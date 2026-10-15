-- Strict JSON string validation and caller-specific management capabilities.
-- Read-only pagination functions can use the existing public SELECT policies.
alter function public.feedback_issue_page(text,boolean,text,boolean,timestamptz,uuid) security invoker;
alter function public.feedback_message_page(uuid,bigint,bigint,integer) security invoker;
create policy feedback_superadmins_no_api_read on public.feedback_superadmins for select to anon,authenticated using(false);
create or replace function public.feedback_context(p_issue uuid default null, p_target uuid default null) returns jsonb
language plpgsql stable security definer set search_path='' as $$
declare who uuid:=auth.uid(); owner_id uuid; administrator boolean:=feedback_private.is_admin(who); manager boolean;
begin
  select creator_id into owner_id from public.feedback_issues where id=p_issue;
  manager:=administrator or coalesce(who=owner_id,false);
  return jsonb_build_object('user_id',who,'is_admin',administrator,'is_creator',coalesce(who=owner_id,false),
    'global_banned',not administrator and exists(select 1 from feedback_private.bans where user_id=who and bans.issue_id is null),
    'issue_banned',not administrator and coalesce(who<>owner_id,true) and exists(select 1 from feedback_private.bans where user_id=who and issue_id=p_issue),
    'target_protected',case when manager then feedback_private.is_admin(p_target) or coalesce(p_target=owner_id,false) else false end,
    'target_issue_banned',case when manager then exists(select 1 from feedback_private.bans where user_id=p_target and issue_id=p_issue) else false end,
    'can_global_ban',administrator and p_target is not null and p_target<>who and not feedback_private.is_admin(p_target),
    'target_global_banned',case when administrator then exists(select 1 from feedback_private.bans where user_id=p_target and issue_id is null) else false end);
end; $$;

create or replace function public.feedback_action(p_action text,p_data jsonb) returns jsonb
language plpgsql security definer set search_path='' as $$
#variable_conflict use_variable
declare
 who uuid:=auth.uid(); administrator boolean; issue public.feedback_issues;
 msg public.feedback_messages; existing public.feedback_messages; target uuid; issue_id uuid;
 mentioned uuid[]; reply_id bigint; client uuid; old_pro boolean; pro_value boolean; previous_time timestamptz;
