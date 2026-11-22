-- Orbito: how long a task with a time takes on the Calendar, in minutes
-- (set by dragging the bottom or top edge of its block). Empty means 30.
-- Run once in the Supabase SQL Editor, AFTER 013_notes_pages.sql. Safe to re-run.
alter table public.tasks add column if not exists duration_minutes integer;
grant select on public.tasks to powersync_fb6cf26de371f110edfdd022;
