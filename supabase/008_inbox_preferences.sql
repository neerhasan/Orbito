-- Orbito M3: the Inbox and the user's preferences (Today sections).
-- Run once in the Supabase SQL Editor, AFTER 007_daily_tables.sql.
-- It is safe to run more than once.

-- 1. Inbox: lines from the Quick Launcher that were not sorted yet, and
--    notes (kind 'note') until Notes exist as their own feature.
create table if not exists public.inbox_items (
  id uuid primary key,
  user_id uuid not null default auth.uid()
    references auth.users (id) on delete cascade,
  text text not null,
  kind text not null default 'inbox' check (kind in ('inbox', 'note')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz
);

-- 2. Preferences: one row per user (the app makes its id from the user),
--    so every device shows the same Today sections in the same order.
create table if not exists public.preferences (
  id uuid primary key,
  user_id uuid not null default auth.uid()
    references auth.users (id) on delete cascade,
  -- The Today sections that are on, in order, comma separated.
  today_sections text not null default '',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz
);

create index if not exists inbox_items_user_id_idx on public.inbox_items (user_id);
create index if not exists preferences_user_id_idx on public.preferences (user_id);

do $$
declare
  t text;
begin
  foreach t in array array['inbox_items', 'preferences'] loop
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
  end loop;
end;
$$;
