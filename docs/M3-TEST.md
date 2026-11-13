# M3 test guide: Today, the Quick Launcher and the Inbox (Windows)

This guide is for the founder. It takes about 15 minutes. If a step does not do what the guide says, tell Claude the test number, the step number and what you saw.

## Before you start (once)

1. Open PowerSync in the browser, the Orbito instance, the sync config editor.
2. Replace everything with the text of `powersync/sync-config.yaml`. It now also has `inbox_items` and `preferences`.
3. Press **Validate**, then **Deploy**. Without this, Inbox lines and your Today choices can disappear after upload.

## Test 1: Today

1. Open Orbito. Expected: it opens on **Today** with the date, a greeting with coloured chips (tasks, habits left, Inbox), your habits as cards, the line from waking to bedtime with an orange dot for now, "Time today", "Sleep", and on the right the month, Tasks, Projects and Goals.
2. Click a chip in the greeting. Expected: it opens that page.
3. Tick a habit card's ring. Expected: it fills and "x of y today" changes.

## Test 2: choose the sections

1. Click **Choose sections** (or **Settings** at the bottom of the menu).
2. Switch **Greeting** off. Go back to **Today**. Expected: no greeting.
3. In Settings move **Sleep** up with the arrow. Expected: Today shows Sleep before Time today.
4. Switch every section off. Expected on Today: "No sections are switched on" and **Restore the defaults**. Click it: everything is back.
5. Close and open Orbito. Expected: your choice is kept.

## Test 3: the Quick Launcher

1. Press **Ctrl K** (or click the search box at the top). Expected: a box opens with example lines.
2. Type `task call bank tomorrow 10am high`. Expected, before you press anything: chips "Task", "Call bank", "Tomorrow", "10:00 AM", "High priority".
3. Press **Enter**. Expected: the box closes; the task is on the Tasks page for tomorrow; its notes say "At 10:00 AM".
4. Ctrl K, type the name of one of your habits, Enter. Expected: the habit is marked done today.
5. Ctrl K, type `slept 11 to 6:30`, Enter. Expected: last night is saved on the Sleep page.
6. Ctrl K, type `focus` and the start of an open task's name, Enter. Expected: focus mode starts on that task.
7. Ctrl K, type `maybe learn the guitar`, Enter. Expected: "Captured to the Inbox"; the Inbox shows a count in the menu.
8. Press **Esc** in the box. Expected: it closes.

## Test 4: the Inbox

1. Click **Inbox**. Expected: the line from test 3 step 7, and any notes (`note …` lines).
2. Click **Make a task** on a line. Expected: it becomes a task and leaves the Inbox.
3. Click the X on a line. Expected: it leaves the Inbox.
4. Empty Inbox: "Nothing waiting".

## Not in M3 (do not report these as bugs)

- On Today: Schedule (time blocks), Reminders, meetings, the Life line, Life area scores, Insights and Notes. They come with their features.
- In the launcher: distractions and `event …` lines go to the Inbox for now.
