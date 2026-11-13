# M2 test guide: habits, sleep and the focus timer (Windows)

This guide is for the founder. It takes about 20 minutes. Do the steps in order on the PC. If a step does not do what the guide says, stop and tell Claude the test number, the step number and what you saw.

## Before you start (do this first, once)

1. Open PowerSync in the browser, open the Orbito instance, and open the sync config editor (the same place as for M1).
2. Replace everything there with the text of the file `powersync/sync-config.yaml` from the project folder. It now has four more parts: habits, habit_logs, focus_sessions and sleep_logs.
3. Press **Validate**, then **Deploy**.

Why this matters: without it, new habits, nights and focus sessions can disappear from the app after they are uploaded. Do not test M2 before this step.

Then open Orbito from the Desktop or the Start menu and sign in.

## Test 1: soft motion

1. Click between **Tasks**, **Projects**, **Habits** and **Sleep** in the menu. Expected: pages fade softly into place, nothing jumps.
2. Hover over a project tile and press on it. Expected: it darkens a little and gives softly.
3. Complete a task on the Tasks page. Expected: the ring fills and the tick grows into place; the title fades to grey.

## Test 2: habits

1. Click **Habits** under "Daily". Expected: "No habits yet".
2. On the right, type "Read", pick a life area, leave all seven days on, pick a usual time, click **Add habit**. Expected: the habit appears with its area, "Every day" and the time.
3. Click the ring in front of "Read". Expected: it fills; the subtitle says "1 of 1 done"; the "Today" tile shows "1 of 1". Click it again: it opens again.
4. Click **Skip**. Expected: the button becomes **Unskip** and the last dot is a grey ring. Click **Unskip**.
5. Click the habit tile (not the ring). On the right, switch off Saturday and Sunday. Expected: "Weekdays" under the days. Click **Save**.
6. Expected nowhere on the page: the word "streak". At the bottom: "A missed day is data, not a failure."

## Test 3: sleep

1. Click **Sleep**. Expected: four tiles, the chart "When you slept" and on the right "Log a night".
2. Set the bedtime and wake time for last night with the two time buttons. Expected: the "Duration" box updates at once.
3. Pick "Good" under "How rested?", type a short note, click **Save night**. Expected: "Last night" shows the length; the night is in "Recent nights"; an orange bar is at the right end of the chart.
4. Click the night under "Recent nights". Change the wake time to the same time as the bedtime. Expected: "Duration 0m" and a note to check the times. Click **Save**: Orbito asks first. Click **Go back**.
5. Switch between **7 nights**, **14 nights** and **30 nights**. Expected: the chart and the average change.

## Test 4: the focus timer

1. Click **Focus**. Expected: your open tasks, each with a **Start** button, and "Planned length".
2. Pick **25m**, then click **Start** next to a task. Expected: the whole window turns into focus mode: the task name, an orange clock counting up, a ring that slowly fills, and a soft glow behind it.
3. Click the round orange **Pause** button. Expected: the clock turns grey and stops; "Paused". Click it again to go on.
4. Click **Back to Orbito** (or press Esc). Expected: the normal app, with a small timer at the top of the menu, still counting. Click it: focus mode comes back.
5. Type a line under "Task notes" and click **Save note**. Then click **Stop and save** (after at least one minute). Expected: a message "Saved … of focus"; the Focus page lists the session under "Today".
6. Go to **Tasks**, open that task. Expected: "Focus time: …" and the note you typed. On **Projects**, its project shows "… focused".
7. Start a timer again, then close Orbito completely while it runs. Wait two minutes and open Orbito. Expected: the timer is in the menu and the time kept counting.

## Test 5: sync

1. Only if you did "Before you start": open Supabase in the browser, **Table Editor**, the tables `habits`, `sleep_logs` and `focus_sessions`. Expected: your rows are there.

## Not in M2 (do not report these as bugs)

- Logging distractions during focus, and the Time page.
- A habit that fills itself in from the sleep log ("wake by 7:00").
- A reason for a missed habit, and the "Patterns" box.
- Sleep from a watch or phone.
- Subtasks and "Up next" in focus mode.
- The phone layout.
