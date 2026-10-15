-- Public feedback data; all mutations are validated inside a single atomic RPC.
create table public.feedback_superadmins (
  user_id uuid primary key references auth.users(id), created_at timestamptz not null default now()
);
alter table public.feedback_superadmins enable row level security;
revoke all on public.feedback_superadmins from anon, authenticated;
insert into public.feedback_superadmins(user_id) values ('29588c6c-4d4e-4e94-a78f-1064ed9d4697');

create function feedback_private.is_admin(who uuid) returns boolean
language sql stable security definer set search_path = '' as $$
  select exists(select 1 from public.feedback_superadmins where user_id=who);
$$;
create table public.feedback_issues (
  id uuid primary key default gen_random_uuid(), creator_id uuid not null references auth.users(id),
  title text not null, description text not null,
  status text not null default 'open' check (status in ('open','declined','completed')),
  locked boolean not null default false, created_at timestamptz not null default clock_timestamp(),
  last_message_at timestamptz not null default clock_timestamp(), updated_at timestamptz not null default clock_timestamp()
);
create index feedback_issues_created on public.feedback_issues(created_at desc,id desc);
create index feedback_issues_activity on public.feedback_issues(last_message_at desc,id desc);
create index feedback_issues_creator on public.feedback_issues(creator_id);
create table public.feedback_messages (
  id bigint generated always as identity primary key, issue_id uuid not null references public.feedback_issues(id),
  sender_id uuid not null references auth.users(id), body text,
  mentions uuid[] not null default '{}', mention_all boolean not null default false,
  reply_to bigint references public.feedback_messages(id), client_id uuid not null,
  created_at timestamptz not null default clock_timestamp(), withdrawn_at timestamptz,
  unique(sender_id,client_id), check ((withdrawn_at is null and body is not null) or (withdrawn_at is not null and body is null and mentions='{}' and not mention_all))
);
create index feedback_messages_issue_id on public.feedback_messages(issue_id,id desc);
create index feedback_messages_sender on public.feedback_messages(sender_id,created_at desc);
create index feedback_messages_reply on public.feedback_messages(reply_to) where reply_to is not null;
create table feedback_private.bans (
  id bigint generated always as identity primary key, issue_id uuid references public.feedback_issues(id),
  user_id uuid not null references auth.users(id), actor_id uuid not null references auth.users(id),
  created_at timestamptz not null default clock_timestamp()
);
create unique index feedback_bans_global on feedback_private.bans(user_id) where issue_id is null;
create unique index feedback_bans_issue on feedback_private.bans(issue_id,user_id) where issue_id is not null;
create table feedback_private.audit (
  id bigint generated always as identity primary key, actor_id uuid not null,
  action text not null, target_id uuid, issue_id uuid, message_id bigint,
  detail jsonb not null default '{}', created_at timestamptz not null default clock_timestamp()
);
create index feedback_audit_message on feedback_private.audit(message_id);
create table feedback_private.rate_limits (user_id uuid primary key, last_message timestamptz, last_issue timestamptz);
create table public.feedback_events (id integer primary key check(id=1), revision bigint not null default 0);
insert into public.feedback_events values(1,0);

create function feedback_private.bump_event() returns trigger language plpgsql security definer set search_path='' as $$
begin update public.feedback_events set revision=revision+1 where id=1; return null; end; $$;
create trigger feedback_admin_changed after insert or update or delete on public.feedback_superadmins for each statement execute function feedback_private.bump_event();
create trigger feedback_ban_changed after insert or update or delete on feedback_private.bans for each statement execute function feedback_private.bump_event();
create trigger feedback_profile_changed after insert or update on public.users for each statement execute function feedback_private.bump_event();

-- Retain the existing self-service protection. Only an administrator may change Pro.
create or replace function public.check_is_pro_unchanged() returns trigger
language plpgsql security definer set search_path='' as $$
begin
  if current_setting('role',true) in ('postgres','service_role')
     or (coalesce(current_setting('role',true),'none')='none' and session_user='postgres') then return new; end if;
  if old.is_pro is distinct from new.is_pro and not feedback_private.is_admin(auth.uid()) then
    raise exception 'is_pro field cannot be modified by users';
  end if;
  return new;
end; $$;

create function feedback_private.validate_text(value text, maximum integer, single_line boolean default false) returns void
language plpgsql security definer set search_path='' as $$
begin
  if value is null or value ~ '^[[:space:]　]*$' or octet_length(value)>262144
     or feedback_private.grapheme_length(value)>maximum
     or (single_line and (position(chr(10) in value)>0 or position(chr(13) in value)>0)) then
    raise exception '内容不能为空且不得超过 % 个字符',maximum;
  end if;
end; $$;

create function public.feedback_context(p_issue uuid default null, p_target uuid default null) returns jsonb
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
    'target_global_banned',case when administrator then exists(select 1 from feedback_private.bans where user_id=p_target and issue_id is null) else false end);
end; $$;

create function public.feedback_profiles(p_ids uuid[]) returns jsonb
language sql stable security definer set search_path='' as $$
 select coalesce(jsonb_agg(jsonb_build_object('user_id',u.user_id,'nickname',u.nickname,'last_login_at',u.last_login_at,'is_pro',u.is_pro)),'[]')
 from public.users u where u.user_id=any(p_ids[1:500]);
