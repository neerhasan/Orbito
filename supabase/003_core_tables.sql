-- Orbito M1: life areas, goals, projects and tasks.
-- Run this once in the Supabase SQL Editor, AFTER 001_sync_test.sql.
-- It is safe to run more than once.
--
-- The links between the tables (a goal's life area, a project's goal, a
-- task's project) are plain UUID columns without foreign keys. The app
-- works offline and deletes by marking rows, so the server must accept
-- every row a device uploads, in any order. The app keeps the links tidy.

-- 1. Life areas.
create table if not exists public.life_areas (
  id uuid primary key,
  user_id uuid not null default auth.uid()
    references auth.users (id) on delete cascade,
  name text not null,
  color text not null default 'grey',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz
);

-- 2. Goals. A goal may belong to one life area.
create table if not exists public.goals (
  id uuid primary key,
  user_id uuid not null default auth.uid()
    references auth.users (id) on delete cascade,
  title text not null,
  life_area_id uuid,
  target_date date,
  done_when text,
  progress integer not null default 0 check (progress between 0 and 100),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz
);

-- 3. Projects. A project may serve one goal.
create table if not exists public.projects (
  id uuid primary key,
  user_id uuid not null default auth.uid()
    references auth.users (id) on delete cascade,
  name text not null,
  goal_id uuid,
  color text not null default 'blue',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz
);

-- 4. Tasks. A task may belong to a project and may link to a goal.
create table if not exists public.tasks (
  id uuid primary key,
  user_id uuid not null default auth.uid()
    references auth.users (id) on delete cascade,
  title text not null,
  project_id uuid,
  goal_id uuid,
  due_date date,
  priority text not null default 'none'
    check (priority in ('none', 'medium', 'high')),
  status text not null default 'open'
    check (status in ('open', 'done')),
  completed_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz
);

create index if not exists life_areas_user_id_idx on public.life_areas (user_id);
create index if not exists goals_user_id_idx on public.goals (user_id);
create index if not exists projects_user_id_idx on public.projects (user_id);
create index if not exists tasks_user_id_idx on public.tasks (user_id);

-- 5. For each table: server time on every change, row-level security so a
--    signed-in user reads and changes only their own rows, and what
--    PowerSync needs to copy the table to devices.
do $$
declare
  t text;
begin
  foreach t in array array['life_areas', 'goals', 'projects', 'tasks'] loop
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
  end loop;
end;
$$;
