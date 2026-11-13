# Feature-Specification.md
Project: Orbito | Version: 0.3 | Date: 2026-11-11
Status: NEEDS REVIEW

Revision notes (2026-11-11): version 0.2 (approved) moved accounts, server and sync into the first release. Version 0.3: Revision note (2026-11-11): the founder decided the first release is for Windows and Android only. Apple versions (Mac, iPhone, iPad) come later, after all features are confirmed.

## 1. Feature inventory
| ID | Feature | Priority (P0/P1/P2) | MVP? | Depends on |
|---|---|---|---|---|
| F-01 | Tasks | P0 | Yes | F-05, F-11 |
| F-02 | Habits | P0 | Yes | F-05, F-11 |
| F-03 | Focus timer | P0 | Yes | F-01, F-11 |
| F-04 | Sleep log | P0 | Yes | F-11 |
| F-05 | Life areas, goals and projects | P0 | Yes | F-11 |
| F-06 | Customisable Today dashboard | P0 | Yes | F-01 to F-05 |
| F-07 | Quick Launcher and Inbox | P0 | Yes | F-01, F-02, F-04 |
| F-08 | Energy modes | V2 (moved from P0 on 2026-11-13) | No | F-01, F-02, F-06 |
| F-09 | Basic life score | V2 (moved from P0 on 2026-11-13) | No | F-02, F-05 |
| F-10 | Fail-day next step | V2 (moved from P0 on 2026-11-13) | No | F-02, F-09 |
| F-11 | Offline storage on the device | P0 | Yes | None |
| F-12 | Insights and 14-day tests | P1 | No | F-02, F-03, F-04 |
| F-13 | Notes | P1 | No | F-05 |
| F-14 | Accounts, server and sync across devices | P0 | Yes | F-11 |
| F-15 | Calendar sync | P1 | No | F-14 |
| F-16 | Trial and subscription billing | P1 | No | F-14 |
| F-17 | Free and premium split | P1 | No | F-16 |
| F-18 | Analytics and reports | P1 | No | F-12 |
| F-19 | Web version | P2 | No | F-14 |
| F-20 | Apple Watch | P2 | No | F-02, F-03 |
| F-21 | AI helpers | P2 | No | F-12 |
| F-22 | More integrations | P2 | No | F-14 |
| F-23 | Sharing | P2 | No | F-14 |
| F-24 | Post-beta additions | P2 | No | TBD |
| F-25 | Apple versions (Mac, iPhone, iPad) | P2 | No | F-01 to F-11, F-14 |
| F-26 | Widgets for Windows, Android and iOS | P2 | No | F-01, F-02, F-03, F-14 |

## 2. Feature details (repeat per feature)

### F-01 Tasks
- Description: create, edit, complete and organise tasks. Each task can belong to a project and goal, have a due date, a priority and a project colour. Views: list with grouping and sorting, and a month view. A chart shows tasks completed per day.
- User permissions: the single user can create, edit, complete and delete their own tasks.
- Inputs: title, optional project, goal, due date, priority.
- Outputs: task list, month view, completion chart.
- Expected behavior: tasks show on one compact line with project name and priority. The user can filter and sort. Completing a task updates the chart and the related goal.
- Error states: empty title is refused with a clear message; a failed save keeps the text the user typed.
- Empty states: a friendly prompt to add a first task.
- Acceptance criteria: a task can be created, edited, completed and deleted; filter, sort and month view work; the chart counts completed tasks by day; data remains after closing the app.

### F-02 Habits
- Description: define habits, mark them done each day and see progress.
- User permissions: the single user manages their own habits.
- Inputs: habit name, target days, optional time.
- Outputs: daily checklist and progress per habit.
- Expected behavior: one tap marks a habit done. Missed days show the next step, not blame. No streak pressure.
- Error states: a failed save keeps the mark and retries.
- Empty states: prompt to add a first habit.
- Acceptance criteria: a habit can be added, ticked and un-ticked for a day; progress shows over the last 7 days; wording on missed days is neutral.