begin
 if who is null then raise exception '请先登录'; end if;
 administrator:=feedback_private.is_admin(who);
 issue_id:=nullif(p_data->>'issue_id','')::uuid;
 target:=nullif(p_data->>'user_id','')::uuid;
 -- Serialize per-account rate checks, including concurrent requests across issues.
 perform pg_advisory_xact_lock(hashtextextended('feedback-user:'||who::text,0));
 if issue_id is not null then
   select * into issue from public.feedback_issues where id=issue_id for update;
   if not found then raise exception '问题不存在'; end if;
 end if;
 if p_action='create' then
   if jsonb_typeof(p_data->'title') is distinct from 'string' or jsonb_typeof(p_data->'description') is distinct from 'string' then raise exception '标题和描述必须是字符串'; end if;
   if not administrator and exists(select 1 from feedback_private.bans where user_id=who and bans.issue_id is null) then raise exception '你已被全局禁言'; end if;
   perform feedback_private.validate_text(p_data->>'title',100,true);
   perform feedback_private.validate_text(p_data->>'description',1000);
   select last_issue into previous_time from feedback_private.rate_limits where user_id=who;
   if not administrator and previous_time>clock_timestamp()-interval '60 seconds' then raise exception '每 60 秒只能创建一个问题'; end if;
   insert into public.feedback_issues(creator_id,title,description) values(who,p_data->>'title',p_data->>'description') returning * into issue;
   insert into feedback_private.rate_limits(user_id,last_issue) values(who,clock_timestamp()) on conflict(user_id) do update set last_issue=excluded.last_issue;
   return to_jsonb(issue);
 elsif p_action='send' then
   if issue.id is null then raise exception '问题不存在'; end if;
   client:=(p_data->>'client_id')::uuid;
   select * into existing from public.feedback_messages where sender_id=who and client_id=client;
   if found then
     if existing.issue_id<>issue.id then raise exception '发送标识已使用'; end if;
     return to_jsonb(existing);
   end if;
   if not administrator and exists(select 1 from feedback_private.bans b where b.user_id=who and (b.issue_id is null or (b.issue_id=issue.id and who<>issue.creator_id))) then raise exception '你已被禁言'; end if;
   if issue.locked and not administrator and who<>issue.creator_id then raise exception '讨论已锁定'; end if;
   if jsonb_typeof(p_data->'body') is distinct from 'string' then raise exception '消息必须是字符串'; end if;
   perform feedback_private.validate_text(p_data->>'body',1000);
   select last_message into previous_time from feedback_private.rate_limits where user_id=who;
   if not administrator and previous_time>clock_timestamp()-interval '3 seconds' then raise exception '每 3 秒只能发送一条消息'; end if;
   select coalesce(array_agg(distinct value::uuid),'{}') into mentioned from jsonb_array_elements_text(coalesce(p_data->'mentions','[]'));
   if exists(select 1 from unnest(mentioned) u where not exists(select 1 from public.feedback_messages m where m.issue_id=issue.id and m.sender_id=u)) then raise exception '只能提及在此问题发过言的用户'; end if;
   reply_id:=nullif(p_data->>'reply_to','')::bigint;
   if reply_id is not null and not exists(select 1 from public.feedback_messages where id=reply_id and feedback_messages.issue_id=issue.id and withdrawn_at is null) then raise exception '无法回复此消息'; end if;
   insert into public.feedback_messages(issue_id,sender_id,body,mentions,mention_all,reply_to,client_id)
   values(issue.id,who,p_data->>'body',mentioned,coalesce((p_data->>'mention_all')::boolean,false),reply_id,client) returning * into msg;
   update public.feedback_issues set last_message_at=msg.created_at where id=issue.id;
   insert into feedback_private.rate_limits(user_id,last_message) values(who,clock_timestamp()) on conflict(user_id) do update set last_message=excluded.last_message;
   return to_jsonb(msg);
 elsif p_action='withdraw' then
   if issue.id is null then raise exception '问题不存在'; end if;
   select * into msg from public.feedback_messages where id=(p_data->>'message_id')::bigint and feedback_messages.issue_id=issue.id for update;
   if not found then raise exception '消息不存在'; end if;
   if feedback_private.is_admin(msg.sender_id) then
     if who<>msg.sender_id then raise exception '只能由该管理员本人撤回'; end if;
   elsif not administrator and who<>issue.creator_id and not (who=msg.sender_id and clock_timestamp()<=msg.created_at+interval '300 seconds') then raise exception '没有撤回权限或已超过五分钟'; end if;
   if msg.withdrawn_at is not null then return to_jsonb(msg); end if;
   update public.feedback_messages set body=null,mentions='{}',mention_all=false,withdrawn_at=clock_timestamp() where id=msg.id returning * into msg;
   insert into feedback_private.audit(actor_id,action,target_id,issue_id,message_id) values(who,'withdraw',msg.sender_id,issue.id,msg.id);
   return to_jsonb(msg);
 elsif p_action='edit' then
   if jsonb_typeof(p_data->'title') is distinct from 'string' or jsonb_typeof(p_data->'description') is distinct from 'string' then raise exception '标题和描述必须是字符串'; end if;
   if issue.id is null or not (administrator or who=issue.creator_id) then raise exception '没有管理权限'; end if;
   perform feedback_private.validate_text(p_data->>'title',100,true);
   perform feedback_private.validate_text(p_data->>'description',1000);
   update public.feedback_issues set title=p_data->>'title',description=p_data->>'description',
     status=coalesce(p_data->>'status',status),locked=coalesce((p_data->>'locked')::boolean,locked),updated_at=clock_timestamp() where id=issue.id returning * into issue;
   return to_jsonb(issue);
 elsif p_action='ban' then
   if target is null or not exists(select 1 from auth.users where id=target) then raise exception '用户不存在'; end if;
   if feedback_private.is_admin(target) then raise exception '不能禁言超级管理员'; end if;
   if issue_id is null then
     if not administrator then raise exception '只有超级管理员可以全局禁言'; end if;
   elsif not (administrator or who=issue.creator_id) or target=issue.creator_id then raise exception '不能禁言问题创建者或没有权限'; end if;
   if coalesce((p_data->>'banned')::boolean,false) then
     insert into feedback_private.bans(issue_id,user_id,actor_id) values(issue_id,target,who) on conflict do nothing;
   else delete from feedback_private.bans where user_id=target and feedback_private.bans.issue_id is not distinct from issue_id; end if;
   insert into feedback_private.audit(actor_id,action,target_id,issue_id,detail) values(who,'ban',target,issue_id,jsonb_build_object('banned',(p_data->>'banned')::boolean));
   return '{}'::jsonb;
 elsif p_action='pro' then
   if not administrator or target is null or target=who then raise exception '只能由超级管理员修改其他用户 Pro'; end if;
   pro_value:=(p_data->>'is_pro')::boolean;
   if pro_value is null then raise exception '缺少 Pro 状态'; end if;
   select is_pro into old_pro from public.users where user_id=target for update;
   if not found then raise exception '用户资料不存在'; end if;
   update public.users set is_pro=pro_value where user_id=target;
   insert into feedback_private.audit(actor_id,action,target_id,detail) values(who,'pro',target,jsonb_build_object('before',old_pro,'after',pro_value));
   return jsonb_build_object('is_pro',pro_value);
 else raise exception '未知操作'; end if;
end; $$;

