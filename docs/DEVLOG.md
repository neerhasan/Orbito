# Development log

Claude Code adds a new entry on top at the end of every session.

### 2026-11-12 M1 fixes after the founder's first test
- Done:
  - PowerSync could not read the four new tables ("permission denied"): the read access in `003_core_tables.sql` went to the wrong login. Fixed on the server and recorded in `supabase/004_powersync_read.sql`. The founder then deployed the sync config.
  - A life area name can be used only once. `PlanRepository.addArea` and `updateArea` refuse a duplicate (`DuplicateNameException`); the Life areas page shows "You already have an area with this name."; first-run setup skips a name that already exists.
  - A project has an icon. New column `projects.icon` (`supabase/005_project_icon.sql`, applied through the Supabase connector), 16 icons in `ProjectIcons`, an icon picker on the project form.
  - A task serves a project only. The goal box is gone from the task form (it shows which goal the project serves), tasks can no longer be added on the Goals page, and a goal counts only the tasks of its projects.
- Left to do: the founder tests again with `docs/M1-TEST.md` (updated).
- Known problems:
  - Duplicate areas made before this fix are not removed. The founder deletes the extra ones on the Life areas page.
  - The "only once" rule is checked on the device. Two devices that are both offline can still each create the same name; after sync both exist. A rule on the server would block the upload and stop sync, so there is none.
  - Tasks that were linked straight to a goal before this fix keep that link in the database, but no screen shows or counts it. They are tasks without a project now.
  - The `goal_id` column of `tasks` and the `progress` column of `goals` are unused.
- Files changed: `lib/data/repositories/plan_repository.dart`, `lib/data/repositories/task_repository.dart`, `lib/data/local/app_database.dart` (and its generated file), `lib/data/sync/powersync_schema.dart`, `lib/domain/progress.dart`, `lib/domain/task_view.dart`, `lib/ui/ember.dart`, `lib/ui/widgets.dart`, the four page files and the setup page, the tests, `supabase/004_powersync_read.sql`, `supabase/005_project_icon.sql`, `docs/DECISIONS.md`, `docs/M1-TEST.md`.
- Test results: `flutter analyze`: no issues. `flutter test`: 85 passed, 0 skipped. `flutter build windows --release`: built.
- Next step: the founder's second M1 test.

### 2026-11-12 M1 steps 4 and 5 of 5: Tasks page and test guide (Windows)
- Done:
  - Tasks page (`lib/features/tasks/tasks_page.dart`): one-line rows with the priority next to the title and the project name on the right in the project's colour; a box to add a task; list view with grouping (due date, project, goal, priority, none), sorting (due date, priority, newest, title) and filters (status, project, goal, priority); a month view; on the right a form to change or delete the selected task.
  - Completion chart (`lib/features/tasks/completion_chart.dart`): tasks completed per day with a toggle for week, 2 weeks, month and year. Drawn by the app itself, no new package.
  - The rules for filtering, sorting, grouping, the chart numbers and the month grid are plain functions in `lib/domain/task_view.dart`, with their own tests.
  - The screens now ask `clockProvider` for the time, so tests can set the day.
  - `docs/M1-TEST.md`: the founder's hands-on test guide for M1.
- Left to do: the founder runs `docs/M1-TEST.md` and approves or reports problems. Then M2.
- Known problems:
  - The founder has still not pasted `powersync/sync-config.yaml` into PowerSync. Until then the new tables do not reach the server. This is step 1 of the test guide.
  - Claude did not click through the real Windows app. The pages were checked with automatic tests and by eye on pictures drawn from the same code with sample data. The first real click-through is the founder's test.
  - The date picker (goal target date, task due date) is not covered by an automatic test.
  - Orange is used for "now" (overdue, today) and, as in the design files, for the high-priority ring and label. If orange must mean only "now", the high-priority colour needs the founder's choice.
  - The goal filter and the "Goal" grouping count a task for a goal when it is linked directly or through its project.
  - In the month view a day shows at most three tasks, then "+N more". There is no way yet to open the full list of that day except the list view.
  - A new task typed on the Tasks page takes over the active project, goal and priority filters, so it stays visible. It never gets a due date.
  - The layout is for a desktop window; narrow windows and the phone are not handled (decision: PC first).