### F-03 Focus timer
- Description: start a focus session on a task and record the time.
- User permissions: single user.
- Inputs: task, optional length.
- Outputs: running timer and saved session.
- Expected behavior: the session is saved to the task, project and goal. The timer keeps running if the user switches screens.
- Error states: if the app closes during a session, the elapsed time is recovered on next open.
- Empty states: no sessions yet shows a prompt to start one.
- Acceptance criteria: start, pause, stop and save work; saved time appears on the task and project.

### F-04 Sleep log
- Description: record sleep time and wake time and see consistency.
- User permissions: single user.
- Inputs: sleep time, wake time, optional note.
- Outputs: nightly record and consistency summary.
- Expected behavior: logging takes one short entry. Past entries can be corrected.
- Error states: a wake time before sleep time asks the user to check.
- Empty states: prompt to log the first night.
- Acceptance criteria: a night can be added, edited and deleted; the summary updates.

### F-05 Life areas, goals and projects
- Description: the chain Life Area, Goal, Project, Task. Each level can be created and linked.
- User permissions: single user.
- Inputs: names, links between levels, optional target date.
- Outputs: pages for each level with linked items and progress.
- Expected behavior: a new project links to a goal, and a goal to a life area. A soft limit on active life areas (proposed 3 to 8) is TBD - pending founder decision.
- Error states: deleting an item that has linked items asks what to do with them.
- Empty states: a first-run setup suggests common life areas the user can accept or change.
- Acceptance criteria: the full chain can be built and navigated; deleting or moving an item never leaves orphaned tasks without a warning.

### F-06 Customisable Today dashboard
- Description: a home screen with the user's chosen sections, for example schedule, habits, tasks, reminders and sleep. (The life line section arrives with F-09 in v2.)
- User permissions: single user.
- Inputs: a settings list where each section is switched on or off and ordered.
- Outputs: the Today screen.
- Expected behavior: only chosen sections show. Changes apply at once. The inbox does not show on the dashboard.
- Error states: if no section is chosen, the screen offers to restore the defaults.
- Empty states: new users see a small default set.
- Acceptance criteria: each section can be toggled and the choice is kept after restart.

### F-07 Quick Launcher and Inbox
- Description: one typed line becomes a task, a habit log, a sleep entry or a note. Items that cannot be sorted go to the Inbox page.
- User permissions: single user.
- Inputs: one line of text.
- Outputs: a created item and a confirmation showing what was created.
- Expected behavior: the user sees what will be created before confirming. Unclear lines go to the Inbox.
- Error states: an unreadable line is saved to the Inbox, not lost.
- Empty states: the Inbox shows "nothing waiting".
- Acceptance criteria: a set of sample lines creates the expected items; no typed line is lost.

### F-08 Energy modes
- Description: low, medium and high energy modes, each with its own routine (three separate routines).
- User permissions: single user.
- Inputs: the user picks a mode; the user sets the routine for each mode.
- Outputs: a Today view showing only the chosen mode's routine and tasks.
- Expected behavior: low mode shows only what matters now. Switching mode is one tap.
- Error states: a mode with no routine suggests creating one.
- Empty states: starter routines the user can edit.
- Acceptance criteria: three routines can be saved separately; switching changes the Today view.

### F-09 Basic life score
- Description: a score per life area and an overall Life line that always shows the user's real position.
- User permissions: single user.
- Inputs: habits, goals and optional self-check.
- Outputs: area scores, the Life line and its history.
- Expected behavior: the real score is always visible. The formula and stage names are TBD - pending founder decision. A proposal exists: habits 40%, goals 40%, self-check 20%.
- Error states: with too little data the app says so instead of showing a number.
- Empty states: explains what data is needed.
- Acceptance criteria: the score is calculated from the agreed formula; the user can see how it was calculated.

### F-10 Fail-day next step
- Description: after a missed day, the app shows the next small step and the progress made so far.
- User permissions: single user.
- Inputs: missed habits and tasks.
- Outputs: one suggested step and a progress summary.
- Expected behavior: wording is encouraging and factual. It never shames. Guided by the ideas of improving one percent each day and identity-based habits; these are not presented as proven science.
- Error states: none expected; with no history the message is skipped.
- Empty states: not shown to new users.
- Acceptance criteria: after a missed day, the user sees one next step and a progress summary; whether this helps or discourages ADHD users is tested in beta.

