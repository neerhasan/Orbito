-- Orbito: the daily focus goal (minutes), shown in the Focus report.
-- Empty until the user picks one; the app then uses 4 hours.
-- Run once in the Supabase SQL Editor, AFTER 011_task_time.sql. Safe to re-run.
alter table public.preferences add column if not exists focus_goal_minutes integer;
grant select on public.preferences to powersync_fb6cf26de371f110edfdd022;
