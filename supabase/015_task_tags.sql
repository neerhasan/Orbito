-- Orbito: tags on a task, set in the add-task box (comma separated, lower
-- case, without "#"). Empty means no tags.
-- Run once in the Supabase SQL Editor, AFTER 014_task_duration.sql. Safe to re-run.
alter table public.tasks add column if not exists tags text;
grant select on public.tasks to powersync_fb6cf26de371f110edfdd022;
