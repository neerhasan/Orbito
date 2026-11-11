# Development log

Claude Code adds a new entry on top at the end of every session.

### 2026-11-11 M0: all five manual tests passed on the PC and the phone
- Done:
  - The app is installed on the founder's Android phone (iQOO Neo 9, Android 16) and runs with the real settings.
  - Test 1 passed: the same account (`test3@orbito.test`) is signed in on the PC and the phone, both show **Sync: Synced**.
  - Test 2 passed: a row added on the PC appears on the phone, and a row added on the phone appears on the PC.
  - Test 3 passed in both directions. Checked on the server: `added offline` (phone) was made at 05:50:16 UTC and arrived at 05:50:51; `pc offline` (PC) was made at 05:53:00 UTC and arrived at 05:53:31. Both arrived only after the network came back.
  - Test 4 passed by hand: a second account on the phone shows an empty list, and its new row does not appear on the PC.
  - Test 5 passed: after closing and restarting the PC app, the user is still signed in and the rows are still there.
- Left to do:
  - The automatic access-rule test: the founder fills in `.env.test` with two test accounts, then run `flutter test test/integration/rls_test.dart`.
  - GitHub: add the three public values as Actions variables.
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
