# Development log

Claude Code adds a new entry on top at the end of every session.

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
