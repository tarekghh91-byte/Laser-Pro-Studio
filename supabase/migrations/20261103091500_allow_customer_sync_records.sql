-- Allow independent customer profiles to use the existing per-user sync store.
-- SECURITY INVOKER and auth.uid() ownership are preserved.
create or replace function public.lp_put_sync_record(
  p_collection text,
  p_record_id text,
  p_payload jsonb,
  p_expected_version bigint
)
returns bigint
language plpgsql
security invoker
set search_path = public
as $function$
declare
  v_user uuid := (select auth.uid());
  v_version bigint;
begin
  if v_user is null then raise exception 'AUTH_REQUIRED'; end if;
  if p_collection not in ('orders','materials','customers')
     or length(p_record_id)>128 or length(p_record_id)<1 or p_payload is null then
    raise exception 'INVALID_RECORD';
  end if;
  if p_expected_version=0 then
    insert into public.lp_sync_records(owner_id,collection,record_id,payload,version)
    values(v_user,p_collection,p_record_id,p_payload,1)
    on conflict do nothing
    returning version into v_version;
  elsif p_expected_version>0 then
    update public.lp_sync_records
       set payload=p_payload, version=version+1, updated_at=now()
     where owner_id=v_user and collection=p_collection and record_id=p_record_id
       and version=p_expected_version
    returning version into v_version;
  end if;
  if v_version is null then raise exception 'SYNC_CONFLICT'; end if;
  return v_version;
end
$function$;

revoke execute on function public.lp_put_sync_record(text,text,jsonb,bigint) from public;
revoke execute on function public.lp_put_sync_record(text,text,jsonb,bigint) from anon;
grant execute on function public.lp_put_sync_record(text,text,jsonb,bigint) to authenticated;
