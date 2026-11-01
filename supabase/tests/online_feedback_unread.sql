-- Execute as postgres in the connected project. All fixture data rolls back.
begin;
do $$
declare
  users uuid[]:=array[]::uuid[]; issue uuid; message jsonb; payload jsonb;
  first_id bigint; latest_id bigint; old_revision bigint; expected boolean[];
  i integer; state public.feedback_issue_states; blocked boolean;
begin
  for i in 1..8 loop
    users:=array_append(users,gen_random_uuid());
    insert into auth.users(id,email) values(users[i],users[i]::text||'@feedback-unread.invalid');
  end loop;
  perform set_config('request.jwt.claim.sub',users[1]::text,true);
  issue:=(public.feedback_action('create','{"title":"unread regression fixture","description":"transaction rollback only"}') ->> 'id')::uuid;
  if not exists(select 1 from public.feedback_issue_states where issue_id=issue and user_id=users[1]) then
    raise exception 'owner state not initialized';
  end if;
  -- Establish historical participants, including one whose message is withdrawn.
  for i in 3..5 loop
    insert into public.feedback_messages(issue_id,sender_id,body,client_id)
      values(issue,users[i],'historical participation',gen_random_uuid());
  end loop;
  update public.feedback_messages set body=null,withdrawn_at=clock_timestamp()
    where issue_id=issue and sender_id=users[5];
  for i in 1..8 loop
    perform set_config('request.jwt.claim.sub',users[i]::text,true);
    perform public.feedback_set_unread_preference(issue,case when i in (4,7) then 'show' when i in (5,8) then 'hide' else 'unset' end);
    perform public.feedback_mark_read(issue,9223372036854775807);
  end loop;
  perform set_config('request.jwt.claim.sub',users[2]::text,true);
  payload:=jsonb_build_object('issue_id',issue,'body','recipient matrix','client_id',gen_random_uuid());
  message:=public.feedback_action('send',payload);
  first_id:=(message->>'id')::bigint;
  expected:=array[true,false,true,true,false,false,true,false];
  for i in 1..8 loop
    select * into strict state from public.feedback_issue_states where issue_id=issue and user_id=users[i];
    if (state.last_notified_id>state.last_read_id) is distinct from expected[i] then
      raise exception 'recipient matrix mismatch for user %',i;
    end if;
  end loop;
  select revision into old_revision from public.feedback_issue_states where issue_id=issue and user_id=users[7];
  message:=public.feedback_action('send',payload);
  if (message->>'id')::bigint<>first_id or
      (select revision from public.feedback_issue_states where issue_id=issue and user_id=users[7])<>old_revision then
    raise exception 'idempotent retry notified twice';
  end if;
  -- A sender retains their previous unread; stale read positions cannot clear
  -- a later message, and a future position is clamped to existing history.
  perform set_config('request.jwt.claim.sub',users[3]::text,true);
  message:=public.feedback_action('send',jsonb_build_object('issue_id',issue,'body','own unread retained','client_id',gen_random_uuid()));
  latest_id:=(message->>'id')::bigint;
  if not exists(select 1 from public.feedback_issue_states where issue_id=issue and user_id=users[3] and last_notified_id>last_read_id) then
    raise exception 'own send cleared previous unread';
  end if;
  perform set_config('request.jwt.claim.sub',users[7]::text,true);
  perform public.feedback_mark_read(issue,first_id);
  if not exists(select 1 from public.feedback_issue_states where issue_id=issue and user_id=users[7] and last_notified_id>last_read_id) then
    raise exception 'stale read cleared newer message';
  end if;
  message:=public.feedback_mark_read(issue,9223372036854775807);
  if (message->>'last_read_id')::bigint<>latest_id then raise exception 'future read not clamped'; end if;
  perform public.feedback_mark_read(issue,first_id);
  if (select last_read_id from public.feedback_issue_states where issue_id=issue and user_id=users[7])<>latest_id then
    raise exception 'read position moved backwards';
  end if;
  delete from feedback_private.rate_limits where user_id=users[2];
  perform set_config('request.jwt.claim.sub',users[2]::text,true);
  message:=public.feedback_action('send',jsonb_build_object('issue_id',issue,'body','after read','client_id',gen_random_uuid()));
  latest_id:=(message->>'id')::bigint;
  select revision into old_revision from public.feedback_issue_states where issue_id=issue and user_id=users[7];
  perform public.feedback_action('withdraw',jsonb_build_object('issue_id',issue,'message_id',latest_id));
  if (select revision from public.feedback_issue_states where issue_id=issue and user_id=users[7])<>old_revision then
    raise exception 'withdrawal changed notification state';
  end if;
  perform set_config('request.jwt.claim.sub',users[7]::text,true);
  perform public.feedback_set_unread_preference(issue,'hide');
  perform public.feedback_set_unread_preference(issue,'show');
  if exists(select 1 from public.feedback_issue_states where issue_id=issue and user_id=users[7] and last_notified_id>last_read_id) then
    raise exception 're-enabling resurrected old unread';
  end if;
  -- Explicit show applies before first participation; reverting to unset clears
  -- only the outsider's badge. Participants continue using the default rule.
  perform set_config('request.jwt.claim.sub',users[6]::text,true);
  perform public.feedback_set_unread_preference(issue,'show');
  perform set_config('request.jwt.claim.sub',users[5]::text,true);
  perform public.feedback_set_unread_preference(issue,'show');
  delete from feedback_private.rate_limits where user_id=users[2];
  perform set_config('request.jwt.claim.sub',users[2]::text,true);
  perform public.feedback_action('send',jsonb_build_object('issue_id',issue,'body','preference changes','client_id',gen_random_uuid()));
  perform set_config('request.jwt.claim.sub',users[6]::text,true);
  message:=public.feedback_set_unread_preference(issue,'unset');
  if (message->>'last_notified_id')::bigint>(message->>'last_read_id')::bigint then raise exception 'unset outsider stayed unread'; end if;
  perform set_config('request.jwt.claim.sub',users[5]::text,true);
  message:=public.feedback_set_unread_preference(issue,'unset');
  if (message->>'last_notified_id')::bigint<=(message->>'last_read_id')::bigint then raise exception 'unset participant lost unread'; end if;
  -- Owner can opt out and opt back in, with all three choices honored.
  for i in 1..3 loop
    perform set_config('request.jwt.claim.sub',users[1]::text,true);
    perform public.feedback_set_unread_preference(issue,(array['hide','show','unset'])[i]);
    delete from feedback_private.rate_limits where user_id=users[2];
    perform set_config('request.jwt.claim.sub',users[2]::text,true);
    perform public.feedback_action('send',jsonb_build_object('issue_id',issue,'body','owner preference','client_id',gen_random_uuid()));
    if (select last_notified_id>last_read_id from public.feedback_issue_states where issue_id=issue and user_id=users[1]) is distinct from (i<>1) then
      raise exception 'owner preference failed %',i;
    end if;
  end loop;
  -- Actual API role: own SELECT works, other users' rows are filtered,
  -- direct INSERT/UPDATE fail, and RPCs cannot run without an identity.
  perform set_config('request.jwt.claim.sub',users[7]::text,true);
  perform set_config('role','authenticated',true);
  if exists(select 1 from public.feedback_issue_states where user_id<>users[7]) or
      not exists(select 1 from public.feedback_issue_states where issue_id=issue) then
    raise exception 'RLS account isolation failed';
  end if;
  blocked:=false;
  begin
    update public.feedback_issue_states set preference='show' where user_id=users[1];
  exception when insufficient_privilege then blocked:=true;
  end;
  if not blocked then raise exception 'direct UPDATE allowed'; end if;
  blocked:=false;
  begin
    insert into public.feedback_issue_states(user_id,issue_id) values(users[1],issue);
  exception when insufficient_privilege then blocked:=true;
  end;
  if not blocked then raise exception 'direct INSERT allowed'; end if;
  message:=public.feedback_set_unread_preference(issue,'hide');
  if (message->>'user_id')::uuid<>users[7] then raise exception 'RPC mutated another account'; end if;
  blocked:=false;
  begin
    perform public.feedback_set_unread_preference(issue,'invalid');
  exception when raise_exception then
    if sqlerrm='无效的未读红点设置' then blocked:=true; else raise; end if;
  end;
  if not blocked then raise exception 'invalid preference accepted'; end if;
  perform set_config('request.jwt.claim.sub','',true);
  perform set_config('request.jwt.claims','{}',true);
  blocked:=false;
  begin
    perform public.feedback_mark_read(issue,0);
  exception when raise_exception then
    if sqlerrm='请先登录' then blocked:=true; else raise; end if;
  end;
  if not blocked then raise exception 'missing identity accepted'; end if;
  perform set_config('role','postgres',true);
  if has_table_privilege('anon','public.feedback_issue_states','SELECT') or
      has_function_privilege('anon','public.feedback_mark_read(uuid,bigint)','EXECUTE') or
      has_function_privilege('anon','public.feedback_set_unread_preference(uuid,text)','EXECUTE') then
    raise exception 'anonymous notification access allowed';
  end if;
end $$;
rollback;
select 'online feedback unread regression passed; fixtures rolled back' as result;
