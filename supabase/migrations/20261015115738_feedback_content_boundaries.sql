-- Dart String.trim whitespace (including BOM) and exact activity fallback.
create or replace function feedback_private.validate_text(value text, maximum integer, single_line boolean default false) returns void
language plpgsql security definer set search_path='' as $$
declare whitespace text := chr(9)||chr(10)||chr(11)||chr(12)||chr(13)||chr(32)||chr(133)||chr(160)||chr(5760)||chr(8192)||chr(8193)||chr(8194)||chr(8195)||chr(8196)||chr(8197)||chr(8198)||chr(8199)||chr(8200)||chr(8201)||chr(8202)||chr(8232)||chr(8233)||chr(8239)||chr(8287)||chr(12288)||chr(65279);
begin
  if value is null or btrim(value,whitespace)='' or octet_length(value)>262144
     or feedback_private.grapheme_length(value)>maximum
     or (single_line and (position(chr(10) in value)>0 or position(chr(13) in value)>0 or position(chr(8232) in value)>0 or position(chr(8233) in value)>0)) then
    raise exception '内容不能为空且不得超过 % 个字符',maximum;
  end if;
end; $$;
create function feedback_private.initialize_issue() returns trigger
language plpgsql security definer set search_path='' as $$
begin new.last_message_at:=new.created_at; return new; end; $$;
revoke all on function feedback_private.initialize_issue() from public,anon,authenticated;
create trigger feedback_issue_initial_activity before insert on public.feedback_issues for each row execute function feedback_private.initialize_issue();
alter table feedback_private.bans enable row level security;
alter table feedback_private.audit enable row level security;
alter table feedback_private.rate_limits enable row level security;
