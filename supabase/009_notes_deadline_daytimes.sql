-- Orbito: Notes, a project deadline, and the wake and bed times.
-- Run once in the Supabase SQL Editor, AFTER 008_inbox_preferences.sql.
-- It is safe to run more than once.

-- 1. A project may have a deadline. Optional; the user can set, change or
--    clear it any time.
alter table public.projects add column if not exists deadline date;

-- 2. The user's usual wake time and bedtime (HH:MM), kept in preferences.
alter table public.preferences add column if not exists wake_time text;
alter table public.preferences add column if not exists bed_time text;

-- 3. Notes: a title and a body, optionally linked to one project.
create table if not exists public.notes (
  id uuid primary key,
  user_id uuid not null default auth.uid()
    references auth.users (id) on delete cascade,
  title text not null default '',
  body text not null default '',
  project_id uuid,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz
);

create index if not exists notes_user_id_idx on public.notes (user_id);

do $$
declare
  t text := 'notes';
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

-- Columns added to tables the PowerSync role already reads.
grant select on public.projects to powersync_fb6cf26de371f110edfdd022;
grant select on public.preferences to powersync_fb6cf26de371f110edfdd022;
