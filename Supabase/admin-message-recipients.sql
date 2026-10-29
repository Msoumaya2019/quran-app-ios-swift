-- Additive read-only RPC; no changes to messaging tables or existing RLS.
begin;
create or replace function public.admin_messages_with_recipients() returns jsonb
language plpgsql security definer set search_path='' as $$
declare result jsonb;
begin
 if not private.is_app_admin() then raise exception 'Accès administrateur refusé';end if;
 select coalesce(jsonb_agg(row_data order by created_at desc,id desc),'[]'::jsonb) into result from (
 select m.created_at,m.id,to_jsonb(m)||jsonb_build_object(
 'recipient_id',case when l.requester_id=m.sender_id then l.recipient_id when l.recipient_id=m.sender_id then l.requester_id else null end,
 'recipient_name',p.display_name,'group_name',g.name
 ) as row_data
 from (select * from public.friend_messages order by created_at desc,id desc limit 100) m
 left join public.friend_links l on l.id=m.link_id
 left join public.friend_profiles p on p.id=case when l.requester_id=m.sender_id then l.recipient_id when l.recipient_id=m.sender_id then l.requester_id else null end
 left join public.friend_groups g on g.id=m.group_id
 ) rows;
 return result;
end $$;
revoke all on function public.admin_messages_with_recipients() from public,anon;
grant execute on function public.admin_messages_with_recipients() to authenticated;
commit;
