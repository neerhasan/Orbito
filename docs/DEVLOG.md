# Development log

Claude Code adds a new entry on top at the end of every session.

### 2026-11-24 Today: new layout, week strip, sleep line chart
- Done (founder's plan): main panel: Greeting, Habits, Calendar, Tasks, Projects, Goals, Sleep; right panel: Time today, Schedule (new defaults in `TodaySection`; a saved choice keeps its order, so the founder may move the Calendar up with the arrows in Settings). Sleep and Goals sit side by side so the Sleep card keeps its size. The month calendar is now a one-row week strip (Sunday to Saturday, today orange, dots on days with tasks); a click on a day shows that day in Tasks and Schedule. The Schedule's hour circles are gone; its tag shows the day ("Today · Tue 24 Nov"). Focused time in "Time today" is orange (founder's choice; CLAUDE.md rule updated). Sleep: a line chart of the hours slept over the last 15 nights with the 15-night average (thin line and number); last night's dot is orange; gaps where a night is not logged. Task blocks in the narrow Schedule shorten their times instead of overflowing.
- Left for later (founder): back and forward buttons (the week strip shows only the picked day's week for now).
- Files changed: `lib/domain/today.dart`, `lib/features/today/today_page.dart`, `lib/features/today/today_schedule.dart`, `test/today_test.dart`, `test/notes_and_day_test.dart`, `CLAUDE.md`.
- Test results: `flutter analyze`: no issues. `flutter test --concurrency=1`: 232 passed. The Today page was checked as a picture rendered off-screen (light mode).

### 2026-11-24 Focus: mini window above other apps
- Done: focus mode has a "Mini window" button. It shrinks the Orbito window into a small 320 x 76 window in the bottom-right corner of the screen that stays above every other app (window_manager, no new package). It shows the task, the clock as hours:minutes:seconds (a countdown shows the time left, a stopwatch the time worked; "Paused" or "Time is up" next to it), a pause/resume button and an expand button that puts the window back where it was (maximised again if it was). Drag it anywhere; a double click does nothing. If the timer ends, the full window comes back by itself.
- Founder's choice: for now the mini window is the app window itself, so the full app is hidden while it is open. Later it becomes a separate window.
- Files changed: `lib/ui/window_frame.dart`, `lib/features/focus/focus_page.dart`, `lib/app/shell.dart`, `lib/domain/focus.dart`, `test/daily_pages_test.dart`, `test/daily_rules_test.dart`.
- Known problems: the tests cannot see the real window (no window in tests); the resize, always-on-top and restore were not checked on screen yet.

### 2026-11-23 Calendar: task list by date; project colours
- Done: the left task list is grouped by date: Overdue, Today, Tomorrow, This week, Next week, Later, No date (weeks start on Sunday, like the calendar). Tasks on the calendar (time blocks, All day chips, month view) show their project's colour with a bar on the left; tasks without a project stay white. A focus block's bar takes its task's project colour.
- Files changed: `lib/features/calendar/calendar_page.dart`, `test/calendar_test.dart`.
- Test results: `flutter analyze`: no issues. `flutter test --concurrency=1`: 230 passed.

### 2026-11-23 Today: Schedule; day bar to 100% at bedtime; motion; alignment
- Schedule (design `Main.dc.html`): a new Today section (it switches itself on for users who chose sections before it existed; switched off it is stored as `-schedule`). Hour chips jump to an hour; the timeline runs from wake time to bedtime (wider when something lies outside), 60 px per hour, with the orange "now" line and time. It shows the Calendar's events, tasks with a time and length, and habits with a usual time (30 minutes, their ring marks the day done). A task whose focus timer runs is orange-tinted with pause, bar and time. Tasks are dragged from the Tasks list on the right onto a time; a scheduled task can be dragged to another time and made longer or shorter by its bottom edge; a click opens its options (done, start focus, change the time, length 15m to 3h, remove the time, open in Tasks). It follows the day picked in the small calendar.
- Day bar (founder): wake time to bedtime is 100%; after bedtime it goes on (110%, 120%). The bar itself still covers 24 hours. Settings text updated.
- Motion (ux-motion review): timings 140/240/400 ms (were 180/340/620); leaving uses ease-in and half the time; hover feedback uses the fast timing; the Quick Launcher opens in 110 ms; jumps on the schedule use ease-in-out.
- Alignment (pages rendered and checked): Schedule hour labels shortened to fit; Life areas suggestion chips no longer leave large gaps; the project deadline is a date button like the goal's.
- Test results: flutter analyze: no issues. flutter test --concurrency=1: 230 passed (new: Schedule page test; the Schedule section rules; day bar percent past bedtime).

### 2026-11-23 Tasks: new add box; tags; the timer on the left
- Done: the Tasks page's add box follows the founder's reference: closed it is "+ Add Task"; a click opens "What would you like to do?" with Date (Today by default; Today, Tomorrow, Next Monday, pick a date, add a time, no date), Priority (flag: High, Medium, none), Tag (earlier tags or a new one), Project and More (a note, a time, clear the options), and Add. Enter adds, Esc closes; date, project and priority stay for the next task. `supabase/015_task_tags.sql` (applied): tasks get `tags` (comma separated, lower case); up to two show on a task row as #tag. The running focus timer in the top bar moved to the left, before the search box.
- Test results: flutter analyze: no issues. flutter test --concurrency=1: 228 passed. Windows release built; the add box checked open and closed on screenshots.

### 2026-11-23 Calendar like Notion Calendar; dark mode
- Dark mode (founder: like the Sleep log app; kept per device): `lib/ui/ember.dart` now has a light and a dark `Palette` (dark values from the Sleep log app: #1e1e20 paper, #262628 tile, #333336 line, #f5f5f4 ink and so on); the paper colours, text styles and project/area/goal swatches follow it; the dark shell stays dark. New `surface` (raised white, dark grey in dark) and `onInk` (text on an ink fill). Status tints (good, warn, bad, blue, violet) have dark values. `lib/app/theme_mode.dart` keeps the choice in `theme.txt` next to the app's data and loads it at start. A moon/sun button in the top bar and a "Dark mode" switch in Settings switch it; the whole app is rebuilt with the new colours. Many `const` keywords were removed (mechanical) because the colours are no longer fixed values.
- Calendar: on the left a small month (click a day to jump to it) and every open task, grouped No date, Overdue, Today, Later. Drag a task onto a time (it gets that date and time), onto the All day row (date only), or back onto the list (no date, no time). Task blocks show from-to times and change by their top and bottom edges in 15-minute steps; moved blocks keep their length. `supabase/014_task_duration.sql` (applied): tasks get `duration_minutes` (empty means 30). The event panel on the right opens only for a new or a clicked event (the day summary is gone).
- Also: the notes page saves a title typed just before leaving the page (its repository is read when the page opens). CI runs the tests on Windows (window_manager's native helper does not build on the Linux runner).
- Known problems: the Android build fails on GitHub Actions (since 20 Nov; the error text needs a signed-in view of the run) and cannot run on this PC (no Gradle wrapper; Gradle runs out of memory).
- Test results: flutter analyze: no issues. flutter test --concurrency=2: 226 passed (new: dark mode switch, a title saved on leaving a page, the Calendar task list drag, task block resize). The PC screen was locked, so the pages were checked as pictures rendered off-screen in dark and light (Today, Tasks, Calendar, Notes, Habits, Sleep, Focus, Settings); three colour bugs found that way were fixed (dark buttons, the New button, outlined buttons).

### 2026-11-23 Notes rebuilt like Notion
- Done: new package `appflowy_editor` (founder approved; MPL-2.0, used unmodified), pinned to GitHub commit 01eccc6 because the 6.2.0 release does not compile with Flutter 3.47. `supabase/013_notes_pages.sql` (applied on the server): notes get `content` (blocks as JSON), `parent_id`, `icon`, `cover`, `favorite`, `trashed_at`, `sort_order`. `lib/domain/note_tree.dart`: the page tree rules. The Notes page is now Notion-style: on the left, search, Favorites, the page tree (▸ to open, + to add a page inside, ••• for favourite, Move to and Trash, drag a page onto another to put it inside), New page and Trash (restore, or delete for good with the pages inside). On the right: breadcrumbs, when it was edited, add a page inside, favourite, •••; the cover, emoji icon, big title and the block editor: Text, Heading 1-3, To-do, Bulleted and Numbered list, Toggle, Quote, Divider, Callout, Code; "/" opens the block menu; markdown shortcuts (# , - , [] , " , ---); + and ⋮⋮ on hover (drag to move a block, or Delete, Duplicate, Move up/down, Turn into). Pages save by themselves 0.9 s after typing stops and when the page closes. A page can still be linked to a project. Old notes open with their text as paragraphs and are saved as blocks the first time they change.
- Checked: the notes and events sync streams are deployed (both are on the PC's database), so the old manual step is done.
- Not built: Notion databases (tables, boards), comments, sharing, page links inside text, images and file uploads, templates, page history.
- Known problems: the Android build could not be checked on this PC (the Gradle daemon crashed: a machine problem); GitHub Actions builds it.
- Test results: flutter analyze: no issues. flutter test --concurrency=2: 222 passed (new: `test/note_pages_test.dart` 6, `test/editor_probe_test.dart` 3, 2 Notes page tests replacing the old form tests). Windows release built and started with real data: the page tree, the converted note, the block handles and the title-area buttons checked on screenshots. The "/" menu, dragging and the Trash were checked by tests only (no test page was made in the founder's notes).

### 2026-11-22 Focus page and Focus report (after the founder's inspiration images)
- Done: the Focus page is now a timer page in Orbito's style: Countdown (25, 45, 60, 90 minutes) or Stopwatch; the picked task above a big ring with clock ticks; "Start to focus"; on the right, focus time today, the open tasks (done ring, project, one dot per session today, a start button; clicking a row picks it) and today's records (a 24-hour strip and one coloured row per session). In focus mode: Full screen (Esc leaves full screen first), the countdown shows the time left, and at 00:00 "Save and take a 5-minute break"; the break counts down on the Focus page and can be skipped. The title bar timer shows the time left of a countdown.
- Focus report (the "Report" button): six numbers (total, this week, today; tasks done in total, this week, today); the records grid (rows Today, Yesterday, 20 Nov …, 0:00 to 24:00, 14 or 60 days); Daily, Weekly, Monthly or Yearly with arrows for: focus time by project or by task, project share (donut with names, %, time), focus by day (stacked bars with a legend); the focus goal ("Goal: 4h", change it from the button) with focus days, goal days, goal rate and a month calendar with a green ring on goal days.
- Data: `supabase/012_focus_goal.sql` (applied on the server): `preferences.focus_goal_minutes`. Synced like the other settings; no sync config change. A countdown now saves at most its planned length (a timer left running, or the app closed, no longer adds hours that were not worked).
- Not built: white noise (founder: skip for now; it needs a sound package), estimated sessions per task, long breaks.
- Test results: flutter analyze: no issues. flutter test --concurrency=2: 213 passed (7 new in `test/focus_report_test.dart`, 1 repository, 1 goal setting, 2 Focus page; the first Focus test now expects the countdown). Windows release built and started with real data: the Focus page and the whole report (numbers, records grid, focus time, project share, focus by day, goal calendar) checked on screenshots at 1280 x 720. Focus mode now has the window buttons and moves the window by its top row (it had none, as the system title bar is hidden). Not checked on screen: full screen, the break, changing the goal (the founder tests these).

### 2026-11-20 Side menu collapses to icons
- Done: a collapse button («) at the right of "Orbito" in the top bar. Collapsed, the side menu slides to a 60 px rail: every page, life area, Settings and "+" for life areas is an icon button with its name as a tooltip; the sync status is a coloured dot (words in the tooltip); the top bar shows only the orange logo, and clicking the logo opens the menu again. The choice is kept while the app runs (it opens again on the next start).
- Test results: flutter analyze: no issues. flutter test --concurrency=2: 202 passed (1 new). Windows release built and started: the collapse button seen on a screenshot; the collapsed rail checked by tests only (the founder was using the screen).

### 2026-11-20 Sleep: Month first, Sleep log entry dialog
- Done: the Sleep page opens on Month. The form on the right is gone; "Log sleep" (top right) or clicking a night opens the Sleep log app's entry dialog: Date you woke up, Bedtime and Wake time as hour, quarter hour and AM or PM, "7h of sleep, 1h short", Delete, Cancel, Save. A date with a night opens it as "Edit night". Its checks: a future date, the same bed and wake time, and more than 16 hours are refused with a message. Delete needs no confirm, as in the Sleep log app.
- Founder's choice: no "How rested" and no note. The 7 saved nights' rested and note values were cleared on the server (one SQL update, the founder's own rows). The columns stay in the database, unused.
- Test results: flutter analyze: no issues. flutter test --concurrency=2: 201 passed (Sleep page tests rewritten). Windows release built and started: Month view and the Edit night dialog checked on screenshots.

### 2026-11-20 Sleep page rebuilt after the founder's Sleep log app
- Done: `lib/domain/sleep_view.dart` (week Monday to Sunday, month and year ranges; period names; goal; how far a night was from it; averages, consistency, changes against earlier periods). The Sleep page now follows `F:\Neeret\sleep-tracker`: Week, Month and Year with Today and arrows; four cards (dark Average sleep card with its change and a small line, Average bedtime and Average wake-up with their targets and last week, month and year, Nights at goal); the Tracking list (one row per morning, newest first, a bar from bedtime to wake time on a 3 PM to 3 PM line, green, yellow, red or deep red by distance from the goal, dashed target lines); for a year, average sleep by month and every night as a square. Clicking a night opens it in the form on the right (a day with no night starts a new one for that day). The form keeps "how rested" and the note, starts at the target times and says how far from the goal the night is. The old chart and the Recent nights list are gone.
- Founder's choice: the targets are the bedtime and wake-up time in Settings, and the goal is the time between them. No server change.
- Not in this step: the five detail pages of the Sleep log app; its export, import and sample data.
- Fix in the same session: the form opens the night of a morning that already has one (today included), as the Sleep log app does, so Save cannot overwrite a night without showing it; picking another date in the form loads that morning's night.
- Test results: flutter analyze: no issues. flutter test --concurrency=2: 201 passed (9 new in `test/sleep_view_test.dart`, Sleep page tests rewritten, 1 new for the fix). Windows release built and started with real data: the Week view (normal and maximised) and the top of the Year view were checked on screenshots. Month view, the year heat map and the Habits log grid were checked by tests only.

### 2026-11-20 Habits: one-click log for the last 7 days
- Done: the Habits page's "Today's checklist" is replaced by a log grid (founder's layout): rows are Today, Yesterday, the weekdays of this week and "Last Sunday" style names for last week; one column per habit. One click on a box logs the habit done on that day (also a forgotten earlier day); a second click clears it. Right-click or a long press skips the day; again un-skips. Clicking a habit's name opens it in the form. Many habits scroll sideways. Today's box has an orange edge while it is open.
- Test results: flutter analyze: no issues. flutter test --concurrency=2: 191 passed (2 new).

### 2026-11-20 One seamless top bar and the orange app icon (Windows)
- Done: new package `window_manager` 0.6.0 (founder approved). The blue Windows title bar is hidden; Orbito's dark top bar now moves the window (drag), maximises it (double click) and holds its own minimise, maximise and close buttons (close turns red on hover). Sign-in and set-up screens get a thin dark strip with the same buttons. `windows/runner/resources/app_icon.ico` is the orange Orbito logo (16 to 256 px).
- Known problems: Windows may keep showing the old icon on a pinned taskbar shortcut until Orbito is unpinned and pinned again.
- Test results: flutter analyze: no issues. flutter test --concurrency=2: 189 passed. Windows release built, started, and the single dark bar checked on a screenshot.

### 2026-11-19 Calendar drag and drop
- Done: `supabase/011_task_time.sql` (applied): tasks get `due_time` (HH:MM). Calendar: drag events to another time or day (snaps to 15 minutes, keeps the length, a dark box shows where it lands); drag the top or bottom edge of an event to change start or end; drag a task from the All day row onto the grid to give it a time, back to All day to remove it. Tasks with a time show as white blocks (design: "Task with a time"). The Tasks page shows the time after the date. The Quick Launcher now saves a typed time as the task's time, not in its notes.
- Test results: flutter analyze: no issues. flutter test --concurrency=2: 189 passed. Windows release built.

### 2026-11-19 Calendar page
- Done: `supabase/010_events.sql` (applied): `events` table with row-level security; sync config has a new `events` stream (the founder deploys it). `lib/domain/calendar.dart` (views, stepping, headings, side-by-side layout of overlapping blocks, focus blocks). Calendar page after `Calendar.dc.html`: Month, Week, 4, 3 and 2 day views; events (add, change, delete; click an empty slot to start one); tasks due and project deadlines in an All day row; past focus sessions as blocks; the picked day listed on the right. Notes stay on the Notes page only; Add habit removed from Today; rows under a date heading no longer repeat the date.
- Not in this step: Google Calendar (F-15), reminders, habit blocks, tasks with a time.
- Known problems: notes vanished after saving because the sync config with `notes` was not deployed yet; the founder deploys it.
- Test results: flutter analyze: no issues. flutter test --concurrency=2: 187 passed (12 new in `test/calendar_test.dart`). Windows release built.

### 2026-11-19 Founder feedback, round 2: Today tasks by day, inline add, compact rows, Tasks menu
- Done: clicking a calendar date switches the Today Tasks section to that day (Back to today returns; the picked date has a ring). "Add one" turns into an input in place and adds the task to the shown day. Task rows on the Tasks and project pages are one line: ring and title left; date, priority, project (and focus time) right; rows never wrap: on a narrow panel the project tag, then the priority tag, are left out. The Tasks page view switch, Show completed and Filters moved into a three-dot menu at the top right (New task is not in it; the add box sits under the chart).
- Test results: flutter analyze: no issues. flutter test --concurrency=2: 174 passed. Windows release built.

### 2026-11-19 Founder feedback after testing M3: Notes, deadlines, day bar
- Done:
  - Server: `supabase/009_notes_deadline_daytimes.sql` (applied): new `notes` table with row-level security, `projects.deadline`, and `preferences.wake_time` and `preferences.bed_time`. Sync config: one new stream, `notes` (the founder deploys it).
  - Notes: a separate Notes page in the side menu. A note has a title, text and an optional project. Notes are not shown inside a project (founder, after testing). Deleting a project keeps its notes and removes the link.
  - Projects: an optional deadline (set, change or clear any time) on the project form, the list and the open project. Today shows it too. The add-task box on an open project is now at the top, and the open project has no large gaps between its title, add box and list.
  - Tasks: one "Show completed / Hide completed" switch replaces "Done today". The completed-tasks chart is always shown under the page title (no hide button). The header buttons wrap instead of overflowing.
  - Scrolling: the mouse wheel now glides instead of jumping. The panel clip is cheaper to draw.
  - Today: calendar dates are clickable and show the tasks due that day. A project opens that project. The day bar is "Day progress": it starts at the wake time and runs 24 hours, with a red dot at bedtime and it keeps running past bedtime.
  - Settings: "Your day" with wake up time and bedtime (synced).
  - New menu: only Task and Note.
- Left to do: the founder deploys the sync config and runs `docs/M3-FEEDBACK-TEST.md`. Existing Inbox items of kind "note" stay in the Inbox (not moved to Notes). Quick Launcher "note ..." lines still go to the Inbox.
- Known problems: none known. The "add a task at the top" request: on the Tasks page the box was already above the list; on an open project it was at the bottom and is now moved up.
- Test results: `flutter analyze`: no issues. `flutter test --concurrency=2`: all passed (13 new tests in `test/notes_and_day_test.dart`). Privacy test now lists `notes` (needs the real server to run).

### 2026-11-13 M3: Today, the Quick Launcher and the Inbox (Windows)
- Done:
  - Server: `supabase/008_inbox_preferences.sql` (inbox_items, preferences) with row-level security; applied. Privacy test covers all 11 tables (passed). Sync config: two new streams (the founder deploys).
  - `lib/domain/launcher.dart`: port of the prototype parseLine (21 tests). `lib/domain/today.dart`: the Today sections and their stored order (5 tests).
  - Quick Launcher (Ctrl K or the search box) with a preview before confirming; Inbox page (make a task, remove); Settings page (Today sections on/off and order, synced); Today page after the design; Today and Inbox in the menu, Settings at the bottom; Today is the start page.
- Left to do: the founder deploys the sync config and runs `docs/M3-TEST.md`.
- Known problems: none new.
- Test results: `flutter analyze`: no issues. `flutter test --concurrency=2`: 160 passed. Windows release built and started; a screenshot of Today matched the design layout.

### 2026-11-13 Redesign after "Tasks · list + detail"
- Done:
  - The founder's new design files are in `docs/design/source/` (Tasks, Sidebar, Titlebar, Icon).
  - App frame (`lib/app/shell.dart`): title bar with logo, search (shows a note until M3), the running focus timer, a New menu and the account button (email, Sign out); side menu with Plan, Daily and Life areas, counts, an orange icon on the open page; sync status at the bottom.
  - Tasks page (`lib/features/tasks/tasks_page.dart`): header with open, overdue and on-time numbers; List and Calendar; Filters button that folds out grouping, sorting and filters; the add box; tasks as two-line tiles grouped by date; "Done today" and "Completed" (the chart) fold-outs; a wide detail panel with focus, project, goal, life area, due, priority, time, focus sessions, notes, Reschedule, Postpone to tomorrow and Delete.
  - The Projects page uses the same tiles and panel.
  - New shared parts: `SoftButton`, `Kbd`, a wider rail option, a larger task ring. New rules in `lib/domain/task_view.dart`: overdue count, on-time share this month, done today.
- Test results: `flutter analyze`: no issues. `flutter test --concurrency=2`: 128 passed. Windows release built and started; a screenshot matched the design layout.
- Next step: the founder looks at the new design, then the M2 test.

### 2026-11-13 Soft motion and M2 (habits, sleep, focus timer), Windows
- Done:
  - Motion: `lib/ui/motion.dart` holds one soft curve and the timings. Pages and the right panel cross-fade, tiles fade in and give when pressed, rings fill, bars and charts rise, panels resize smoothly. No motion when Windows has animation effects off.
  - Server: `supabase/007_daily_tables.sql` (habits, habit_logs, focus_sessions, sleep_logs) with row-level security; applied through the connector. The privacy test (`test/integration/rls_test.dart`) now covers all nine tables and passed against the real project.
  - Sync config: four new streams in `powersync/sync-config.yaml`. The founder still has to deploy it (see `docs/M2-TEST.md`, "Before you start").
  - Local: Drift tables, PowerSync schema, and a device-only `focus_timer` table so a running timer survives closing the app.
  - Rules in `lib/domain/habits.dart`, `sleep.dart`, `focus.dart`; repositories in `lib/data/repositories/`.
  - Pages after the designs: Habits, Sleep, Focus (with full-window focus mode and a timer pill in the side menu). Tasks show focus time and a "Start focus" button; projects and goals show focus time.
  - Ids made from text (UUID version 5, `stableId` in `providers.dart`) for one habit mark per day and one night per morning, so two devices write the same row.
- Left to do: the founder deploys the sync config and runs `docs/M2-TEST.md`.
- Known problems:
  - `flutter test` ran out of memory on this PC when all test files ran at once (4 GB free). Run `flutter test --concurrency=2`.
  - Until the new sync config is deployed, M2 rows can vanish from the app after upload (the same cause as the duplicate areas in M1).
  - The Supabase security check still warns that leaked-password protection is off (an M5 item).
- Test results: `flutter analyze`: no issues. `flutter test --concurrency=2`: 128 passed (the 9 privacy tests ran against the real project). `flutter build windows --release --no-tree-shake-icons`: built; the app was restarted.
- Next step: the founder's M2 test.

### 2026-11-13 M1 fixes after the founder's second test
- Done:
  - Only one project icon showed in the Windows app. Cause: the local release build reused an old, cut-down copy of the icon font (2.6 KB) made before the icons were added. Fix: build with `flutter build windows --release --no-tree-shake-icons`, which keeps the whole icon font (1.6 MB). Use this flag for every Windows build until icons stop changing.
  - Clicking a project opens a project page (`lib/features/projects/projects_page.dart`): icon, name, the goal as a chip, progress, all its tasks (open first) with the first line of each task's notes, and a box to add tasks. On the right: the selected task, or the project form.
  - Every task has a Notes box (`tasks.notes`). `TaskRow`, `TaskForm` and `PriorityTag` in `tasks_page.dart` are now public so the project page reuses them.
  - Goals have a colour (`goals.color`, `GoalColors`) and an icon (`goals.icon`); life areas have an optional icon (`life_areas.icon`, shown by `AreaMark` in the list and the side menu). `ProjectIcons` is now `ItemIcons` with 17 icons (`flag` added).
  - Server: `supabase/006_icons_colours_notes.sql`, applied through the Supabase connector. The sync config uses `SELECT *`, so no change there.
- Left to do: the founder runs the quick retest at the top of `docs/M1-TEST.md`.
- Known problems: none new. Older notes below still apply.
- Test results: `flutter analyze`: no issues. `flutter test`: 90 passed. `flutter build windows --release --no-tree-shake-icons`: built; the app was restarted.
- Next step: the founder's retest, then the M2 plan ("go").

### 2026-11-13 Scope change: M4 moved to v2
- Done: the founder moved energy modes (F-08), the basic life score (F-09) and the fail-day next step (F-10) to v2, the second build. Documents updated: new `docs/V2-FEATURES.md` (the list of held features), `docs/BUILD-PLAN.md` (M4 marked as moved), `docs/DECISIONS.md`, `docs/product/Feature-Specification.md`, `docs/product/PRD.md`, `docs/technical/System-Architecture.md`, `docs/status/Project-Status.md`, `CLAUDE.md`.
- v1 is now: M1 (done, waiting for the founder's approval), M2 daily tracking, M3 home and capture, M5 accounts and hardening, M6 closed test. M5 and M6 keep their names.
- No code changed. The `Today` dashboard in M3 will have no energy-mode switcher and no Life line section.
- Next step: the founder approves M1, then the plan for M2.

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
