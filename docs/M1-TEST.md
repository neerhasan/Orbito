# M1 test guide: life areas, goals, projects and tasks (Windows)

This guide is for the founder. It takes about 20 minutes. Do the steps in order on the PC. If a step does not do what the guide says, stop and tell Claude the step number and what you saw.

The phone is not part of this test. The decision is: PC first.

## Before you start

1. Do this once: open PowerSync in the browser, open the Orbito instance, and open the sync rules (sync config) editor. Replace everything there with the text of the file `powersync/sync-config.yaml` from the project folder. Press **Validate**, then **Deploy**. Without this step your data stays on the PC and does not reach the server.
2. Start Orbito on the PC: `build\windows\x64\runner\Release\orbito.exe` in the project folder.
3. Sign in with your test account.

## Test 1: first-run setup

1. With a new account you see "Which parts of your life do you want to look after?".
2. Click three or four areas. The button changes to "Add 3 areas" (or 4).
3. Click the button.
4. Expected: the areas appear in the menu on the left, each with a coloured dot.

## Test 2: life areas

1. Click **All areas** in the menu on the left.
2. Type a new name on the right, pick a colour, click **Add area**. Expected: it appears in the list.
3. Click **Add area** with an empty name. Expected: the message "Give the area a name.", and nothing is added.
4. Click an area in the list, change its name, click **Save**. Expected: the new name shows in the list and in the menu.
5. Close the form with the X. Type the name of an area you already have and click **Add area**. Expected: the message "You already have an area with this name.", and no second area.

## Test 3: goals

1. Click **Goals** in the menu.
2. Add a goal: a title, a life area, a target date, and a "done when" line. Click **Add goal**.
3. Expected: the goal is in the list with its area and date. It shows "No tasks yet" and 0%.
4. Click the goal. Expected: there is no box to add a task here. A task belongs to a project, and the project serves the goal.

## Test 4: projects

1. Click **Projects** in the menu.
2. Add a project: a name, the goal from test 3 under "Serves goal", a colour and an icon. Click **Add project**. Expected: the project is in the list with the icon you picked, in the colour you picked.
3. Click the project. Add two tasks on the right. Complete one.
4. Expected: the project shows "1 of 2 tasks" and 50%.
5. Go back to **Goals**. Expected: the goal counts the two tasks of its project and shows "1 of 2 tasks", 50%.

## Test 5: the Tasks page

1. Click **Tasks** in the menu.
2. Expected: every open task is on one line. Tasks of a project show the project name on the right in the project's colour.
3. Type a task in "Add a task" and press Enter. Expected: it appears under "No date".
4. Click the new task. On the right there is a project box and no goal box. Pick the project from test 4. Expected: a line under the box says which goal the task now serves. Then click **Today** next to the date, click **High**, click **Save**. Expected: the task moves to the "Today" group, the word "Today" is orange, and a small "High" label sits next to the title.
5. Chart: click the circle in front of a task. Expected: the task leaves the list and the orange point at the right end of the chart goes up by one. Click **Week**, **Month** and **Year**: the chart changes each time.
6. Grouping: change "Group: Due date" to Project, then Goal, then Priority. Expected: the headings change each time.
7. Sorting: change "Sort: Due date" to Title. Expected: tasks inside a group are in A to Z order.
8. Filters: change "Open" to "Done". Expected: only completed tasks. Change it to "All tasks". Then pick a project under "All projects". Expected: only that project's tasks.
9. Set the filters back to "Open" and "All projects".
10. Month view: click **Month**. Expected: a calendar of this month. Today has an orange border. Tasks with a due date sit on their day. The arrows move to the next and the previous month.
11. Delete: click **List**, click a task, click **Delete task**, confirm. Expected: the task is gone.

## Test 6: deleting with linked items

1. Go to **Projects**. Click a project that has tasks. Click **Delete project**.
2. Expected: a question appears: keep the tasks without a project, or delete them too. **Cancel** deletes nothing.
3. Choose **Keep the tasks**. Expected: the project is gone; its tasks are still on the Tasks page, without a project name.

## Test 7: the data stays and syncs

1. Close Orbito completely and start it again. Expected: everything is still there.
2. Turn the PC's Wi-Fi off. Add a task. Expected: it is saved at once, and the status at the bottom left says there is a change waiting to upload.
3. Turn Wi-Fi on. Expected: within about a minute the status goes back to "Synced".
4. Only if you did "Before you start" step 1: open Supabase in the browser, open **Table Editor**, open the table `tasks`. Expected: your tasks are there.

## Not in M1 (do not report these as bugs)

- The phone layout. The app is laid out for a desktop window only.
- Typing a date or a project inside the task title ("review contract fri 3pm #work"). That belongs to the Quick Launcher, a later milestone.
- Subtasks, tags, a time of day, and focus time on a task.
- Today, Upcoming, Inbox, Habits, Sleep, Focus and the other pages of the prototype.
