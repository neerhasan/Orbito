-- PowerSync reads the database through the login that its "Connect Supabase"
-- wizard created (powersync_<id>). That login needs read access to every
-- synced table. 003_core_tables.sql gave it to `powersync_role` instead,
-- which PowerSync does not use, so validating the sync config failed with
-- "permission denied for table ...".
--
-- Every new synced table needs this grant too.
grant select on public.life_areas, public.goals, public.projects, public.tasks
  to powersync_fb6cf26de371f110edfdd022;
