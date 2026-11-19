-- Orbito: a task may have a time on its due day (HH:MM, local time), set by
-- dragging it onto the Calendar grid or typed in the Quick Launcher.
-- Run once in the Supabase SQL Editor, AFTER 010_events.sql. Safe to re-run.
alter table public.tasks add column if not exists due_time text;
grant select on public.tasks to powersync_fb6cf26de371f110edfdd022;
