# Decisions and defaults

Decided by the founder:
- App name: Orbito. First release: Windows and Android, a closed test with friends at $0. Apple versions later.
- Stack: Flutter, SQLite with Drift, Supabase, PowerSync.
- Accounts, server and sync are in the first release.
- The approval process is paused until the founder has tested v1.
- 2026-11-11: M0 (sync proof) approved.
- 2026-11-11: Life areas: 3 to 8 is a suggestion shown to the user, not a limit. Any number is allowed.
- 2026-11-11: Build the Windows (PC) version first. Work on the Android screens starts only after the founder has finalised the PC version. The code stays shared and the Android build must keep compiling, but no Android layouts are designed or tested until then.
- 2026-11-12: Goal progress is automatic: tasks done out of all tasks that count for the goal. No slider. A goal with no tasks shows 0%. The hand-set `progress` column in the `goals` table is no longer used by any screen; it stays in the database for now.
- 2026-11-12 (after the founder's first M1 test): A task serves a project only, and the project serves the goal. A task has no goal of its own. The tasks that count for a goal are the tasks of its projects. The `goal_id` column of `tasks` is no longer written or read by the app; it stays in the database for now.
- 2026-11-12: A life area name can be used only once per user. Capital letters and spaces around the name do not make a name different.
- 2026-11-12: A project has an icon, picked from a fixed list of 16 (Claude chose the list; say if icons are missing).

Defaults used until the founder changes them:
- Sign-in: email and password, verification off during the test.
- Sync conflicts: latest change wins (server time).
- Life score: habits 40%, goals 40%, self-check 20%. Stages: Starting 0-39, Building 40-64, Established 65-84, Thriving 85+.
- UI language: English only.
- Android Today layout: option A.

Open (not blocking v1):
- Name availability (stores, domain, trademark). Search showed many apps named "Orbit".
- Which features are free and which are premium; price; billing (P1).
- Backups before public sales.
