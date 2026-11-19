# Test guide: the Calendar page

Before you start: deploy the new sync config (an `events` part was added at the bottom of `powersync/sync-config.yaml`). Then start the new Windows build.

If something is wrong, send me the test number, the step number and what you saw.

## Test 1: Open the calendar
1. Click "Calendar" in the side menu (under Notes).
2. You see this week, Sunday to Saturday. Today's number is orange and its column is lightly tinted. An orange line marks the time now.
3. Above the grid: the month, and "Week N · first to last day".

## Test 2: Add an event
1. Click "Event" (top right). The right panel shows "New event", starting at the next full hour.
2. Type a name, change the day, start and end if you like, pick a project, write a note. Click "Add event".
3. The event shows on the grid at its time, in blue (or in the project's colour).
4. Click an empty place on the grid, for example Thursday at 3 PM. The form starts at that day and time.

## Test 3: Change and delete an event
1. Click an event on the grid. The right panel says "Edit event".
2. Change the name or the time, click "Save". The grid updates.
3. Click "Delete event" and confirm. It is gone.

## Test 4: Tasks, deadlines and focus
1. A task with a due date shows in the "All day" row of its day. Click it: the Tasks page opens.
2. A project deadline shows as "Due: project name". Click it: that project opens.
3. A focus session you did shows as a grey block at the time it ran.

## Test 5: Views and moving around
1. Click Month, Week, 4 day, 3 day and 2 day. Each view changes the grid.
2. Use the arrows to go back and forward. "Today" brings you back.
3. In Month, click a day: the right panel lists what is on that day, and a new event starts on that day.

## Test 6: Sync
1. Add an event, close Orbito, open it again. The event is still there.
