-- Collapse queued notifications to the newest eligible message per issue.
-- Expiration also runs when Google credentials or OAuth are unavailable.
create or replace function public.feedback_claim_push_jobs(p_limit integer default 20) returns jsonb
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
        and s.last_notified_id=push_jobs.message_id and s.last_read_id<push_jobs.message_id and m.withdrawn_at is null));
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

create or replace function public.feedback_push_delivery(p_job bigint,p_lease uuid) returns jsonb
language sql stable security definer set search_path='' as $$
  select jsonb_build_object('token',d.token,'project_id',d.project_id,'user_id',j.user_id,
    'issue_id',j.issue_id,'message_id',j.message_id,'title',i.title)
  from feedback_private.push_jobs j join feedback_private.push_devices d on d.installation_id=j.installation_id
    join public.feedback_issue_states s on s.user_id=j.user_id and s.issue_id=j.issue_id
    join public.feedback_messages m on m.id=j.message_id join public.feedback_issues i on i.id=j.issue_id
  where j.id=p_job and j.lease_token=p_lease and j.status='processing'
    and j.expires_at>clock_timestamp() and d.user_id=j.user_id and d.enabled and d.token is not null
    and d.updated_at>clock_timestamp()-interval '90 days'
    and s.preference<>'hide' and s.last_notified_id=j.message_id and s.last_read_id<j.message_id and m.withdrawn_at is null;
$$;

create or replace function feedback_private.dispatch_push_jobs() returns void
language plpgsql security definer set search_path='' as $$
begin
  update feedback_private.push_jobs set status='cancelled',lease_token=null
    where status in ('pending','processing') and expires_at<=clock_timestamp();
  if exists(select 1 from feedback_private.push_jobs where (status='pending' and next_attempt_at<=clock_timestamp())
      or (status='processing' and locked_at<clock_timestamp()-interval '5 minutes')) then
    perform net.http_post(
      url:='https://jtvxrwybwvgpqobyhaoy.supabase.co/functions/v1/feedback-push',
      headers:=jsonb_build_object('Content-Type','application/json','x-feedback-push-secret',
        (select decrypted_secret from vault.decrypted_secrets where name='feedback_push_dispatch_secret')),
      body:='{}'::jsonb,timeout_milliseconds:=10000);
  end if;
end; $$;
