-- Orbito M0: a separate database login for PowerSync.
-- Run this once in the Supabase SQL Editor, AFTER 001_sync_test.sql.
--
-- BEFORE you press Run: replace REPLACE_WITH_A_LONG_PASSWORD below with a
-- long password that you make up (letters and numbers only, 30 or more).
-- Do the replacement inside the Supabase SQL Editor only. Do not save the
-- password in this file, in Git or in any chat. You will type the same
-- password once into the PowerSync dashboard, so keep it in your password
-- manager.
--
-- This login can only read. PowerSync uses it to copy rows to devices and
-- decides per user what to send, using the sync config.

create role powersync_role
  with replication bypassrls login
  password 'REPLACE_WITH_A_LONG_PASSWORD';

grant select on all tables in schema public to powersync_role;
alter default privileges in schema public
  grant select on tables to powersync_role;
