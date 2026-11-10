-- Orbito M0: the test table, its access rules and what PowerSync needs.
-- Paste this whole file into the Supabase SQL Editor and press Run.
-- It is safe to run more than once.

-- 1. The table. The id is a UUID made on the device.
create table if not exists public.sync_test (
  id uuid primary key,
  user_id uuid not null default auth.uid()
    references auth.users (id) on delete cascade,
  text text not null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz
);

create index if not exists sync_test_user_id_idx
  on public.sync_test (user_id);

-- 2. Server time decides which change is the latest, not the device clock.
create or replace function public.set_updated_at()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

drop trigger if exists sync_test_set_updated_at on public.sync_test;
create trigger sync_test_set_updated_at
  before insert or update on public.sync_test
  for each row execute function public.set_updated_at();

-- 3. Row-level security: a signed-in user can read and change only rows
--    where user_id is their own id. Nobody else gets anything.
alter table public.sync_test enable row level security;

drop policy if exists "sync_test: own rows only" on public.sync_test;
create policy "sync_test: own rows only"
  on public.sync_test
  for all
  to authenticated
  using ((select auth.uid()) = user_id)
  with check ((select auth.uid()) = user_id);

-- Let signed-in users reach the table at all. The rule above then limits
-- them to their own rows. People who are not signed in get no access.
revoke all on public.sync_test from anon;
revoke all on public.sync_test from authenticated;
grant select, insert, update, delete on public.sync_test to authenticated;

-- 4. What PowerSync needs to copy the table to devices.
alter table public.sync_test replica identity full;

do $$
begin
  if not exists (select 1 from pg_publication where pubname = 'powersync') then
    create publication powersync for table public.sync_test;
  elsif not exists (
    select 1 from pg_publication_tables
    where pubname = 'powersync'
      and schemaname = 'public'
      and tablename = 'sync_test'
  ) then
    alter publication powersync add table public.sync_test;
  end if;
end;
$$;
