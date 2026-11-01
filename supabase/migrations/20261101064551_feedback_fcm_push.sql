-- FCM credentials live in Edge Function secrets, never in a client or migration.
create extension if not exists pg_net with schema extensions;
create extension if not exists pg_cron;

create table feedback_private.push_devices (
  installation_id uuid primary key,
  user_id uuid not null references auth.users(id) on delete cascade,
  secret_hash bytea not null,
  token text unique,
  project_id text not null,
  enabled boolean not null default true,
  updated_at timestamptz not null default clock_timestamp()
);
create index feedback_push_devices_user on feedback_private.push_devices(user_id);
alter table feedback_private.push_devices enable row level security;
revoke all on feedback_private.push_devices from public,anon,authenticated;

create table feedback_private.push_jobs (
  id bigint generated always as identity primary key,
  installation_id uuid not null references feedback_private.push_devices(installation_id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  issue_id uuid not null references public.feedback_issues(id) on delete cascade,
  message_id bigint not null references public.feedback_messages(id) on delete cascade,
  status text not null default 'pending' check(status in ('pending','processing','sent','cancelled','failed')),
  attempts integer not null default 0,
  next_attempt_at timestamptz not null default clock_timestamp(),
  locked_at timestamptz,
  lease_token uuid,
  created_at timestamptz not null default clock_timestamp(),
  expires_at timestamptz not null default clock_timestamp()+interval '24 hours',
  last_error text,
  unique(installation_id,message_id)
);
create index feedback_push_jobs_due on feedback_private.push_jobs(next_attempt_at,id) where status='pending';
create index feedback_push_jobs_processing on feedback_private.push_jobs(locked_at) where status='processing';
create index feedback_push_jobs_device on feedback_private.push_jobs(installation_id);
create index feedback_push_jobs_user on feedback_private.push_jobs(user_id);
create index feedback_push_jobs_issue on feedback_private.push_jobs(issue_id);
create index feedback_push_jobs_message on feedback_private.push_jobs(message_id);
alter table feedback_private.push_jobs enable row level security;
revoke all on feedback_private.push_jobs from public,anon,authenticated;

create function public.feedback_register_push_device(p_installation uuid,p_secret text,p_token text,p_project text) returns void
language plpgsql security definer set search_path='' as $$
declare who uuid:=auth.uid(); existing feedback_private.push_devices;
begin
  if who is null then raise exception '请先登录'; end if;
  if p_installation is null or p_secret is null or length(p_secret) not between 32 and 256
      or p_token is null or length(p_token) not between 20 and 4096
      or p_project is null or p_project !~ '^[a-z0-9][a-z0-9-]{3,62}$' then raise exception '无效的推送设备'; end if;
  perform pg_advisory_xact_lock(hashtextextended('feedback-push-device:'||p_installation::text,0));
  select * into existing from feedback_private.push_devices where installation_id=p_installation;
  if found and existing.secret_hash<>extensions.digest(p_secret,'sha256') then raise exception '设备凭据不匹配'; end if;
  insert into feedback_private.push_devices(installation_id,user_id,secret_hash,token,project_id)
    values(p_installation,who,extensions.digest(p_secret,'sha256'),p_token,p_project)
    on conflict(installation_id) do update set user_id=who,token=excluded.token,project_id=excluded.project_id,enabled=true,updated_at=clock_timestamp();
  update feedback_private.push_jobs set status='cancelled',lease_token=null
    where installation_id=p_installation and user_id<>who and status in ('pending','processing');
end; $$;
revoke all on function public.feedback_register_push_device(uuid,text,text,text) from public,anon,authenticated;
grant execute on function public.feedback_register_push_device(uuid,text,text,text) to authenticated;

-- Revocation also works just after logout, using an unguessable installation
-- capability. It discloses no account/token and cannot register a device.
create function public.feedback_unregister_push_device(p_installation uuid,p_secret text) returns void
language plpgsql security definer set search_path='' as $$
begin
  if p_installation is null or p_secret is null or length(p_secret) not between 32 and 256 then return; end if;
  perform pg_advisory_xact_lock(hashtextextended('feedback-push-device:'||p_installation::text,0));
  update feedback_private.push_devices set enabled=false,token=null,updated_at=clock_timestamp()
    where installation_id=p_installation and secret_hash=extensions.digest(p_secret,'sha256');
  if found then
    update feedback_private.push_jobs set status='cancelled',lease_token=null
      where installation_id=p_installation and status in ('pending','processing');
  end if;
end; $$;
revoke all on function public.feedback_unregister_push_device(uuid,text) from public,anon,authenticated;
grant execute on function public.feedback_unregister_push_device(uuid,text) to anon,authenticated;

-- A narrow, randomly generated dispatch capability is kept in Vault. Neither
-- this migration nor the Edge Function needs to export it to a local file.
do $$ begin
  if not exists(select 1 from vault.secrets where name='feedback_push_dispatch_secret') then
    perform vault.create_secret(encode(extensions.gen_random_bytes(32),'hex'),'feedback_push_dispatch_secret');
  end if;
end; $$;

create function public.feedback_push_authorized(p_secret text) returns boolean
language sql stable security definer set search_path='' as $$
  select p_secret is not null and length(p_secret)=64 and exists(
    select 1 from vault.decrypted_secrets where name='feedback_push_dispatch_secret'
      and extensions.digest(decrypted_secret,'sha256')=extensions.digest(p_secret,'sha256'));
$$;
revoke all on function public.feedback_push_authorized(text) from public,anon,authenticated;
grant execute on function public.feedback_push_authorized(text) to service_role;

create function feedback_private.enqueue_push_message() returns trigger
language plpgsql security definer set search_path='' as $$
begin
  if new.last_notified_id<=new.last_read_id or new.preference='hide' then return new; end if;
  if tg_op='UPDATE' then
    if new.last_notified_id<=old.last_notified_id then return new; end if;
  end if;
  insert into feedback_private.push_jobs(installation_id,user_id,issue_id,message_id)
    select d.installation_id,new.user_id,new.issue_id,new.last_notified_id
    from feedback_private.push_devices d
    where d.user_id=new.user_id and d.enabled and d.token is not null
      and d.updated_at>clock_timestamp()-interval '90 days'
    on conflict(installation_id,message_id) do nothing;
  return new;
end; $$;
revoke all on function feedback_private.enqueue_push_message() from public,anon,authenticated;
create trigger feedback_unread_push after insert or update of last_notified_id on public.feedback_issue_states
  for each row execute function feedback_private.enqueue_push_message();

create function public.feedback_claim_push_jobs(p_limit integer default 20) returns jsonb
language plpgsql security definer set search_path='' as $$
declare result jsonb;
begin
  -- Expired leases may be retried; old workers cannot acknowledge a new lease.
  update feedback_private.push_jobs set status=case when attempts>=5 then 'failed' else 'pending' end,lease_token=null
    where status='processing' and locked_at<clock_timestamp()-interval '5 minutes';
  update feedback_private.push_jobs set status='cancelled',lease_token=null
    where status='pending' and (expires_at<=clock_timestamp() or not exists(
      select 1 from feedback_private.push_devices d join public.feedback_issue_states s
        on s.user_id=d.user_id and s.issue_id=push_jobs.issue_id
      join public.feedback_messages m on m.id=push_jobs.message_id
      where d.installation_id=push_jobs.installation_id and d.user_id=push_jobs.user_id
        and d.enabled and d.token is not null and s.preference<>'hide'
        and s.last_read_id<push_jobs.message_id and m.withdrawn_at is null));
  with candidates as (
    select id from feedback_private.push_jobs where status='pending' and next_attempt_at<=clock_timestamp()
      order by id for update skip locked limit least(greatest(p_limit,1),50)
  ), claimed as (
    update feedback_private.push_jobs j set status='processing',attempts=attempts+1,
      locked_at=clock_timestamp(),lease_token=gen_random_uuid()
    from candidates c where j.id=c.id returning j.id,j.lease_token
  ) select coalesce(jsonb_agg(to_jsonb(claimed)),'[]') into result from claimed;
  return result;
end; $$;
revoke all on function public.feedback_claim_push_jobs(integer) from public,anon,authenticated;
grant execute on function public.feedback_claim_push_jobs(integer) to service_role;

create function public.feedback_push_delivery(p_job bigint,p_lease uuid) returns jsonb
language sql stable security definer set search_path='' as $$
  select jsonb_build_object('token',d.token,'project_id',d.project_id,'user_id',j.user_id,
    'issue_id',j.issue_id,'message_id',j.message_id,'title',i.title)
  from feedback_private.push_jobs j join feedback_private.push_devices d on d.installation_id=j.installation_id
    join public.feedback_issue_states s on s.user_id=j.user_id and s.issue_id=j.issue_id
    join public.feedback_messages m on m.id=j.message_id join public.feedback_issues i on i.id=j.issue_id
  where j.id=p_job and j.lease_token=p_lease and j.status='processing'
    and j.expires_at>clock_timestamp() and d.user_id=j.user_id and d.enabled and d.token is not null
    and d.updated_at>clock_timestamp()-interval '90 days'
    and s.preference<>'hide' and s.last_read_id<j.message_id and m.withdrawn_at is null;
$$;
revoke all on function public.feedback_push_delivery(bigint,uuid) from public,anon,authenticated;
grant execute on function public.feedback_push_delivery(bigint,uuid) to service_role;

create function public.feedback_complete_push_job(p_job bigint,p_lease uuid,p_status text,p_error text default null,p_invalid_token text default null) returns void
language plpgsql security definer set search_path='' as $$
declare job feedback_private.push_jobs;
begin
  if p_status is null or p_status not in ('sent','cancelled','retry','failed') then raise exception 'Invalid push result'; end if;
  select * into job from feedback_private.push_jobs where id=p_job and lease_token=p_lease and status='processing';
  if not found then return; end if;
  -- Device before job matches registration/revocation's lock order.
  if p_invalid_token is not null then
    update feedback_private.push_devices set enabled=false,token=null
      where installation_id=job.installation_id and user_id=job.user_id and token=p_invalid_token;
  end if;
  update feedback_private.push_jobs set
    status=case when p_status='retry' and attempts<5 then 'pending' when p_status='retry' then 'failed' else p_status end,
    next_attempt_at=clock_timestamp()+make_interval(secs=>least(3600,30*power(2,attempts)::integer)),
    lease_token=null,last_error=left(p_error,80)
    where id=p_job and lease_token=p_lease and status='processing';
end; $$;
revoke all on function public.feedback_complete_push_job(bigint,uuid,text,text,text) from public,anon,authenticated;
grant execute on function public.feedback_complete_push_job(bigint,uuid,text,text,text) to service_role;

create function feedback_private.dispatch_push_jobs() returns void
language plpgsql security definer set search_path='' as $$
begin
  if exists(select 1 from feedback_private.push_jobs where (status='pending' and next_attempt_at<=clock_timestamp())
      or (status='processing' and locked_at<clock_timestamp()-interval '5 minutes')) then
    perform net.http_post(
      url:='https://jtvxrwybwvgpqobyhaoy.supabase.co/functions/v1/feedback-push',
      headers:=jsonb_build_object('Content-Type','application/json','x-feedback-push-secret',
        (select decrypted_secret from vault.decrypted_secrets where name='feedback_push_dispatch_secret')),
      body:='{}'::jsonb,timeout_milliseconds:=10000);
  end if;
end; $$;
revoke all on function feedback_private.dispatch_push_jobs() from public,anon,authenticated;

create function feedback_private.wake_push_worker() returns trigger
language plpgsql security definer set search_path='' as $$
begin perform feedback_private.dispatch_push_jobs(); return null; end; $$;
revoke all on function feedback_private.wake_push_worker() from public,anon,authenticated;
create trigger feedback_push_wake after insert on feedback_private.push_jobs
  for each statement execute function feedback_private.wake_push_worker();

select cron.schedule('feedback-push-retry','* * * * *','select feedback_private.dispatch_push_jobs()');
-- Keep terminal delivery records for seven days; no chat contents are copied.
select cron.schedule('feedback-push-cleanup','23 3 * * *',
  $cron$delete from feedback_private.push_jobs where status in ('sent','cancelled','failed') and created_at<now()-interval '7 days'$cron$);
