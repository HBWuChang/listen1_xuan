-- Expose only the caller's action permission, never the administrator roster.
create function public.feedback_can_withdraw(p_message bigint) returns boolean
language sql stable security definer set search_path='' as $$
 select coalesce((select auth.uid() is not null and m.withdrawn_at is null and
   case when feedback_private.is_admin(m.sender_id) then auth.uid()=m.sender_id
   else feedback_private.is_admin(auth.uid()) or i.creator_id=auth.uid()
     or (m.sender_id=auth.uid() and clock_timestamp()<=m.created_at+interval '300 seconds') end
 from public.feedback_messages m join public.feedback_issues i on i.id=m.issue_id where m.id=p_message),false);
$$;
revoke all on function public.feedback_can_withdraw(bigint) from public,anon,authenticated;
grant execute on function public.feedback_can_withdraw(bigint) to anon,authenticated;
