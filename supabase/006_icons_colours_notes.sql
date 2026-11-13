-- Orbito M1 changes after the founder's second test (2026-11-13):
-- notes on a task, an icon and a colour on a goal, an icon on a life area.
-- Run once in the Supabase SQL Editor, AFTER 005_project_icon.sql.
-- It is safe to run more than once. The sync config uses SELECT *, so the
-- new columns reach the devices without a change there.

alter table public.tasks
  add column if not exists notes text;

alter table public.goals
  add column if not exists icon text,
  add column if not exists color text not null default 'blue';

alter table public.life_areas
  add column if not exists icon text;
