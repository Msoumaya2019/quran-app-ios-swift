-- Non-destructive native-only activity feature. Collection remains OFF after migration.
-- Existing app_admins(user_id) is reused; a designated owner must be set separately.
begin;
create table if not exists public.native_activity_settings (
 singleton boolean primary key default true check(singleton),
 admin_user_id uuid references auth.users(id),
 enabled boolean not null default false,
 privacy_version text not null default 'usage-2026-10-14',
 legal_review_confirmed boolean not null default false,
 retention_job_confirmed boolean not null default false
);
insert into public.native_activity_settings(singleton) values(true) on conflict do nothing;
create table if not exists public.native_activity_consents (
 user_id uuid primary key references auth.users(id) on delete cascade,
 privacy_version text not null, consented_at timestamptz not null default now()
);
create table if not exists public.native_activity_chunks (
 user_id uuid not null references auth.users(id) on delete cascade,
 id uuid not null, session_id uuid not null, started_at timestamptz not null,
 active_seconds integer not null check(active_seconds between 1 and 60),
 primary key(user_id,id)
);
create index if not exists native_activity_period on public.native_activity_chunks(user_id,started_at);
alter table public.native_activity_settings enable row level security;
alter table public.native_activity_consents enable row level security;
alter table public.native_activity_chunks enable row level security;
-- No client table access. All paths require explicit checks in security-definer functions.
revoke all on public.native_activity_settings,public.native_activity_consents,public.native_activity_chunks from anon,authenticated;

create or replace function public.native_activity_status() returns jsonb
language sql security definer set search_path = public, pg_temp as $$
 select jsonb_build_object('enabled', enabled and legal_review_confirmed and retention_job_confirmed,
 'consenting', exists(select 1 from public.native_activity_consents c where c.user_id=auth.uid() and c.privacy_version=s.privacy_version))
 from public.native_activity_settings s where singleton and auth.uid() is not null;
$$;
create or replace function public.native_activity_consent(p_consent boolean) returns void
language plpgsql security definer set search_path = public, pg_temp as $$
declare s public.native_activity_settings;
begin
 if auth.uid() is null then raise exception 'Authentication required' using errcode='42501'; end if;
 select * into s from public.native_activity_settings where singleton;
 if not p_consent then
  delete from public.native_activity_consents where user_id=auth.uid();
  delete from public.native_activity_chunks where user_id=auth.uid(); return;
 end if;
 if not(s.enabled and s.legal_review_confirmed and s.retention_job_confirmed) then raise exception 'Collection disabled' using errcode='42501'; end if;
 insert into public.native_activity_consents(user_id,privacy_version) values(auth.uid(),s.privacy_version)
 on conflict(user_id) do update set privacy_version=excluded.privacy_version,consented_at=now();
end; $$;
create or replace function public.native_activity_ingest(p_chunks jsonb) returns void
language plpgsql security definer set search_path = public, pg_temp as $$
declare v jsonb; s public.native_activity_settings; start_time timestamptz; seconds integer;
begin
 if auth.uid() is null then raise exception 'Authentication required' using errcode='42501'; end if;
 select * into s from public.native_activity_settings where singleton;
 if not(s.enabled and s.legal_review_confirmed and s.retention_job_confirmed) or not exists(select 1 from public.native_activity_consents c where c.user_id=auth.uid() and c.privacy_version=s.privacy_version) then
  raise exception 'Collection disabled or consent missing' using errcode='42501';
 end if;
 if jsonb_typeof(p_chunks)<>'array' or jsonb_array_length(p_chunks)>100 then raise exception 'Invalid batch'; end if;
 for v in select value from jsonb_array_elements(p_chunks) loop
  start_time=(v->>'started_at')::timestamptz; seconds=(v->>'active_seconds')::integer;
  if start_time < now()-interval '30 days' or start_time>now()+interval '1 minute' or seconds not between 1 and 60 then raise exception 'Invalid foreground interval'; end if;
  insert into public.native_activity_chunks(user_id,id,session_id,started_at,active_seconds)
  values(auth.uid(),(v->>'id')::uuid,(v->>'session_id')::uuid,start_time,seconds)
  on conflict(user_id,id) do update set active_seconds=greatest(native_activity_chunks.active_seconds,excluded.active_seconds)
  where native_activity_chunks.session_id=excluded.session_id and native_activity_chunks.started_at=excluded.started_at;
 end loop;
 delete from public.native_activity_chunks where started_at<now()-interval '30 days';
end; $$;

-- Only the designated account AND an existing app_admins membership may read summaries.
create or replace function public.native_activity_summary(p_users uuid[],p_zone text default 'Europe/Paris') returns jsonb
language plpgsql security definer set search_path = public, pg_temp as $$
declare result jsonb; day_start timestamptz; period_start timestamptz;
begin
 if auth.uid() is null or not exists(select 1 from public.native_activity_settings s join public.app_admins a on a.user_id=s.admin_user_id where s.singleton and s.admin_user_id=auth.uid()) then
  raise exception 'Owner administrator required' using errcode='42501';
 end if;
 if coalesce(array_length(p_users,1),0)>50 then raise exception 'Too many accounts'; end if;
 if not exists(select 1 from pg_timezone_names where name=p_zone) then raise exception 'Invalid time zone'; end if;
 day_start=date_trunc('day',now() at time zone p_zone) at time zone p_zone;
 period_start=(date_trunc('day',now() at time zone p_zone)-interval '6 days') at time zone p_zone;
 select coalesce(jsonb_agg(jsonb_build_object('user_id',u.id,'last_sign_in_at',u.last_sign_in_at,
 'last_seen',a.last_seen,'today_seconds',coalesce(a.today_seconds,0),'week_seconds',coalesce(a.week_seconds,0),
 'sessions_7_days',coalesce(a.sessions,0),'tracked',exists(select 1 from public.native_activity_consents c where c.user_id=u.id),
 'period_start',period_start,'period_end',now(),'time_zone',p_zone)), '[]'::jsonb) into result
 from auth.users u left join lateral (
 select max(started_at+active_seconds*interval '1 second') last_seen,
 sum(greatest(0,extract(epoch from least(started_at+active_seconds*interval '1 second',now())-greatest(started_at,day_start))))::bigint today_seconds,
 sum(greatest(0,extract(epoch from least(started_at+active_seconds*interval '1 second',now())-greatest(started_at,period_start))))::bigint week_seconds,
 count(distinct session_id) filter(where started_at>=period_start) sessions
 from public.native_activity_chunks c where c.user_id=u.id and started_at>=now()-interval '30 days'
 ) a on true where u.id=any(p_users);
 return result;
end; $$;
-- Configure a DAILY scheduled call before confirming retention_job_confirmed.
create or replace function public.native_activity_purge() returns void
language sql security definer set search_path = public, pg_temp as $$
 delete from public.native_activity_chunks where started_at<now()-interval '30 days';
$$;
revoke all on function public.native_activity_status(),public.native_activity_consent(boolean),public.native_activity_ingest(jsonb),public.native_activity_summary(uuid[],text),public.native_activity_purge() from public,anon,authenticated;
grant execute on function public.native_activity_status(),public.native_activity_consent(boolean),public.native_activity_ingest(jsonb),public.native_activity_summary(uuid[],text) to authenticated;
grant execute on function public.native_activity_purge() to service_role;
commit;