$$;

create function public.feedback_participants(p_issue uuid,p_search text default '',p_after uuid default null,p_limit integer default 30) returns jsonb
language sql stable security definer set search_path='' as $$
 select coalesce(jsonb_agg(to_jsonb(r)),'[]') from (
   select u.user_id,u.nickname,u.last_login_at,u.is_pro from public.users u
   where exists(select 1 from public.feedback_messages m where m.issue_id=p_issue and m.sender_id=u.user_id)
   and (p_after is null or u.user_id>p_after)
   and (coalesce(p_search,'')='' or position(lower(p_search) in lower(coalesce(u.nickname,'')||u.user_id::text))>0)
   order by u.user_id limit least(greatest(p_limit,1),114)
 ) r;
$$;

create function public.feedback_issue_page(p_search text default '',p_mine boolean default false,p_sort text default 'activity',p_ascending boolean default false,p_cursor_time timestamptz default null,p_cursor_id uuid default null) returns jsonb
language sql stable security definer set search_path='' as $$
 select coalesce(jsonb_agg(to_jsonb(r)),'[]') from (
   select i.* from public.feedback_issues i
   where (not p_mine or i.creator_id=auth.uid())
   and (coalesce(p_search,'')='' or position(lower(p_search) in lower(i.title||chr(10)||i.description))>0)
   and (p_cursor_time is null or case when p_ascending then
     (case when p_sort='created' then i.created_at else i.last_message_at end,i.id)>(p_cursor_time,p_cursor_id)
     else (case when p_sort='created' then i.created_at else i.last_message_at end,i.id)<(p_cursor_time,p_cursor_id) end)
   order by case when p_ascending then case when p_sort='created' then i.created_at else i.last_message_at end end asc,
     case when not p_ascending then case when p_sort='created' then i.created_at else i.last_message_at end end desc,
     case when p_ascending then i.id end asc,case when not p_ascending then i.id end desc limit 30
 ) r;
$$;

create function public.feedback_message_page(p_issue uuid,p_before bigint default null,p_after bigint default null,p_limit integer default 30) returns jsonb
language sql stable security definer set search_path='' as $$
 select coalesce(jsonb_agg(to_jsonb(r)),'[]') from (
  select m.* from public.feedback_messages m where m.issue_id=p_issue
  and (p_before is null or m.id<p_before) and (p_after is null or m.id>p_after)
  order by case when p_after is not null then m.id end asc,case when p_after is null then m.id end desc
  limit least(greatest(p_limit,1),114)
 ) r;
$$;

create function public.feedback_action(p_action text,p_data jsonb) returns jsonb
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

create function public.feedback_withdrawal_audit(p_message bigint) returns jsonb
language plpgsql stable security definer set search_path='' as $$
begin
 if not feedback_private.is_admin(auth.uid()) then raise exception '没有权限'; end if;
 return (select coalesce(jsonb_agg(jsonb_build_object('actor_id',actor_id,'created_at',created_at)),'[]') from feedback_private.audit where message_id=p_message and action='withdraw');
end; $$;

-- Only public chat data is readable directly (required by Postgres Changes).
-- No API role can write tables or inspect the administrator roster/audit tables.
alter table public.feedback_issues enable row level security;
alter table public.feedback_messages enable row level security;
alter table public.feedback_events enable row level security;
create policy feedback_issues_read on public.feedback_issues for select to anon,authenticated using(true);
create policy feedback_messages_read on public.feedback_messages for select to anon,authenticated using(true);
create policy feedback_events_read on public.feedback_events for select to anon,authenticated using(true);
revoke all on public.feedback_issues,public.feedback_messages,public.feedback_events from anon,authenticated;
grant select on public.feedback_issues,public.feedback_messages,public.feedback_events to anon,authenticated;
alter publication supabase_realtime add table public.feedback_issues,public.feedback_messages,public.feedback_events;

revoke all on all tables in schema feedback_private from public,anon,authenticated;
revoke all on all functions in schema feedback_private from public,anon,authenticated;
revoke all on function public.feedback_context(uuid,uuid),public.feedback_profiles(uuid[]),public.feedback_participants(uuid,text,uuid,integer),public.feedback_issue_page(text,boolean,text,boolean,timestamptz,uuid),public.feedback_message_page(uuid,bigint,bigint,integer),public.feedback_action(text,jsonb),public.feedback_withdrawal_audit(bigint) from public,anon,authenticated;
grant execute on function public.feedback_context(uuid,uuid),public.feedback_profiles(uuid[]),public.feedback_participants(uuid,text,uuid,integer),public.feedback_issue_page(text,boolean,text,boolean,timestamptz,uuid),public.feedback_message_page(uuid,bigint,bigint,integer) to anon,authenticated;
grant execute on function public.feedback_action(text,jsonb),public.feedback_withdrawal_audit(bigint) to authenticated;
comment on table public.feedback_superadmins is 'Feedback superadministrators: modify only via database; never authorize by nickname.';
comment on table public.users is 'User profiles; is_pro changes restricted to database administrators and the audited feedback administrator RPC.';
