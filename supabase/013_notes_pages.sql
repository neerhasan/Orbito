-- Orbito: notes become Notion-style pages.
-- A page can sit inside another page, has an emoji icon and a cover colour,
-- can be a favourite, goes to the Trash before it is deleted for good, and
-- keeps its content as editor blocks (JSON). `body` stays as a plain-text
-- copy of the content.
-- Run once in the Supabase SQL Editor, AFTER 012_focus_goal.sql. Safe to re-run.
alter table public.notes add column if not exists content text;
alter table public.notes add column if not exists parent_id uuid;
alter table public.notes add column if not exists icon text;
alter table public.notes add column if not exists cover text;
alter table public.notes add column if not exists favorite integer;
alter table public.notes add column if not exists trashed_at timestamptz;
alter table public.notes add column if not exists sort_order double precision;
create index if not exists notes_parent_id_idx on public.notes (parent_id);
grant select on public.notes to powersync_fb6cf26de371f110edfdd022;
