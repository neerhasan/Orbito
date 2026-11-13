# Orbito: instructions for Claude Code

Read this file first in every session. Then read the files it points to.

## What Orbito is
Orbito is a personal life operating system. One person plans their life (life areas, goals, projects, tasks) and tracks it (habits, sleep, focus time). The app shows their real position and what to do next, including after a failed day. The app is a general life app with ADHD-friendly design. It makes no medical claims.

## Current goal: v1 for a closed test
- Platforms: **Windows and Android only.** Do not add iOS or macOS code or folders. Keep the code platform-neutral so Apple versions can be added later.
- Audience: the founder and a few friends. Cost target: $0 (free plans).
- Scope: the first-release features only: F-01 to F-07, F-11 and F-14 in `docs/product/Feature-Specification.md`. Energy modes, life score and the fail-day step (F-08 to F-10) are held for v2 (see `docs/V2-FEATURES.md`). Everything else (V2, P1, P2) is out of scope. If asked for something out of scope, say so and ask.

## Approved stack (do not change without asking)
- Flutter (Dart), Windows and Android.
- Local database: SQLite through the Drift library.
- Server: Supabase (PostgreSQL, sign-in). Sync: PowerSync.
- No custom backend in v1. One small server-side function is allowed for account deletion.
- Distribution for the test: files shared directly. Build with GitHub Actions.

## Where the truth lives (in this order)
1. `docs/product/Feature-Specification.md`: what each feature does and its acceptance criteria.
2. `docs/product/PRD.md` and `docs/product/User-Flows.md`.
3. `docs/technical/System-Architecture.md` and `docs/technical/Technology-Stack.md`.
4. `docs/design/`: how screens should look (`source/` holds the design screens as HTML, `ember.css` holds the colours and styles, `screens-reference/` holds pictures).
5. `docs/reference/prototype/orbito-prototype.html`: a working web prototype that shows how features should behave. Reuse its logic (for example the Quick Launcher line parser, `parseLine`) but write clean Flutter code.
If these documents disagree with each other, or are silent on something important, **stop and ask the founder.** Do not guess.
The design files and the prototype still show the old name "Life System". The app is called **Orbito**. Use Orbito everywhere.

## How to work
- Do one milestone at a time from `docs/BUILD-PLAN.md`. Never build the whole app in one go.
- For any task that touches more than about three files, show a short plan first and wait for the founder's go-ahead.
- Before saying something is done: run `flutter analyze` and `flutter test`, run the app if you can, and report the real results. Never claim a feature works if you did not run it.
- Commit to Git after each working step, with a clear message. Never force-push. Never rewrite history.
- Do not add a new package without explaining why and asking.
- Keep changes small. Do not rewrite working code without saying what could break.
- Update `docs/DEVLOG.md` at the end of each session: what was done, what is left, known problems.

## Rules for the code
- **Local first:** screens read only from the local database, never straight from the network. Writes go to the local database first, then sync.
- Every table has: `id` (UUID made on the device), `user_id`, `created_at`, `updated_at`, `deleted_at` (soft delete).
- **Security:** never put secret keys in the app or in Git. Only the Supabase public (publishable) key may be in the app. Keep keys in `.env`, which is git-ignored, and provide `.env.example`. Every table must have a row-level security rule so a user can read and change only their own rows, and there must be a test that proves another user cannot see the data.
- Sync conflicts: the latest change wins, judged by server time, not the device clock.
- Sign-in: email and password. Email verification is off during the friends test.
- UI language: English only in v1. Use the device time zone.
- Life score (v2, not built in v1; placeholder, the founder will change it): area score = habits 40% + goals 40% + self-check 20%. Stages: Starting 0-39, Building 40-64, Established 65-84, Thriving 85+. Keep the formula in one place so it is easy to change.

## ADHD-friendly design rules
- Calm screens, not crowded. The user chooses which dashboard sections show.
- Common actions take one tap.
- No streak pressure and no shaming words. (v2: after a missed day, show one small next step and the progress made so far.)
- (v2, not built in v1) Low, medium and high energy modes each have their own routine. Low mode shows only what matters now.
- Orange (#FF5A1F) means "now". Do not use it for decoration.

## How to talk to the founder
The founder is not a programmer. Use simple English. Explain any technical term the first time. At the end of each milestone, say: what is done, how to run it, exactly what to test, and what is still broken. Say clearly which steps the founder must do by hand.