- Files changed: `lib/features/tasks/tasks_page.dart`, `lib/features/tasks/completion_chart.dart`, `lib/domain/task_view.dart`, `lib/app/app.dart`, `lib/app/providers.dart`, `test/task_view_test.dart`, `test/plan_pages_test.dart`, `docs/M1-TEST.md`, `docs/DECISIONS.md`.
- Test results: `flutter analyze`: no issues. `flutter test`: 83 passed, 0 skipped, including the access-rule test for all five tables against the real server. `flutter build windows --release`: built, and the app starts. The Android build was not run in this session.
- Next step: the founder's M1 test. No M2 work before the founder approves M1.

### 2026-11-12 M1 step 3 of 5, part 2: Goals page (Windows)
- Done:
  - The founder chose: goal progress is automatic from tasks (recorded in `docs/DECISIONS.md`).
  - Goals page (`lib/features/goals/goals_page.dart`): list with life area, target date and percent; a form with title, life area, target date and "done when"; the projects that serve the goal; the goal's own tasks with a complete button and a quick "add task" box; delete with the keep-or-delete question.
  - The progress rules are in one file, `lib/domain/progress.dart`: percent of tasks done, and which tasks count for a goal.
- Left to do: M1 step 4 (the Tasks page) and step 5 (test guide).
- Known problems:
  - `PlanRepository.setGoalProgress` and the `progress` column are unused now. Not removed: removing a column needs a change on the server too.
  - The target date opens Flutter's standard date picker. It was not checked by Claude in the real app, and no automatic test opens it.
  - The founder has still not pasted `powersync/sync-config.yaml` into PowerSync.
- Files changed: `lib/features/goals/goals_page.dart`, `lib/domain/progress.dart`, `lib/features/projects/projects_page.dart`, `lib/app/app.dart`, `test/progress_test.dart`, `test/plan_pages_test.dart`, `docs/DECISIONS.md`.
- Test results: `flutter analyze`: no issues. `flutter test`: 60 passed, 0 skipped. The Windows app was not rebuilt or opened after this part.
- Next step: M1 step 4, the Tasks page.

### 2026-11-11 M1 step 3 of 5, part 1: first-run setup, Life areas page, Projects page (Windows)
- Done:
  - First-run setup (`lib/features/setup/setup_page.dart`): ten suggested life areas to pick from, "Skip for now", and a note while the first download from the server has not finished.
  - Life areas page (`lib/features/areas/areas_page.dart`): list with goal counts, a form to add, rename, recolour and delete. Deleting an area with goals asks: keep the goals or delete them too.
  - Projects page (`lib/features/projects/projects_page.dart`): list with percent from tasks done, a form with name, goal and colour, the project's tasks with a complete button, a quick "add task" box, and delete with the same keep-or-delete question.
  - Date helpers in `lib/domain/dates.dart`.
