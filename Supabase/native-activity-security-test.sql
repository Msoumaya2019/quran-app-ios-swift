-- Run only in a disposable PostgreSQL database, never the production project.
create schema auth;
create role anon; create role authenticated; create role service_role;
create table auth.users(id uuid primary key,last_sign_in_at timestamptz);
create function auth.uid() returns uuid language sql stable as $$ select nullif(current_setting('request.jwt.claim.sub',true),'')::uuid $$;
grant usage on schema auth to authenticated;
grant execute on function auth.uid() to authenticated;
create table public.app_admins(user_id uuid primary key);
insert into auth.users values
('00000000-0000-0000-0000-000000000001','2026-10-14T10:00:00Z'),
('00000000-0000-0000-0000-000000000002',null),
('00000000-0000-0000-0000-000000000003',null);
insert into public.app_admins values('00000000-0000-0000-0000-000000000001'),('00000000-0000-0000-0000-000000000002');
\i Supabase/native-activity.sql
update public.native_activity_settings set admin_user_id='00000000-0000-0000-0000-000000000001';
set role authenticated;
set request.jwt.claim.sub='00000000-0000-0000-0000-000000000003';
do $$ begin
 if (public.native_activity_status()->>'enabled')::boolean then raise exception 'Must be disabled by default'; end if;
 begin perform public.native_activity_consent(true); raise exception 'Consent enabled without privacy gate'; exception when insufficient_privilege then null; end;
 begin perform public.native_activity_summary(array['00000000-0000-0000-0000-000000000001'::uuid]); raise exception 'Member read summaries'; exception when insufficient_privilege then null; end;
 begin perform * from public.native_activity_chunks; raise exception 'Member read raw data'; exception when insufficient_privilege then null; end;
end $$;
reset role;
update public.native_activity_settings set enabled=true,legal_review_confirmed=true,retention_job_confirmed=true;
set role authenticated;
select public.native_activity_consent(true);
do $$ declare payload jsonb; begin
 payload=jsonb_build_array(jsonb_build_object('id','10000000-0000-0000-0000-000000000001','session_id','20000000-0000-0000-0000-000000000001','started_at',now()-interval '2 minutes','active_seconds',30));
 perform public.native_activity_ingest(payload); perform public.native_activity_ingest(payload);
end $$;
set request.jwt.claim.sub='00000000-0000-0000-0000-000000000002';
do $$ begin
 begin perform public.native_activity_summary(array['00000000-0000-0000-0000-000000000003'::uuid]); raise exception 'Other admin read summaries'; exception when insufficient_privilege then null; end;
end $$;
set request.jwt.claim.sub='00000000-0000-0000-0000-000000000001';
do $$ declare result jsonb; begin
 result=public.native_activity_summary(array['00000000-0000-0000-0000-000000000003'::uuid]);
 if (result->0->>'today_seconds')::int<>30 or (result->0->>'sessions_7_days')::int<>1 then raise exception 'Duplicate accounting'; end if;
 if result->0->>'last_sign_in_at' is not null then raise exception 'Invented authentication'; end if;
end $$;
set request.jwt.claim.sub='00000000-0000-0000-0000-000000000003';
select public.native_activity_consent(false);
reset role;
do $$ begin if exists(select from public.native_activity_chunks) then raise exception 'Withdrawal did not erase data'; end if; end $$;
set role anon;
do $$ begin
 begin perform public.native_activity_status(); raise exception 'Anonymous access allowed'; exception when insufficient_privilege then null; end;
end $$;
reset role;
delete from public.app_admins where user_id='00000000-0000-0000-0000-000000000001';
set role authenticated;
set request.jwt.claim.sub='00000000-0000-0000-0000-000000000003';
do $$ begin
 if (public.native_activity_status()->>'enabled')::boolean then raise exception 'Collection enabled without an authorized owner'; end if;
end $$;
reset role;
delete from auth.users where id='00000000-0000-0000-0000-000000000001';
do $$ begin
 if exists(select from public.native_activity_settings where admin_user_id is not null) then raise exception 'Owner deletion blocked or dangling configuration'; end if;
end $$;
select 'Activity security tests passed' as result;
