create table if not exists public.captcha_challenges (
  id uuid primary key,
  answer_hash text not null,
  attempts integer not null default 0,
  expires_at timestamptz not null,
  consumed_at timestamptz,
  created_at timestamptz not null default now(),
  constraint captcha_challenges_attempts_check check (attempts between 0 and 5)
);

create index if not exists captcha_challenges_expires_at_idx
  on public.captcha_challenges (expires_at);

alter table public.captcha_challenges enable row level security;

revoke all on table public.captcha_challenges from anon, authenticated;
grant all on table public.captcha_challenges to service_role;

create or replace function public.consume_captcha_challenge(
  p_challenge_id uuid,
  p_answer_hash text
)
returns boolean
language plpgsql
security definer
set search_path = public
as $$
declare
  stored_hash text;
begin
  select answer_hash
  into stored_hash
  from public.captcha_challenges
  where id = p_challenge_id
    and consumed_at is null
    and expires_at > now()
    and attempts < 5
  for update;

  if not found then
    return false;
  end if;

  update public.captcha_challenges
  set attempts = attempts + 1,
      consumed_at = case
        when stored_hash = p_answer_hash then now()
        else consumed_at
      end
  where id = p_challenge_id;

  return stored_hash = p_answer_hash;
end;
$$;

revoke all on function public.consume_captcha_challenge(uuid, text)
  from public, anon, authenticated;
grant execute on function public.consume_captcha_challenge(uuid, text)
  to service_role;