- Left to do: the Goals page (waits for the founder's answer on goal progress), the Tasks page, the test guide.
- Known problems:
  - The founder has not yet pasted the new `powersync/sync-config.yaml` into PowerSync. Until then areas, goals, projects and tasks stay on the device and do not reach the server.
  - Deleting the last life area brings the first-run setup back. "Skip for now" lasts only until the app closes.
  - The tests found one layout bug (the text on a suggestion tile was 2 pixels too tall); fixed.
- Files changed: `lib/features/setup/setup_page.dart`, `lib/features/areas/areas_page.dart`, `lib/features/projects/projects_page.dart`, `lib/domain/dates.dart`, `lib/ui/widgets.dart`, `lib/app/app.dart`, `lib/app/providers.dart`, `test/plan_pages_test.dart`; formatting only in some other files.
- Test results: `flutter analyze`: no issues. `flutter test`: 54 passed, 0 skipped (5 new page tests). `flutter build windows --release`: built. The app was started on the PC and the setup screen was checked by eye from a picture of the window. Adding areas and projects by hand in the real app was not done by Claude; the page tests cover it.
- Next step: the Goals page, then M1 step 4, the Tasks page.

### 2026-11-11 M1 step 2 of 5: app frame and look (Windows)
- Done:
  - The Ember look in code: colours, text styles and the theme (`lib/ui/ember.dart`), shared parts such as panel, tile, tag and colour picker (`lib/ui/widgets.dart`).
  - The Inter font is in the app as one variable font file (`assets/fonts/Inter.ttf`, licence in `assets/fonts/Inter-OFL.txt`). No new package.
  - The app frame (`lib/app/shell.dart`): side menu with Tasks, Projects, Goals and Life areas, the sync status, the email and sign out.
  - The sign-in screen moved to `lib/features/auth/` and was restyled. It has a button to show the typed password.
  - The M0 test screen, its repository and its tests were removed. The table `sync_test` stays on the server and in the sync config.
- Left to do: M1 steps 3 to 5. The four pages show "This page is being built" for now.
- Known problems:
  - The side menu has a fixed width and the layout is made for a desktop window. Narrow windows and the phone are not handled yet (decision: PC first).
  - The sign-in screen has no "forgot password" link. Password reset belongs to M5.
- Files changed: `lib/ui/ember.dart`, `lib/ui/widgets.dart`, `lib/app/shell.dart`, `lib/app/app.dart`, `lib/app/providers.dart`, `lib/features/auth/sign_in_screen.dart`, `test/widget_test.dart`, `pubspec.yaml`, `assets/fonts/`; removed `lib/features/sync_test/`, `lib/data/repositories/sync_test_repository.dart`, `test/sync_test_repository_test.dart`.
- Test results: `flutter analyze`: no issues. `flutter test`: 49 passed, 0 skipped. `flutter build windows --debug`: built. The app was started on the PC and the frame was checked by eye from a picture of the window: signed in, status "Synced", fonts and colours as designed. The Android build was not run in this step.
- Next step: M1 step 3, first-run setup and the pages for life areas, goals and projects.

### 2026-11-11 M1 step 1 of 5: data layer for life areas, goals, projects and tasks
- Done:
  - The founder approved M0. The GitHub Actions run that uses the three variables finished green with both downloads (`orbito-windows`, `orbito-android-apk`).
  - Decisions recorded in `docs/DECISIONS.md`: life areas have a suggestion of 3 to 8, not a limit; the Windows version is built first, Android screens start after the founder finalises it.
  - Four new tables on Supabase: `life_areas`, `goals`, `projects`, `tasks` (`supabase/003_core_tables.sql`, applied through the Supabase connector). Each has row-level security, the server-time trigger, and is in the `powersync` publication. Checked on the server.
  - The same four tables on the device (Drift and the PowerSync schema), with shared columns in one place (`SyncColumns`).
  - `PlanRepository` (life areas, goals, projects) and `TaskRepository`. Deleting an area, goal or project takes a choice: keep the linked items and remove the link, or delete them too. Counting methods exist for the warning text.
  - The access-rule test now runs for every synced table.
- Left to do:
  - The founder pastes the new `powersync/sync-config.yaml` into PowerSync. Until then the new tables do not sync.
  - M1 steps 2 to 5: app frame and look, setup and the area, goal and project pages, the Tasks page, testing.
  - Open question for the founder: goal progress. The feature list says completing a task updates the related goal; the prototype has a hand-set slider. The data layer keeps a hand-set `progress` number for now.
- Known problems:
  - The links between the tables have no foreign keys on the server, on purpose: the app works offline and must be able to upload rows in any order. The app keeps the links tidy.
  - Tasks hold only what feature F-01 lists (title, project, goal, due date, priority). The prototype also has subtasks, tags, a time of day, an estimate and "postponed" counts. These are not built.
  - Supabase's security check reports one warning: "Leaked password protection" is off. It checks new passwords against a list of leaked ones. Not changed.
  - The code generator (`dart run build_runner build`) ran out of memory once when run together with other commands. It worked when run alone.
- Files changed: `supabase/003_core_tables.sql`, `powersync/sync-config.yaml`, `lib/data/local/app_database.dart` (and its generated file), `lib/data/sync/powersync_schema.dart`, `lib/data/repositories/plan_repository.dart`, `lib/data/repositories/task_repository.dart`, `lib/app/providers.dart`, `test/plan_repository_test.dart`, `test/task_repository_test.dart`, `test/integration/rls_test.dart`, `docs/DECISIONS.md`.
- Test results: `flutter analyze`: no issues. `flutter test`: 52 passed, 0 skipped, including the access-rule test for all five tables against the real server. The app itself was not started in this step; no screen uses the new tables yet.
- Next step: M1 step 2, the app frame and look.

### 2026-11-11 M0: all five manual tests passed on the PC and the phone
- Done:
  - The app is installed on the founder's Android phone (iQOO Neo 9, Android 16) and runs with the real settings.
  - Test 1 passed: the same account (`test3@orbito.test`) is signed in on the PC and the phone, both show **Sync: Synced**.
  - Test 2 passed: a row added on the PC appears on the phone, and a row added on the phone appears on the PC.
  - Test 3 passed in both directions. Checked on the server: `added offline` (phone) was made at 05:50:16 UTC and arrived at 05:50:51; `pc offline` (PC) was made at 05:53:00 UTC and arrived at 05:53:31. Both arrived only after the network came back.
  - Test 4 passed by hand: a second account on the phone shows an empty list, and its new row does not appear on the PC.
  - Test 5 passed: after closing and restarting the PC app, the user is still signed in and the rows are still there.
  - The automatic access-rule test passed against the real server (`flutter test test/integration/rls_test.dart`: "All tests passed!", not skipped): a second account cannot read, change, delete or forge the first account's rows.
  - `.gitignore` now ignores every file that starts with `.env.`, after a file with passwords was saved for a moment under the name `.env.test.example`. It was never committed.
  - The founder added the three public values as GitHub Actions variables. Whether the builds pick them up is not checked yet: it needs a run that starts after they were added.
- Left to do:
  - Confirm that a GitHub Actions run started after the variables were added turns green, and that its app starts without the "not set up yet" screen.
  - With the founder's agreement: remove the unused database login `powersync_role`, and the extra test accounts.
  - The founder approves M0. M1 does not start before that.
- Known problems:
  - Installing over the USB cable failed: the PC saw the phone, but commands froze. Installing over Wi-Fi (**Wireless debugging**) worked. The cable or the USB port is the likely cause; this was not investigated further.
  - On this phone an install question shows for about 10 seconds. If nobody taps it, the install ends with `INSTALL_FAILED_ABORTED: User rejected permissions`.
  - Sign-in was refused several times because of small typing differences in the email. Five test accounts exist on the server now. The sign-in screen has no "forgot password" option and no way to show the typed password. Both are worth adding with the real sign-in screen.
- Files changed: `docs/DEVLOG.md`, `docs/M0-SETUP.md`.
- Test results: the five manual tests above passed. No code changed since the last run of `flutter analyze` (no issues) and `flutter test` (24 passed, 1 skipped).
- Next step: the founder fills in `.env.test` for the automatic access-rule test.

### 2026-11-11 M0: servers created, sync proven from the PC (phone tests still open)
- Done:
  - Supabase project `orbito` created (region Mumbai, `ap-south-1`). Email confirmation is off. Table `sync_test` is live with row-level security, one policy, the server-time trigger and the `powersync` publication. Supabase's security check reports no problems.
  - PowerSync project "Orbito" created (region IN, one instance), connected with the **Connect Supabase** button, sync config deployed, Supabase sign-in turned on.
  - `.env` filled in by the founder. The Windows app was rebuilt with the real settings.
  - On the PC: account created, test screen opens, status line shows **Sync: Synced**, the row `from pc` was added. Checked on the server: the row is in Supabase with the right user, and PowerSync's replication slot is active.
  - The GitHub Actions run for the first M0 commit finished green.
  - `supabase/001_sync_test.sql`: signed-in users now get only select, insert, update and delete. Supabase's defaults had also given truncate, references and trigger.
  - `docs/M0-SETUP.md` updated to the steps that really worked.
- Left to do:
  - Phone: install the app, sign in with the same account, then Tests 2 to 5 in `docs/M0-SETUP.md` (row travels both ways, offline then reconnect, second account sees nothing, restart keeps data).
  - Founder fills in `.env.test`, then run the access-rule test against the real server.
  - GitHub: add the three public values as Actions variables.
  - With the founder's agreement: remove the unused database login `powersync_role`.
- Known problems:
  - Sync is proven in one direction only (PC to server). Server to device, the phone and the offline case are not tested yet. M0 is not finished.
  - PowerSync rejected sign-in at first: `PSYNC_S2105 Unexpected "aud" claim value: "authenticated"`. Fix: add `authenticated` under **JWT Audience** in PowerSync Client Auth.
  - The hand-made login `powersync_role` (from `supabase/002_powersync_role.sql`) is unused, because the Connect Supabase button made its own login. It still exists in the database.
  - The repository is public now. The older entry below still says private.
  - The Supabase connector declines SQL that contains `drop` statements, so the live table was created without the `drop ... if exists` lines of the SQL file. The result is the same on an empty project.
- Files changed: `supabase/001_sync_test.sql`, `docs/M0-SETUP.md`, `docs/DEVLOG.md`.
- Test results: `flutter analyze`: no issues. `flutter test`: 24 passed, 1 skipped (the access-rule test, which needs `.env.test`).
- Next step: the founder puts the app on the Android phone (Part 5 of `docs/M0-SETUP.md`).

### 2026-11-11 M0: project setup and sync proof (code written, sync not yet proven)
- Done:
  - PC tools installed: Flutter 3.47.9 (`C:\src\flutter`), Visual Studio 2022 with "Desktop development with C++", Android Studio, Android SDK 36, NDK 28.2 and CMake 3.22.1. Windows Developer Mode is on. `flutter doctor` reports no issues.
  - The Android SDK and the Gradle cache live on `H:\Ai` (`H:\Ai\Android\Sdk`, `H:\Ai\gradle`) because drive C: ran out of space. The user setting `GRADLE_USER_HOME` points to `H:\Ai\gradle`.
  - Flutter project created for Windows and Android only (app id `com.orbito.orbito`).
  - Local database (Drift) with the test table `sync_test`, running on top of the PowerSync database.
  - Supabase email and password sign-in. Keys are read from `.env` (git-ignored). The template is `env.example`.
  - PowerSync sync for `sync_test`, with upload of local changes to Supabase.
  - Test screen: sign in or create account, list of rows, add box, sync status line, sign out.
  - SQL for Supabase (`supabase/001_sync_test.sql`, `supabase/002_powersync_role.sql`) and the PowerSync sync config (`powersync/sync-config.yaml`).
  - GitHub Actions workflow (`.github/workflows/build.yml`) for the Windows app and the Android APK.
  - Founder guide with setup and test steps: `docs/M0-SETUP.md`.
- Packages added: `drift`, `supabase_flutter`, `powersync`, `drift_sqlite_async`, `flutter_dotenv`, `flutter_riverpod`, `path_provider`; build tools `build_runner`, `drift_dev`.
- Left to do (all need the founder first, see `docs/M0-SETUP.md`):
  - Create the Supabase project and the PowerSync instance, run the SQL, deploy the sync config, fill in `.env`.
  - Run the M0 test on the PC and the phone (same account on both, row travels both ways, offline then reconnect, second account sees nothing).
  - Fill in `.env.test` and run the access-rule test against the real server.
  - On GitHub (private repo `neerhasan/Orbito`, already pushed): add the three public values as Actions variables and confirm the Actions run produces both builds.
- Known problems:
  - Sync between PowerSync and Supabase is NOT proven yet. No real keys exist, so sign-in and sync have never run. This is the main M0 risk and is still open.
  - The Windows app was only started with placeholder keys. It opened, but the screens were not checked by eye.
  - The APK was built but not installed on a phone.
  - The GitHub Actions workflow has never run.
  - Claude Code's safety settings block it from creating or reading files named `.env*`. The founder creates and fills those files. The template is therefore named `env.example`, not `.env.example`.
  - `android/gradle.properties`: Kotlin incremental compilation is off, because it fails on Windows when the project and the pub cache are on different drives. Build memory is lowered to 4 GB.
- Files changed: everything under `lib/`, `test/`, `supabase/`, `powersync/`, `.github/`; `pubspec.yaml`, `.gitignore`, `env.example`, `env.test.example`, `android/gradle.properties`, `android/app/src/main/AndroidManifest.xml`, `windows/runner/main.cpp`, `docs/M0-SETUP.md`.
- Test results: `flutter analyze`: no issues. `flutter test`: 24 passed, 1 skipped (the access-rule test, which needs real keys). `flutter build windows --debug`: built. `flutter build apk --debug`: built (170 MB debug APK).
- Next step: the founder does Part 1 of `docs/M0-SETUP.md` (Supabase).

## Template
### [date] Milestone or task
- Done:
- Left to do:
- Known problems:
- Files changed:
- Test results:
- Next step:
