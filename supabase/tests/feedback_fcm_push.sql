-- Real role/queue behavior, without sending notifications. pg_net requests
-- created by fixture inserts roll back with the rest of this transaction.
begin;
do $$
declare
  users uuid[]:=array[gen_random_uuid(),gen_random_uuid(),gen_random_uuid()];
  install_a uuid:=gen_random_uuid(); install_b uuid:=gen_random_uuid();
  secret_a text:=encode(extensions.gen_random_bytes(32),'hex');
  secret_b text:=encode(extensions.gen_random_bytes(32),'hex');
  issue uuid; payload jsonb; msg jsonb; id_a bigint; id_b bigint;
  lease_a uuid; lease_b uuid; old_lease uuid; blocked boolean; i integer; first_message bigint;
begin
  for i in 1..3 loop insert into auth.users(id,email) values(users[i],users[i]::text||'@feedback-fcm.invalid'); end loop;
  perform set_config('request.jwt.claim.sub',users[1]::text,true);
  issue:=(public.feedback_action('create','{"title":"FCM regression fixture","description":"rollback only"}')->>'id')::uuid;
  perform public.feedback_register_push_device(install_a,secret_a,repeat('a',120),'listen1-xuan');
  blocked:=false;
  begin
    perform public.feedback_register_push_device(install_a,repeat('z',64),repeat('b',120),'listen1-xuan');
  exception when raise_exception then
    if sqlerrm='设备凭据不匹配' then blocked:=true; else raise; end if;
  end;
  if not blocked then raise exception 'installation capability bypassed'; end if;
  perform set_config('request.jwt.claim.sub',users[3]::text,true);
  perform public.feedback_set_unread_preference(issue,'show');
  perform public.feedback_register_push_device(install_b,secret_b,repeat('b',120),'listen1-xuan');
  perform set_config('request.jwt.claim.sub',users[2]::text,true);
  payload:=jsonb_build_object('issue_id',issue,'body','push fixture','client_id',gen_random_uuid());
  msg:=public.feedback_action('send',payload);
  first_message:=(msg->>'id')::bigint;
  perform public.feedback_action('send',payload);
  if (select count(*) from feedback_private.push_jobs where issue_id=issue)<>2 then raise exception 'recipient/idempotency mismatch'; end if;
  perform public.feedback_claim_push_jobs(20);
  select id,lease_token into id_a,lease_a from feedback_private.push_jobs where installation_id=install_a and message_id=first_message;
  select id,lease_token into id_b,lease_b from feedback_private.push_jobs where installation_id=install_b and message_id=first_message;
  if public.feedback_push_delivery(id_a,lease_a) is null then raise exception 'valid delivery missing'; end if;
  perform public.feedback_complete_push_job(id_a,gen_random_uuid(),'sent');
  if (select status from feedback_private.push_jobs where id=id_a)<>'processing' then raise exception 'stale lease acknowledged'; end if;
  -- Reading after claim but before provider send suppresses delivery.
  perform set_config('request.jwt.claim.sub',users[1]::text,true);
  perform public.feedback_mark_read(issue,first_message);
  if public.feedback_push_delivery(id_a,lease_a) is not null then raise exception 'read issue delivered'; end if;
  perform public.feedback_complete_push_job(id_a,lease_a,'cancelled');
  -- An UNREGISTERED response for an old token cannot disable a rotated token.
  perform set_config('request.jwt.claim.sub',users[3]::text,true);
  perform public.feedback_register_push_device(install_b,secret_b,repeat('c',120),'listen1-xuan');
  perform public.feedback_complete_push_job(id_b,lease_b,'failed','UNREGISTERED',repeat('b',120));
  if not exists(select 1 from feedback_private.push_devices where installation_id=install_b and enabled and token=repeat('c',120)) then raise exception 'rotation lost newer token'; end if;
  -- Two queued messages collapse to the latest one for each issue/device.
  for i in 1..2 loop
    delete from feedback_private.rate_limits where user_id=users[2];
    perform set_config('request.jwt.claim.sub',users[2]::text,true);
    msg:=public.feedback_action('send',jsonb_build_object('issue_id',issue,'body','queued burst','client_id',gen_random_uuid()));
  end loop;
  perform public.feedback_claim_push_jobs(20);
  if (select count(*) from feedback_private.push_jobs where issue_id=issue and status='processing')<>2 then raise exception 'burst was not collapsed'; end if;
  select id,lease_token into id_a,lease_a from feedback_private.push_jobs where installation_id=install_a and status='processing';
  -- Anonymous revocation requires the capability, and works after logout.
  perform set_config('role','anon',true);
  perform public.feedback_unregister_push_device(install_a,repeat('z',64));
  perform set_config('role','postgres',true);
  if not (select enabled from feedback_private.push_devices where installation_id=install_a) then raise exception 'wrong secret revoked device'; end if;
  perform set_config('role','anon',true);
  perform public.feedback_unregister_push_device(install_a,secret_a);
  blocked:=false;
  begin
    perform public.feedback_register_push_device(install_a,secret_a,repeat('d',120),'listen1-xuan');
  exception when insufficient_privilege then blocked:=true;
  end;
  if not blocked then raise exception 'anonymous registration allowed'; end if;
  perform set_config('role','postgres',true);
  if public.feedback_push_delivery(id_a,lease_a) is not null then raise exception 'revoked device delivered'; end if;
  -- A physical device may safely bind to the next account using its capability.
  perform set_config('request.jwt.claim.sub',users[3]::text,true);
  perform public.feedback_register_push_device(install_a,secret_a,repeat('d',120),'listen1-xuan');
  if exists(select 1 from feedback_private.push_jobs where installation_id=install_a and user_id=users[1] and status in ('pending','processing')) then raise exception 'previous account jobs survived rebind'; end if;
  select id,lease_token into id_b,lease_b from feedback_private.push_jobs where installation_id=install_b and status='processing';
  old_lease:=lease_b;
  update feedback_private.push_jobs set locked_at=clock_timestamp()-interval '6 minutes' where id=id_b;
  perform public.feedback_claim_push_jobs(20);
  select lease_token into lease_b from feedback_private.push_jobs where id=id_b;
  if lease_b=old_lease then raise exception 'expired lease not replaced'; end if;
  perform public.feedback_complete_push_job(id_b,old_lease,'sent');
  if (select status from feedback_private.push_jobs where id=id_b)<>'processing' then raise exception 'old worker acknowledged new lease'; end if;
  perform public.feedback_complete_push_job(id_b,lease_b,'sent');
  -- Muting after enqueue suppresses both pending and already-claimed work.
  delete from feedback_private.rate_limits where user_id=users[2];
  perform set_config('request.jwt.claim.sub',users[2]::text,true);
  msg:=public.feedback_action('send',jsonb_build_object('issue_id',issue,'body','mute test','client_id',gen_random_uuid()));
  perform public.feedback_claim_push_jobs(20);
  select id,lease_token into id_b,lease_b from feedback_private.push_jobs where installation_id=install_b and message_id=(msg->>'id')::bigint;
  perform set_config('request.jwt.claim.sub',users[3]::text,true);
  perform public.feedback_set_unread_preference(issue,'hide');
  if public.feedback_push_delivery(id_b,lease_b) is not null then raise exception 'muted issue delivered'; end if;
  update feedback_private.push_jobs set attempts=5,locked_at=clock_timestamp()-interval '6 minutes' where id=id_b;
  perform public.feedback_claim_push_jobs(20);
  if (select status from feedback_private.push_jobs where id=id_b)<>'failed' then raise exception 'crashed worker retries unbounded'; end if;
  -- Expiration cleanup is independent of FCM/OAuth availability.
  update feedback_private.push_jobs set status='pending',expires_at=clock_timestamp()-interval '1 minute' where id=id_a;
  perform feedback_private.dispatch_push_jobs();
  if (select status from feedback_private.push_jobs where id=id_a)<>'cancelled' then raise exception 'expired push not cancelled'; end if;
  perform set_config('role','authenticated',true);
  blocked:=false;
  begin perform public.feedback_claim_push_jobs(1); exception when insufficient_privilege then blocked:=true; end;
  if not blocked then raise exception 'client can claim delivery jobs'; end if;
  perform set_config('role','postgres',true);
  if has_schema_privilege('authenticated','feedback_private','USAGE') or
      has_function_privilege('anon','public.feedback_push_authorized(text)','EXECUTE') or
      has_function_privilege('authenticated','public.feedback_complete_push_job(bigint,uuid,text,text,text)','EXECUTE') then
    raise exception 'private worker surface exposed';
  end if;
end $$;
rollback;
select 'FCM queue, account isolation and delivery guards passed; fixtures rolled back' as result;
