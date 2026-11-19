-- Orbito: calendar events (the Calendar page).
-- Run once in the Supabase SQL Editor, AFTER 009_notes_deadline_daytimes.sql.
-- It is safe to run more than once.

create table if not exists public.events (
  id uuid primary key,
  user_id uuid not null default auth.uid()
    references auth.users (id) on delete cascade,
  title text not null default '',
  -- The day of the event, and its start and end as HH:MM (local time).
  day date not null default current_date,
  start_time text not null default '09:00',
  end_time text not null default '10:00',
  project_id uuid,
  note text not null default '',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz
);

create index if not exists events_user_id_idx on public.events (user_id);

do $$
declare
  t text := 'events';
begin
  if not exists (
    select 1 from pg_trigger
    where tgname = t || '_set_updated_at' and not tgisinternal
  ) then
    execute format(
      'create trigger %I before insert or update on public.%I '
      'for each row execute function public.set_updated_at()',
      t || '_set_updated_at', t);
  end if;

  execute format('alter table public.%I enable row level security', t);

  if not exists (
    select 1 from pg_policies
    where schemaname = 'public' and tablename = t
      and policyname = t || ': own rows only'
  ) then
    execute format(
      'create policy %I on public.%I for all to authenticated '
      'using ((select auth.uid()) = user_id) '
      'with check ((select auth.uid()) = user_id)',
      t || ': own rows only', t);
  end if;

  execute format('revoke all on public.%I from anon', t);
  execute format('revoke all on public.%I from authenticated', t);
  execute format(
    'grant select, insert, update, delete on public.%I to authenticated', t);

  execute format('alter table public.%I replica identity full', t);

  if not exists (
    select 1 from pg_publication_tables
    where pubname = 'powersync' and schemaname = 'public' and tablename = t
  ) then
    execute format('alter publication powersync add table public.%I', t);
  end if;

  execute format(
    'grant select on public.%I to powersync_fb6cf26de371f110edfdd022', t);
end;
$$;
