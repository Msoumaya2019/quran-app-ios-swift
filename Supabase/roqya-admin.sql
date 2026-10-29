-- Apply after social.sql and roqya.sql. Reuses existing administrator identity.
begin;
grant insert,update on public.roqyas,public.roqya_reciters,public.roqya_audios to authenticated;
do $$ declare t text; begin
 foreach t in array array['roqyas','roqya_reciters','roqya_audios'] loop
 execute format('drop policy if exists roqya_admin_read on public.%I',t);
 execute format('create policy roqya_admin_read on public.%I for select to authenticated using(private.is_app_admin())',t);
 execute format('drop policy if exists roqya_admin_insert on public.%I',t);
 execute format('create policy roqya_admin_insert on public.%I for insert to authenticated with check(private.is_app_admin())',t);
 execute format('drop policy if exists roqya_admin_update on public.%I',t);
 execute format('create policy roqya_admin_update on public.%I for update to authenticated using(private.is_app_admin()) with check(private.is_app_admin())',t);
 end loop;
end $$;
drop policy if exists roqya_admin_storage_read on storage.objects;
create policy roqya_admin_storage_read on storage.objects for select to authenticated using(bucket_id in ('roqya-audio','roqya-images') and private.is_app_admin());
drop policy if exists roqya_admin_storage_insert on storage.objects;
create policy roqya_admin_storage_insert on storage.objects for insert to authenticated with check(bucket_id in ('roqya-audio','roqya-images') and private.is_app_admin());
-- Only unassociated uploads may be removed. Existing media are preserved.
drop policy if exists roqya_admin_storage_delete on storage.objects;
create policy roqya_admin_storage_delete on storage.objects for delete to authenticated using(
 private.is_app_admin() and (
 (bucket_id='roqya-audio' and not exists(select 1 from public.roqya_audios a where a.storage_path=name))
 or (bucket_id='roqya-images' and not exists(select 1 from public.roqyas r where r.image_url like '%/roqya-images/'||name) and not exists(select 1 from public.roqya_reciters r where r.photo_url like '%/roqya-images/'||name))
 ));
commit;
