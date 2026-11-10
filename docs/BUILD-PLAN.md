# Orbito build plan (v1, Windows and Android)

Work through the milestones in order. Each milestone ends with a demo, and the founder tests it before the next one starts. Paste the prompt into Claude Code in the project folder.

## Before M0: what the founder does by hand
1. Install on the Windows PC (follow the official pages, because requirements change): Git, the Flutter SDK, Visual Studio with the "Desktop development with C++" part, Android Studio with the Android SDK, and Claude Code. Run `flutter doctor` and fix what it reports.
2. Create a private GitHub repo named `orbito-app` and copy this handoff folder into it.
3. Create a free Supabase project and a free PowerSync account. Keep the keys private. Never paste secret keys into chat or into Git.
4. Turn on developer mode and USB debugging on the Android phone.

## M0: project setup and sync proof
Purpose: remove the biggest risks first. Prove that sign-in and sync work between the Windows PC and the Android phone before building any real feature.

Prompt:
> Read CLAUDE.md and everything it points to. Task M0. Show me a short plan first and wait for my go-ahead. Then: (1) create the Flutter project for Windows and Android only; (2) add the Drift local database with one test table called `sync_test` (id, user_id, text, created_at, updated_at, deleted_at); (3) add Supabase email and password sign-in using keys from a git-ignored `.env` file, and provide `.env.example`; (4) add PowerSync so `sync_test` syncs with PostgreSQL; (5) write the exact SQL for me to paste into Supabase (table and row-level security so each user only sees their own rows) and the sync rules for PowerSync, and tell me step by step where to paste them; (6) build one test screen: sign in, a list of test rows, an add button, and a sync status line; (7) add a GitHub Actions workflow that builds the Windows app and the Android APK. Do not build any real product feature.

Done when:
- The same account signs in on the PC and on the phone.
- A row added on one device appears on the other.
- A row added while one device is offline appears after it reconnects.
- A second account cannot see the first account's rows (tested).
- `flutter analyze` and `flutter test` pass, and GitHub Actions produces a Windows build and an APK.

If sync between PowerSync and Supabase does not work, stop and report. We will change the plan before building more.

## M1: core data and tasks (F-05, F-01)
Prompt:
> Read CLAUDE.md. Task M1: life areas, goals, projects and tasks (the chain life area, goal, project, task). Tables, repositories, sync rules and row-level security for each new table, with a test that another user cannot see the data. Screens: first-run setup that suggests life areas; pages for areas, goals and projects; the Tasks page. The Tasks page needs: compact one-line rows showing project name on the right in the project's colour and the priority next to the title; a completion chart for the last 14 days with a toggle for week, 2 weeks, month and year; grouping, sorting and filtering (by project, goal, priority, status); a month view; and a colour picker when adding a project. Follow `docs/design/` and the prototype's Tasks view. Show me a plan first.

Done when: all of F-05 and F-01 acceptance criteria pass; data survives closing the app; changes sync between devices.

## M2: daily tracking (F-02, F-03, F-04)
Prompt:
> Read CLAUDE.md. Task M2: habits (one tap to mark done, 7-day progress, neutral wording on missed days, no streak pressure), focus timer (start, pause, stop and save time to the task, project and goal; recover time if the app closes during a session), and the sleep log (sleep and wake time, consistency summary). Same rules for tables, sync and security as M1.

Done when: F-02, F-03 and F-04 acceptance criteria pass.

## M3: home and capture (F-06, F-07)
Prompt:
> Read CLAUDE.md. Task M3: the customisable Today dashboard (the user switches sections on or off and orders them in Settings; the choice is kept and synced), and the Quick Launcher with the Inbox (one typed line becomes a task, habit log, sleep entry or note; show what will be created before confirming; lines that cannot be understood go to the Inbox and are never lost). Port the logic of `parseLine` from the prototype with unit tests using at least 15 sample lines. The Inbox does not show on the dashboard.

Done when: F-06 and F-07 acceptance criteria pass.

## M4: guidance (F-08, F-09, F-10)
Prompt:
> Read CLAUDE.md. Task M4: energy modes (low, medium, high, each with its own saved routine; one tap to switch; low mode shows only what matters now), the basic life score (area scores and an overall Life line, always showing the real position; use the placeholder formula in CLAUDE.md, kept in one place; say clearly when there is too little data), and the fail-day next step (after a missed day, one small suggested step and a summary of progress so far, encouraging and factual, never shaming).

Done when: F-08, F-09 and F-10 acceptance criteria pass. The founder reviews the wording of the fail-day messages.

## M5: accounts and hardening (F-14, F-11)
Prompt:
> Read CLAUDE.md. Task M5: finish accounts and sync. Sign up, sign in, sign out; sync status shown on screen (synced, syncing, offline, paused); account page with data export to a readable file and account deletion (this needs one small server-side function; explain it and tell me exactly how to deploy it); a short privacy note shown at sign-up; friendly error messages; verify that every table has row-level security with a passing test; verify that every first-release feature works with the internet off.

Done when: F-14 and F-11 acceptance criteria pass, and the founder can sign in on a fresh device and see all data.

## M6: closed test release
Prompt:
> Read CLAUDE.md. Task M6: prepare the closed test. Make GitHub Actions produce a Windows build and an Android APK on demand. Write a one-page install guide for friends in simple English, a short "known limits" note (free plan can pause after about a week of inactivity, no server backups, this is a test), and a simple way to collect feedback using `docs/TEST-NOTES-TEMPLATE.md`.

Done when: a friend can install on Windows or Android from the guide, create an account and use the app.

## After v1
The founder tests, fills in the test notes, and brings them to the planning chat. The documents and this plan are updated, and the next prompts are written.
