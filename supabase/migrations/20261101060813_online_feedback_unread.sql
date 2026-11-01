-- Personal unread metadata is private even though feedback contents are public.
create table public.feedback_issue_states (
  user_id uuid not null references auth.users(id) on delete cascade,
  issue_id uuid not null references public.feedback_issues(id) on delete cascade,
  preference text not null default 'unset' check (preference in ('unset','show','hide')),
  participated boolean not null default false,
  last_notified_id bigint not null default 0 check (last_notified_id >= 0),
  last_read_id bigint not null default 0 check (last_read_id >= 0),
  revision bigint not null default 1,
  primary key (user_id,issue_id)
);
create index feedback_issue_states_issue on public.feedback_issue_states(issue_id);
alter table public.feedback_issue_states enable row level security;
revoke all on public.feedback_issue_states from public,anon,authenticated;
grant select on public.feedback_issue_states to authenticated;
create policy feedback_issue_states_own_read on public.feedback_issue_states
  for select to authenticated using ((select auth.uid())=user_id);
comment on table public.feedback_issue_states is 'Private per-account feedback notification preferences and read positions; writes only via validated RPCs and triggers.';

-- Match the issue-first locking order of feedback_action. Keep initialization
-- atomic with concurrent old clients sending messages during deployment.
lock table public.feedback_issues,public.feedback_messages in access exclusive mode;

insert into public.feedback_issue_states(user_id,issue_id,participated)
select creator_id,id,false from public.feedback_issues;
insert into public.feedback_issue_states(user_id,issue_id,participated)
select distinct sender_id,issue_id,true from public.feedback_messages
on conflict(user_id,issue_id) do update set participated=true;
-- Existing messages intentionally create no unread notifications.

create function feedback_private.track_issue_owner() returns trigger
language plpgsql security definer set search_path='' as $$
begin
  insert into public.feedback_issue_states(user_id,issue_id) values(new.creator_id,new.id)
    on conflict(user_id,issue_id) do nothing;
  return new;
end; $$;
revoke all on function feedback_private.track_issue_owner() from public,anon,authenticated;
create trigger feedback_issue_unread_owner after insert on public.feedback_issues
  for each row execute function feedback_private.track_issue_owner();

create function feedback_private.notify_issue_message() returns trigger
language plpgsql security definer set search_path='' as $$
declare owner_id uuid;
begin
  -- feedback_action already holds this lock before allocating a message ID.
  -- Also serialize direct privileged inserts with read/preference RPCs.
  select creator_id into owner_id from public.feedback_issues where id=new.issue_id for update;
  insert into public.feedback_issue_states(user_id,issue_id,participated)
    values(new.sender_id,new.issue_id,true)
    on conflict(user_id,issue_id) do update
      set participated=true,revision=public.feedback_issue_states.revision+1
      where not public.feedback_issue_states.participated;
  update public.feedback_issue_states
    set last_notified_id=greatest(last_notified_id,new.id),revision=revision+1
    where issue_id=new.issue_id and user_id<>new.sender_id
      and (preference='show' or (preference='unset' and (participated or user_id=owner_id)));
  return new;
end; $$;
revoke all on function feedback_private.notify_issue_message() from public,anon,authenticated;
create trigger feedback_message_unread after insert on public.feedback_messages
  for each row execute function feedback_private.notify_issue_message();

create function public.feedback_mark_read(p_issue uuid,p_through bigint) returns jsonb
language plpgsql security definer set search_path='' as $$
declare who uuid:=auth.uid(); latest bigint; result public.feedback_issue_states;
begin
  if who is null then raise exception '请先登录'; end if;
  if p_through is null or p_through<0 then raise exception '无效的已读位置'; end if;
  perform 1 from public.feedback_issues where id=p_issue for update;
  if not found then raise exception '问题不存在'; end if;
  select coalesce(max(id),0) into latest from public.feedback_messages where issue_id=p_issue;
  insert into public.feedback_issue_states(user_id,issue_id,last_read_id)
    values(who,p_issue,least(p_through,latest))
    on conflict(user_id,issue_id) do update
      set last_read_id=greatest(public.feedback_issue_states.last_read_id,excluded.last_read_id),
          revision=public.feedback_issue_states.revision+1
    returning * into result;
  return to_jsonb(result);
end; $$;
revoke all on function public.feedback_mark_read(uuid,bigint) from public,anon,authenticated;
grant execute on function public.feedback_mark_read(uuid,bigint) to authenticated;

create function public.feedback_set_unread_preference(p_issue uuid,p_preference text) returns jsonb
language plpgsql security definer set search_path='' as $$
declare who uuid:=auth.uid(); owner_id uuid; result public.feedback_issue_states;
begin
  if who is null then raise exception '请先登录'; end if;
  if p_preference is null or p_preference not in ('unset','show','hide') then raise exception '无效的未读红点设置'; end if;
  select creator_id into owner_id from public.feedback_issues where id=p_issue for update;
  if not found then raise exception '问题不存在'; end if;
  -- Clear disallowed unread in the same UPDATE/revision as the preference.
  insert into public.feedback_issue_states as s(user_id,issue_id,preference)
    values(who,p_issue,p_preference)
    on conflict(user_id,issue_id) do update
      set preference=excluded.preference,revision=s.revision+1,
          last_read_id=case when excluded.preference='hide' or
            (excluded.preference='unset' and not s.participated and who<>owner_id)
            then greatest(s.last_read_id,s.last_notified_id) else s.last_read_id end
    returning * into result;
  return to_jsonb(result);
end; $$;
revoke all on function public.feedback_set_unread_preference(uuid,text) from public,anon,authenticated;
grant execute on function public.feedback_set_unread_preference(uuid,text) to authenticated;

alter publication supabase_realtime add table public.feedback_issue_states;
