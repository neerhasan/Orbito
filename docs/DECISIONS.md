# Decisions and defaults

Decided by the founder:
- App name: Orbito. First release: Windows and Android, a closed test with friends at $0. Apple versions later.
- Stack: Flutter, SQLite with Drift, Supabase, PowerSync.
- Accounts, server and sync are in the first release.
- The approval process is paused until the founder has tested v1.
- 2026-11-11: M0 (sync proof) approved.
- 2026-11-11: Life areas: 3 to 8 is a suggestion shown to the user, not a limit. Any number is allowed.
- 2026-11-11: Build the Windows (PC) version first. Work on the Android screens starts only after the founder has finalised the PC version. The code stays shared and the Android build must keep compiling, but no Android layouts are designed or tested until then.
- 2026-11-12: Goal progress is automatic: tasks done out of all tasks that count for the goal. No slider. Tasks that count: tasks linked straight to the goal, and tasks of the projects that serve the goal (this second part is Claude's reading of "linked", say if it is wrong). A goal with no tasks shows 0%. The hand-set `progress` column in the `goals` table is no longer used by any screen; it stays in the database for now.

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