### F-11 Offline storage on the device
- Description: all P0 data is stored on the device and works without internet.
- User permissions: single user.
- Inputs: all user data.
- Outputs: data available at any time.
- Expected behavior: nothing is lost if the app closes. The user can export their data.
- Error states: if storage is full, the user is told clearly and nothing is deleted.
- Empty states: not applicable.
- Acceptance criteria: with the internet off, every P0 feature works; data remains after restart; export produces a readable file.

### F-14 Accounts, server and sync across devices
- Description: the user creates an account and signs in. Data is stored on the device first and synced through a server, so the same data appears on every device the user signs in on.
- User permissions: each user can read and change only their own data. The user can sign out, export their data and delete their account.
- Inputs: sign-up and sign-in details (method TBD - pending Phase 03 and Phase 04), and all user data created in the app.
- Outputs: the same data on every signed-in device, and a visible sync status.
- Expected behavior: the device works offline first. Changes made offline are queued and sync when the connection returns. When the same item was changed on two devices, the proposed rule is that the latest change wins, using server time (to be confirmed in Phase 04). Deleting the account removes the user's data from the server.
- Error states: wrong sign-in details give a clear message; no connection shows "will sync when online" and loses nothing; a failed sync retries and tells the user if it keeps failing.
- Empty states: a new account starts empty with the first-run setup; signing in on a second device downloads the existing data with a progress message.
- Acceptance criteria: an account can be created and signed in on two devices; a change on one device appears on the other; an edit made offline syncs after reconnecting; no user can see another user's data; deleting an account removes the server data; data export produces a readable file.

### F-12 to F-24 (P1 and P2, except F-14 above)
Short descriptions only. Full details: TBD - pending later iteration; each feature returns to Phase 02 for full specification before it is built.
- F-12 Insights and 14-day tests: patterns found in the user's own data, labelled Fact, Correlation, Hypothesis or Recommendation, with a 14-day test to check a hypothesis. A proposed rule is at least 14 days of data and at least 7 cases on each side.
- F-13 Notes: written notes linked to areas, goals and projects.
- F-15 Calendar sync: calendars to sync are TBD - pending founder decision.
- F-16 Trial and subscription billing: one-month trial with all premium features, then premium features turn off.
- F-17 Free and premium split: decided by the founder after testing all features.
- F-18 Analytics and reports: charts of time and progress.
- F-19 Web version. F-20 Apple Watch. F-21 AI helpers. F-22 More integrations. F-23 Sharing.
- F-25 Apple versions (Mac, iPhone, iPad): built after all features are confirmed. Needs a Mac and a $99 per year developer membership. The first release (F-01 to F-11 and F-14) targets Windows and Android only.
- F-24 Post-beta additions: a place for any feature the founder adds after the beta launch.
- F-26 Widgets for Windows, Android and iOS (added 2026-11-13): small widgets outside the app showing chosen information such as today's tasks or habits. What they show and the exact design are TBD - pending founder decision. iOS widgets need the Apple release (F-25). v1 keeps the data and rules separate from the screens so widgets can be added later.

## 3. MVP scope (P0 list)
F-01 to F-07, F-11 and F-14. (F-08, F-09 and F-10 moved to v2 on 2026-11-13; see `docs/V2-FEATURES.md`. In v1 the Today dashboard has no energy-mode switcher and no Life line section.)

## 4. Future features (V2, P1, P2)
V2 (second build, held by the founder): F-08, F-09 and F-10. P1: F-12, F-13 and F-15 to F-18. P2: F-19 to F-26. New ideas are added here as new IDs and go through Phase 02 before they are built.

## 5. Feature dependency map
Everything depends on F-11 (storage), and all user data syncs through F-14. Tasks, habits and focus depend on F-05 (life areas, goals, projects). The dashboard, Quick Launcher, energy modes, score and fail-day step depend on the core features. Insights depend on habits, focus and sleep data. Billing and calendar sync depend on accounts (F-14).
