-- Orbito M2: habits, habit marks, focus sessions and the sleep log.
-- Run once in the Supabase SQL Editor, AFTER 006_icons_colours_notes.sql.
-- It is safe to run more than once.
--
-- Like the M1 tables, links (a mark's habit, a session's task) are plain
-- UUID columns without foreign keys, so the server accepts rows a device
-- uploads in any order.
--
-- A habit mark and a night of sleep are "one per day". The app makes their
-- id from the habit (or the user) and the day, so two devices that mark the
-- same day write the same row, and the latest change wins.

-- 1. Habits.
create table if not exists public.habits (
  id uuid primary key,
  user_id uuid not null default auth.uid()
    references auth.users (id) on delete cascade,
  name text not null,
  life_area_id uuid,
  -- Usual time of day as HH:MM, or empty.
  usual_time text,
  -- The planned weekdays as digits, Monday = 1 ... Sunday = 7.
  days text not null default '1234567',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz
);

-- 2. Habit marks: one row per habit and day. Un-marking deletes the row
--    (soft delete), so the day is open again.
create table if not exists public.habit_logs (
  id uuid primary key,
  user_id uuid not null default auth.uid()
    references auth.users (id) on delete cascade,
  habit_id uuid,
  day date not null default current_date,
  status text not null default 'done' check (status in ('done', 'skip')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz
);

-- 3. Focus sessions: the time worked, saved to a task (or to no task).
create table if not exists public.focus_sessions (
  id uuid primary key,
  user_id uuid not null default auth.uid()
    references auth.users (id) on delete cascade,
  task_id uuid,
  started_at timestamptz not null default now(),
  ended_at timestamptz not null default now(),
  focus_seconds integer not null default 0 check (focus_seconds >= 0),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz
);

-- 4. Sleep log: one night per morning date.
create table if not exists public.sleep_logs (
  id uuid primary key,
  user_id uuid not null default auth.uid()
    references auth.users (id) on delete cascade,
  -- The morning the user woke up.
  day date not null default current_date,
  bed_time text not null default '23:00',
  wake_time text not null default '07:00',
  rested text check (rested in ('poor', 'okay', 'good', 'great')),
  note text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz
);

create index if not exists habits_user_id_idx on public.habits (user_id);
create index if not exists habit_logs_user_id_idx on public.habit_logs (user_id);
create index if not exists focus_sessions_user_id_idx
  on public.focus_sessions (user_id);
create index if not exists sleep_logs_user_id_idx on public.sleep_logs (user_id);

-- 5. For each table: server time on every change, row-level security so a
--    signed-in user reads and changes only their own rows, and what
--    PowerSync needs to copy the table to devices.
do $$
declare
  t text;
begin
  foreach t in array array['habits', 'habit_logs', 'focus_sessions',
                           'sleep_logs'] loop
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

    -- The login PowerSync reads with (see 004_powersync_read.sql).
    execute format(
      'grant select on public.%I to powersync_fb6cf26de371f110edfdd022', t);
  end loop;
end;
$$;
