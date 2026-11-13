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
- 2026-11-13: Milestone M4 (energy modes F-08, basic life score F-09, fail-day next step F-10) moves from v1 to v2, the second build. v1 is now F-01 to F-07, F-11 and F-14. The full list of held features is in `docs/V2-FEATURES.md`.
- 2026-11-13 (after the founder's second M1 test):
  - Clicking a project opens a project page with all its tasks and the first line of each task's notes.
  - Every task has a Notes box (free text for that one task). This is not F-13 Notes; the separate Notes page stays in the later list.
  - Goals and life areas can have an icon from the same list as projects (now 17 icons, `flag` added). A life area may also have no icon; it then shows its dot.
  - A goal has its own colour, picked like a project colour (founder chose option A). Orange is not offered.
  - A project shows its goal as the goal's icon and name in the goal's colour, without the word "Goal:".
- 2026-11-13: M1 approved by the founder "for now"; design changes to M1 may follow later. M2 may start.
- 2026-11-13: Soft, fluid ("liquid") animation everywhere. One place holds the timing and curves (`lib/ui/motion.dart`). When Windows has animation effects turned off, the app does not animate. Screens follow the designs in `docs/design/source/`.
- 2026-11-13 (M2, Claude's choices; the founder can change them):
  - The Habits design shows streaks ("4-day streak"). The spec says no streak pressure, so habits show "x of 7 days" and a 30-day percent instead. Skip marks a planned rest day that does not count against the habit.
  - A habit has planned weekdays (every day by default). Days that are not planned do not count.
  - Focus sessions under one minute are not saved. Planned lengths offered: none, 25, 45, 60, 90 minutes.
  - While a timer runs, the Focus page is the full-window focus mode from the design; "Back to Orbito" (or Esc) leaves it and the timer stays in the side menu.
  - A night is filed under the morning the user woke up. One night per morning; saving again replaces it. A night of 0 hours or more than 16 hours asks the user to check the times. "How rested" (poor, okay, good, great) is optional, as in the design.
- 2026-11-13: Widgets for Windows, Android and iOS are wanted in a future version (new feature F-26, P2). Nothing is built in v1; v1 keeps the data and rules separate from the screens so widgets can be added later. Details are in `docs/V2-FEATURES.md`.

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
