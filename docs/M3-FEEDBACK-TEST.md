# Test guide: your feedback changes

Before you start: deploy the new sync config (the `notes` stream was added at the bottom of `powersync/sync-config.yaml`). Then start the new Windows build.

If something is wrong, send me the test number, the step number and what you saw.

## Test 1: Notes
1. Click "Notes" in the side menu (under Projects).
2. Click "New note", type a title and some text, pick a project in "Project (optional)", click "Add note".
3. The note shows in the list with the project name on it.
4. Click the note, change the text, click "Save".
5. Open the Projects page, open that project. You should see the note under "Notes". Click it: the Notes page opens on that note.
6. In the project, click "Add note": a new note opens with that project already chosen.
7. Click "New" at the top, then "Note": the Notes page opens with an empty note.
8. In the Notes list, use the filter to show only one project's notes.

## Test 2: The New menu
1. Click "New" at the top. It shows only "Task" and "Note".

## Test 3: Project deadline
1. Open a project (or add a new one). Click "Pick a date" under "Deadline (optional)", pick a date, click "Save".
2. The date shows under the project name in the list and in the open project.
3. Change the date. Then click the small x to remove it. Save. The date is gone.
4. A project without a deadline still saves normally.

## Test 4: Add a task at the top
1. Open a project. The box "Add a task to this project" is now above the task list.

## Test 5: Show or hide completed tasks
1. Open Tasks. Complete a task. It disappears from the list.
2. Click "Show completed". The task shows again with a line through it. The button now says "Hide completed".
3. Click it again. Completed tasks hide.

## Test 6: Today calendar
1. Give a task a due date (for example the 20th of this month).
2. On Today, click that date in the calendar. A list of tasks due that day shows under the calendar. Click the date again to close the list.
3. Click a date with no tasks: it says "No tasks due this day."

## Test 7: Today project link
1. On Today, in "Projects", click one project. That project opens, not the list of projects.

## Test 8: Day progress bar
1. Open Settings. Under "Your day" set "Wake up time" and "Bedtime".
2. Open Today. Under the habits, the bar says "Day progress" with a percent, and a red dot marks your bedtime. The orange dot is "now".
3. The bar starts at your wake time and fills over 24 hours. After your bedtime it says "Past bedtime" and keeps running.

## Test 9: Smooth scrolling
1. On a long page (Tasks with many tasks, or Today), scroll with the mouse wheel. It should glide, not jump.
