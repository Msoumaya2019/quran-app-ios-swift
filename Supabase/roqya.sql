-- Additive migration. No existing Quran/auth/user tables are changed.
begin;
create table if not exists public.roqya_reciters (
 id uuid primary key default gen_random_uuid(), name text not null,
 photo_url text, description text not null default '', enabled boolean not null default true,
 sort_order integer not null default 0, created_at timestamptz not null default now()
);
create table if not exists public.roqyas (
 id uuid primary key default gen_random_uuid(), title text not null, description text not null default '',
 category text not null default 'complete', image_url text, enabled boolean not null default true,
 sort_order integer not null default 0, created_at timestamptz not null default now()
);
create table if not exists public.roqya_audios (
 id uuid primary key default gen_random_uuid(),
 roqya_id uuid not null references public.roqyas(id) on delete restrict,
 reciter_id uuid not null references public.roqya_reciters(id) on delete restrict,
 audio_url text, storage_path text, duration_seconds numeric not null default 0 check(duration_seconds>=0),
 file_size bigint check(file_size>0), enabled boolean not null default true, sort_order integer not null default 0,
 created_at timestamptz not null default now(),
 check (coalesce(nullif(storage_path,'') is not null or audio_url like 'https://%',false)),
 check (storage_path is null or (storage_path not like '/%' and storage_path not like '%..%' and storage_path ~* '\.(mp3|m4a)$'))
);
create index if not exists roqya_audios_roqya on public.roqya_audios(roqya_id);
create index if not exists roqya_audios_reciter on public.roqya_audios(reciter_id);
alter table public.roqyas enable row level security;
alter table public.roqya_reciters enable row level security;
alter table public.roqya_audios enable row level security;
revoke all on public.roqyas,public.roqya_reciters,public.roqya_audios from anon,authenticated;
grant select on public.roqyas,public.roqya_reciters,public.roqya_audios to anon,authenticated;
drop policy if exists roqya_catalog_read on public.roqyas;
create policy roqya_catalog_read on public.roqyas for select to anon,authenticated using(enabled);
drop policy if exists roqya_reciters_read on public.roqya_reciters;
create policy roqya_reciters_read on public.roqya_reciters for select to anon,authenticated using(enabled);
drop policy if exists roqya_audios_read on public.roqya_audios;
create policy roqya_audios_read on public.roqya_audios for select to anon,authenticated using(
 enabled and exists(select 1 from public.roqyas r where r.id=roqya_id and r.enabled)
 and exists(select 1 from public.roqya_reciters c where c.id=reciter_id and c.enabled)
);
-- Private audio: signed URLs honor enabled catalog entries and expire after 6h.
insert into storage.buckets(id,name,public,allowed_mime_types)
 values('roqya-audio','roqya-audio',false,array['audio/mpeg','audio/mp4','audio/x-m4a']) on conflict(id) do update set public=false,allowed_mime_types=excluded.allowed_mime_types;
drop policy if exists roqya_audio_read on storage.objects;
create policy roqya_audio_read on storage.objects for select to anon,authenticated using(
 bucket_id='roqya-audio' and exists(select 1 from public.roqya_audios a where a.storage_path=name and a.enabled)
);
-- Optional covers/photos, administered from the dashboard only.
insert into storage.buckets(id,name,public,allowed_mime_types)
 values('roqya-images','roqya-images',true,array['image/jpeg','image/png','image/webp']) on conflict(id) do nothing;
commit;
