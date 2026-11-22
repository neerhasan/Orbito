import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../app/shell.dart'
    show AppPage, currentPageProvider, openProjectRequestProvider;
import '../../data/local/app_database.dart';
import '../../domain/dates.dart';
import '../../domain/focus.dart';
import '../../domain/habits.dart';
import '../../domain/progress.dart';
import '../../domain/sleep.dart';
import '../../domain/task_view.dart' show countOverdue;
import '../../domain/today.dart';
import '../../ui/ember.dart';
import '../../ui/motion.dart';
import '../../ui/widgets.dart';
import '../settings/settings_page.dart' show saveTodaySections;

/// The day picked in the calendar. Null means today. The Tasks section
/// shows the tasks of this day.
class SelectedDay extends Notifier<String?> {
  @override
  String? build() => null;

  void pick(String? day) => state = day;
}

final selectedDayProvider = NotifierProvider<SelectedDay, String?>(
  SelectedDay.new,
);

/// The Today page (design: `Today dashboard · Phase 1`, `Main.dc.html`).
/// It shows the sections the user switched on in Settings, in their order.
/// Sections that need features not built yet (schedule, life line,
/// insights, notes, meetings) are left out until those exist.
class TodayPage extends ConsumerWidget {
  const TodayPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final now = ref.watch(clockProvider)();
    final today = dayKey(now);
    final sections = readSections(ref.watch(todaySectionsProvider).value);
    final main = sections.where((s) => s.column == TodayColumn.main).toList();
    final side = sections.where((s) => s.column == TodayColumn.side).toList();
    void open(AppPage page) =>
        ref.read(currentPageProvider.notifier).open(page);

    Widget build(TodaySection section) => switch (section) {
      TodaySection.greeting => _Greeting(now: now, open: open),
      TodaySection.habits => _HabitsSection(now: now, open: open),
      TodaySection.time => const _TimeToday(),
      TodaySection.sleep => _SleepCard(open: open),
      TodaySection.calendar => const _MiniCalendar(),
      TodaySection.tasks => _TodayTasks(open: open),
      TodaySection.projects => _ProjectsSection(open: open),
      TodaySection.goals => _GoalsSection(open: open),
    };

    // "Time today" and "Sleep" sit side by side when they follow each other.
    final mainWidgets = <Widget>[];
    const pair = {TodaySection.time, TodaySection.sleep};
    for (var i = 0; i < main.length; i++) {
      final section = main[i];
      final next = i + 1 < main.length ? main[i + 1] : null;
      if (pair.contains(section) && next != null && pair.contains(next)) {
        mainWidgets.add(
          TileGrid(
            key: const Key('today-pair'),
            minWidth: 280,
            children: [build(section), build(next)],
          ),
        );
        i++;
      } else {
        mainWidgets.add(
          KeyedSubtree(
            key: Key('today-section-${section.name}'),
            child: build(section),
          ),
        );
      }
    }

    return PageLayout(
      main: [
        Wrap(
          alignment: WrapAlignment.spaceBetween,
          spacing: 12,
          runSpacing: 12,
          children: [
            PageHeader(
              title: 'Today',
              subtitle: '${formatLongDay(today)} ${now.year}',
            ),
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: SoftButton(
                key: const Key('today-customize'),
                icon: Icons.tune,
                label: 'Choose sections',
                onPressed: () => open(AppPage.settings),
              ),
            ),
          ],
        ),
        if (sections.isEmpty)
          Tile(
            padding: const EdgeInsets.all(22),
            child: Column(
              children: [
                Text('No sections are switched on', style: Ember.h3),
                const SizedBox(height: 6),
                Text(
                  'Pick what Today shows in Settings, or bring back the '
                  'default sections.',
                  textAlign: TextAlign.center,
                  style: Ember.meta,
                ),
                const SizedBox(height: 12),
                FilledButton(
                  key: const Key('today-restore'),
                  onPressed: () =>
                      saveTodaySections(context, ref, defaultSections),
                  child: const Text('Restore the defaults'),
                ),
              ],
            ),
          )
        else
          ...mainWidgets,
      ],
      rail: side.isEmpty
          ? null
          : [
              for (final section in side)
                KeyedSubtree(
                  key: Key('today-section-${section.name}'),
                  child: build(section),
                ),
            ],
    );
  }
}

/// A small coloured chip that opens a page.
class _LinkChip extends StatelessWidget {
  const _LinkChip({
    super.key,
    required this.label,
    required this.background,
    required this.foreground,
    required this.onTap,
  });

  final String label;
  final Color background;
  final Color foreground;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      child: Material(
        color: background,
        borderRadius: BorderRadius.circular(7),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: Text(label, style: Ember.text(12, 15, color: foreground)),
          ),
        ),
      ),
    );
  }
}

/// "Good morning. You have 3 tasks · 1 overdue, 2 habits left and 1 line in
/// the Inbox."
class _Greeting extends ConsumerWidget {
  const _Greeting({required this.now, required this.open});

  final DateTime now;
  final ValueChanged<AppPage> open;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final today = dayKey(now);
    final tasks = ref.watch(tasksProvider).value ?? const <Task>[];
    final habits = ref.watch(habitsProvider).value ?? const <Habit>[];
    final logs = ref.watch(habitLogsProvider).value ?? const <HabitLog>[];
    final inbox = ref.watch(inboxProvider).value ?? const <InboxItem>[];
    final dueNow = tasks
        .where(
          (t) =>
              t.status != TaskStatus.done &&
              t.dueDate != null &&
              t.dueDate!.compareTo(today) <= 0,
        )
        .length;
    final overdue = countOverdue(tasks, today: today);
    final progress = todayProgress(habits, logs, today: today);
    final habitsLeft = progress.planned - progress.done;
    final text = Ember.text(14, 17, color: Ember.ink);
    return Container(
      key: const Key('today-greeting'),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Ember.tile,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Wrap(
        spacing: 6,
        runSpacing: 6,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Text('${greetingFor(now)}. You have', style: text),
          _LinkChip(
            key: const Key('greeting-tasks'),
            label: overdue == 0
                ? countOf(dueNow, 'task')
                : '${countOf(dueNow, 'task')} · $overdue overdue',
            background: Ember.nowSoft,
            foreground: Ember.nowInk,
            onTap: () => open(AppPage.tasks),
          ),
          _LinkChip(
            key: const Key('greeting-habits'),
            label: '${countOf(habitsLeft, 'habit')} left',
            background: Ember.goodBg,
            foreground: Ember.goodInk,
            onTap: () => open(AppPage.habits),
          ),
          Text('and', style: text),
          _LinkChip(
            key: const Key('greeting-inbox'),
            label: '${countOf(inbox.length, 'line')} in the Inbox',
            background: Ember.violetBg,
            foreground: Ember.violetInk,
            onTap: () => open(AppPage.inbox),
          ),
        ],
      ),
    );
  }
}

/// Habit cards and the day from waking to bedtime.
class _HabitsSection extends ConsumerWidget {
  const _HabitsSection({required this.now, required this.open});

  final DateTime now;
  final ValueChanged<AppPage> open;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final today = dayKey(now);
    final habits = ref.watch(habitsProvider).value ?? const <Habit>[];
    final logs = ref.watch(habitLogsProvider).value ?? const <HabitLog>[];
    final progress = todayProgress(habits, logs, today: today);
    final planned = habits.where((h) => isPlanned(h, today)).toList();

    Future<void> mark(Habit habit, bool done) async {
      final userId = ref.read(userIdProvider);
      if (userId == null) return;
      try {
        await ref
            .read(habitRepositoryProvider)
            .setMark(
              userId: userId,
              habitId: habit.id,
              day: today,
              status: done ? null : HabitMark.done,
            );
      } catch (error) {
        if (context.mounted) showMessage(context, 'Could not save. ($error)');
      }
    }

    // The 24-hour day starts at the wake time set in Settings.
    final times = ref.watch(dayTimesProvider).value;
    final wakeTime = times?.wake ?? '07:00';
    final bedTime = times?.bed ?? '23:00';
    final day = dayProgress(now, wake: wakeTime, bed: bedTime);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionHeader(
          icon: Icons.repeat,
          title: 'Habits',
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '${progress.done} of ${progress.planned} today',
                style: Ember.meta,
              ),
            ],
          ),
        ),
        if (planned.isEmpty)
          Text(
            habits.isEmpty
                ? 'No habits yet. Add three or four on the Habits page.'
                : 'No habits planned today. A rest day.',
            style: Ember.meta,
          )
        else
          TileGrid(
            minWidth: 170,
            children: [
              for (final habit in planned)
                _HabitCard(
                  habit: habit,
                  marks: marksOf(habit.id, logs),
                  today: today,
                  onMark: mark,
                ),
            ],
          ),
        const SizedBox(height: 14),
        _DayBar(share: day.share, bedShare: day.bedShare),
        const SizedBox(height: 6),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Day progress · ${day.percent}%',
              key: const Key('today-day-progress'),
              style: Ember.caption.copyWith(fontWeight: FontWeight.w400),
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const ColorDot(_bedRed, size: 6),
                const SizedBox(width: 5),
                Text(
                  day.pastBed
                      ? 'Past bedtime ${formatTime(bedTime)}'
                      : 'Bedtime ${formatTime(bedTime)}',
                  key: const Key('today-bedtime'),
                  style: Ember.caption.copyWith(fontWeight: FontWeight.w400),
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }
}

class _HabitCard extends StatelessWidget {
  const _HabitCard({
    required this.habit,
    required this.marks,
    required this.today,
    required this.onMark,
  });

  final Habit habit;
  final Map<String, String> marks;
  final String today;
  final Future<void> Function(Habit habit, bool done) onMark;

  @override
  Widget build(BuildContext context) {
    final state = dayState(habit, marks, today, today: today);
    final week = lastDays(habit, marks, today: today);
    final done = state == HabitDay.done;
    final weekDone = week.where((d) => d == HabitDay.done).length;
    return Tile(
      key: Key('today-habit-${habit.id}'),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  habit.name,
                  overflow: TextOverflow.ellipsis,
                  style: Ember.h3.copyWith(color: Ember.ink),
                ),
              ),
              TaskRing(
                done: done,
                priority: TaskPriority.none,
                label: '${done ? 'Undo' : 'Done'} ${habit.name}',
                onTap: () => onMark(habit, done),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              for (var i = 0; i < week.length; i++) ...[
                if (i > 0) const SizedBox(width: 6),
                AnimatedContainer(
                  duration: Motion.of(context, Motion.base),
                  width: 9,
                  height: 9,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: switch (week[i]) {
                      HabitDay.done => Ember.ink,
                      HabitDay.missed => Ember.mark,
                      HabitDay.off => Ember.line,
                      _ => Colors.transparent,
                    },
                    border: switch (week[i]) {
                      HabitDay.open => Border.all(color: Ember.now, width: 1.6),
                      HabitDay.skipped => Border.all(
                        color: Ember.ring,
                        width: 1.6,
                      ),
                      _ => null,
                    },
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 10),
          Text('$weekDone of 7 this week', style: Ember.meta),
        ],
      ),
    );
  }
}

/// The red of the bedtime dot.
const _bedRed = Color(0xFFD64545);

/// The 24 hours from waking: solid for the part that has passed, dotted for
/// what is left, a red dot at bedtime and an orange dot for now.
class _DayBar extends StatelessWidget {
  const _DayBar({required this.share, required this.bedShare});

  final double share;
  final double bedShare;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(end: share),
      duration: Motion.of(context, Motion.slow),
      curve: Motion.soft,
      builder: (context, value, _) => SizedBox(
        key: const Key('today-day-bar'),
        height: 10,
        child: CustomPaint(
          size: const Size(double.infinity, 10),
          painter: _DayBarPainter(value, bedShare),
        ),
      ),
    );
  }
}

class _DayBarPainter extends CustomPainter {
  _DayBarPainter(this.share, this.bedShare);

  final double share;
  final double bedShare;

  @override
  void paint(Canvas canvas, Size size) {
    final y = size.height / 2;
    final at = size.width * share;
    canvas.drawLine(
      Offset(0, y),
      Offset(at, y),
      Paint()
        ..color = Ember.ink
        ..strokeWidth = 2
        ..strokeCap = StrokeCap.round,
    );
    final dots = Paint()..color = Ember.ring;
    for (var x = at + 6; x < size.width; x += 5) {
      canvas.drawCircle(Offset(x, y), 1, dots);
    }
    canvas.drawCircle(
      Offset(size.width * bedShare, y),
      4,
      Paint()..color = _bedRed,
    );
    canvas.drawCircle(Offset(at, y), 5, Paint()..color = Ember.now);
  }

  @override
  bool shouldRepaint(_DayBarPainter old) =>
      old.share != share || old.bedShare != bedShare;
}

/// Focused time since waking, against the rest of the day so far.
class _TimeToday extends ConsumerWidget {
  const _TimeToday();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final now = ref.watch(clockProvider)();
    final today = dayKey(now);
    final sessions =
        ref.watch(focusSessionsProvider).value ?? const <FocusSession>[];
    final timer = ref.watch(focusTimerProvider).value;
    final wake = ref.watch(dayTimesProvider).value?.wake ?? '07:00';
    final saved = sessionsOn(
      sessions,
      today,
    ).fold<int>(0, (sum, session) => sum + session.focusSeconds);
    final focused = saved + (timer == null ? 0 : workedMs(timer, now) ~/ 1000);
    final sinceWake = math.max(
      0,
      (now.hour * 60 + now.minute - minutesOf(wake)!) * 60,
    );
    final other = math.max(0, sinceWake - focused);
    return Tile(
      key: const Key('today-time'),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(Icons.schedule, size: 16, color: Ember.ink),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Time today',
                  style: Ember.h3.copyWith(color: Ember.ink),
                ),
              ),
              Text('Since ${formatTime(wake)}', style: Ember.meta),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: SizedBox(
              height: 8,
              child: Row(
                children: [
                  if (focused > 0)
                    Expanded(
                      flex: focused,
                      child: Container(color: Ember.ink),
                    ),
                  if (focused > 0 && other > 0) const SizedBox(width: 3),
                  Expanded(
                    flex: math.max(1, other),
                    child: Container(color: Ember.mark),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 14,
            children: [
              _Legend(Ember.ink, 'Focused ${formatWorked(focused)}'),
              _Legend(Ember.ring, 'Other ${formatWorked(other)}'),
            ],
          ),
        ],
      ),
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend(this.color, this.label);

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        ColorDot(color, size: 6),
        const SizedBox(width: 5),
        Text(label, style: Ember.caption.copyWith(color: Ember.ink2)),
      ],
    );
  }
}

/// Last night, how consistent bedtimes are, and the last 7 nights.
class _SleepCard extends ConsumerWidget {
  const _SleepCard({required this.open});

  final ValueChanged<AppPage> open;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final today = dayKey(ref.watch(clockProvider)());
    final nights = ref.watch(sleepLogsProvider).value ?? const <SleepLog>[];
    final week = nightsBefore(nights, end: today, count: 7);
    final lastNight = nightOn(nights, today);
    final steady = consistency(nightsBefore(nights, end: today, count: 14));
    return Tile(
      key: const Key('today-sleep'),
      onTap: () => open(AppPage.sleep),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(Icons.bedtime_outlined, size: 16, color: Ember.ink),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Sleep',
                  style: Ember.h3.copyWith(color: Ember.ink),
                ),
              ),
              if (steady != null)
                Tag(
                  '$steady% consistent',
                  background: Ember.goodBg,
                  foreground: Ember.goodInk,
                ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      lastNight == null
                          ? '—'
                          : formatMinutes(
                              sleepMinutes(
                                lastNight.bedTime,
                                lastNight.wakeTime,
                              ),
                            ),
                      style: Ember.stat.copyWith(color: Ember.ink),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      lastNight == null
                          ? 'Last night is not logged yet'
                          : '${formatTime(lastNight.bedTime)} to '
                                '${formatTime(lastNight.wakeTime)}',
                      style: Ember.meta,
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  SizedBox(
                    height: 36,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        for (var i = 0; i < week.length; i++) ...[
                          if (i > 0) const SizedBox(width: 4),
                          _NightBar(night: week[i], last: i == week.length - 1),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text('Last 7 nights', style: Ember.caption),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _NightBar extends StatelessWidget {
  const _NightBar({required this.night, required this.last});

  final SleepLog? night;
  final bool last;

  @override
  Widget build(BuildContext context) {
    final night = this.night;
    final minutes = night == null
        ? 0
        : sleepMinutes(night.bedTime, night.wakeTime);
    final height = night == null
        ? 3.0
        : math.max(6.0, minutes / 600 * 36).clamp(3.0, 36.0);
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: height),
      duration: Motion.of(context, Motion.slow),
      curve: Motion.soft,
      builder: (context, value, _) => Container(
        width: 6,
        height: value,
        decoration: BoxDecoration(
          color: night == null
              ? Ember.line
              : last
              ? Ember.now
              : Ember.mark,
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    );
  }
}

/// The month, Sunday first as in the design. Today is an orange circle; a
/// small dot marks days with open tasks due.
class _MiniCalendar extends ConsumerStatefulWidget {
  const _MiniCalendar();

  @override
  ConsumerState<_MiniCalendar> createState() => _MiniCalendarState();
}

class _MiniCalendarState extends ConsumerState<_MiniCalendar> {
  var _offset = 0;

  @override
  Widget build(BuildContext context) {
    final now = ref.watch(clockProvider)();
    final today = dayKey(now);
    final selected = ref.watch(selectedDayProvider);
    final tasks = ref.watch(tasksProvider).value ?? const <Task>[];
    final month = DateTime(now.year, now.month + _offset);
    final days = DateTime(month.year, month.month + 1, 0).day;
    final lead = DateTime(month.year, month.month).weekday % 7;
    final due = {
      for (final task in tasks)
        if (task.status != TaskStatus.done && task.dueDate != null)
          task.dueDate!,
    };

    Widget day(int n) {
      if (n < 1 || n > days) return const SizedBox(height: 36);
      final key = dayKey(DateTime(month.year, month.month, n));
      final isToday = key == today;
      final isSelected = key == selected;
      return InkWell(
        key: Key('today-day-$key'),
        borderRadius: BorderRadius.circular(10),
        // A second click, or a click on today, goes back to today.
        onTap: () => ref
            .read(selectedDayProvider.notifier)
            .pick(isSelected || isToday ? null : key),
        child: SizedBox(
          height: 36,
          child: Column(
            children: [
              Container(
                width: 26,
                height: 26,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isToday ? Ember.now : null,
                  border: isSelected
                      ? Border.all(color: Ember.ink, width: 1.5)
                      : null,
                ),
                child: Text(
                  '$n',
                  style: Ember.text(
                    12,
                    15,
                    weight: isToday ? 600 : 400,
                    color: isToday ? Ember.white : Ember.ink,
                  ),
                ),
              ),
              if (due.contains(key))
                Padding(
                  padding: EdgeInsets.only(top: 2),
                  child: ColorDot(Ember.ink3, size: 4),
                ),
            ],
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                '${monthNames[month.month - 1]} ${month.year}',
                key: const Key('today-month'),
                style: Ember.h2,
              ),
            ),
            IconButton(
              key: const Key('today-month-back'),
              tooltip: 'Previous month',
              iconSize: 18,
              color: Ember.ink2,
              visualDensity: VisualDensity.compact,
              onPressed: () => setState(() => _offset--),
              icon: const Icon(Icons.chevron_left),
            ),
            IconButton(
              key: const Key('today-month-next'),
              tooltip: 'Next month',
              iconSize: 18,
              color: Ember.ink2,
              visualDensity: VisualDensity.compact,
              onPressed: () => setState(() => _offset++),
              icon: const Icon(Icons.chevron_right),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            for (final letter in const ['S', 'M', 'T', 'W', 'T', 'F', 'S'])
              Expanded(
                child: Text(
                  letter,
                  textAlign: TextAlign.center,
                  style: Ember.caption,
                ),
              ),
          ],
        ),
        const SizedBox(height: 6),
        SoftSwitcher(
          child: Column(
            key: ValueKey(month),
            children: [
              for (var week = 0; week * 7 < lead + days; week++)
                Row(
                  children: [
                    for (var col = 0; col < 7; col++)
                      Expanded(child: day(week * 7 + col - lead + 1)),
                  ],
                ),
            ],
          ),
        ),
      ],
    );
  }
}

/// The tasks of the day picked in the calendar (today when none is picked:
/// then overdue tasks show too). "Add one" turns into a box in place.
class _TodayTasks extends ConsumerStatefulWidget {
  const _TodayTasks({required this.open});

  final ValueChanged<AppPage> open;

  @override
  ConsumerState<_TodayTasks> createState() => _TodayTasksState();
}

class _TodayTasksState extends ConsumerState<_TodayTasks> {
  final _title = TextEditingController();
  final _focus = FocusNode();
  var _adding = false;
  var _busy = false;

  @override
  void dispose() {
    _title.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _startAdding() {
    setState(() => _adding = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focus.requestFocus();
    });
  }

  void _stopAdding() => setState(() {
    _adding = false;
    _title.clear();
  });

  /// Adds the typed task to [day]. The box closes only when it worked, so
  /// the typed title is never lost.
  Future<void> _save(String day) async {
    final userId = ref.read(userIdProvider);
    final title = _title.text.trim();
    if (userId == null || title.isEmpty || _busy) return;
    setState(() => _busy = true);
    try {
      await ref
          .read(taskRepositoryProvider)
          .addTask(userId: userId, title: title, dueDate: day);
      if (mounted) _stopAdding();
    } catch (error) {
      if (mounted) showMessage(context, 'Could not add the task. ($error)');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final today = dayKey(ref.watch(clockProvider)());
    final day = ref.watch(selectedDayProvider) ?? today;
    final isToday = day == today;
    final tasks = ref.watch(tasksProvider).value ?? const <Task>[];
    final projects = ref.watch(projectsProvider).value ?? const <Project>[];
    final openTasks = tasks.where((t) => t.status != TaskStatus.done);
    final overdue = isToday
        ? openTasks
              .where(
                (t) => t.dueDate != null && t.dueDate!.compareTo(today) < 0,
              )
              .toList()
        : const <Task>[];
    // Today shows what is still open; another day shows all its tasks,
    // open ones first.
    final dueOnDay = isToday
        ? openTasks.where((t) => t.dueDate == day).toList()
        : [
            ...openTasks.where((t) => t.dueDate == day),
            ...tasks.where(
              (t) => t.status == TaskStatus.done && t.dueDate == day,
            ),
          ];

    Widget row(Task task) {
      final project = projects.where((p) => p.id == task.projectId).firstOrNull;
      final done = task.status == TaskStatus.done;
      final late = !done && task.dueDate!.compareTo(today) < 0;
      return Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Appear(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Transform.translate(
                offset: const Offset(-5, -6),
                child: TaskRing(
                  done: done,
                  priority: task.priority,
                  label: '${done ? 'Undo' : 'Complete'} ${task.title}',
                  onTap: () => ref
                      .read(taskRepositoryProvider)
                      .setDone(task.id, done: !done),
                ),
              ),
              Expanded(
                child: InkWell(
                  key: Key('today-task-${task.id}'),
                  onTap: () => widget.open(AppPage.tasks),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        task.title,
                        style: Ember.item.copyWith(
                          color: done ? Ember.ink3 : Ember.ink,
                          decoration: done ? TextDecoration.lineThrough : null,
                        ),
                      ),
                      // The heading above already says the day; overdue
                      // tasks still show theirs.
                      if (task.dueDate != day || project != null) ...[
                        const SizedBox(height: 5),
                        Wrap(
                          spacing: 6,
                          children: [
                            if (task.dueDate != day)
                              Text(
                                formatRelativeDay(task.dueDate!, today: today),
                                style: Ember.meta.copyWith(
                                  color: late ? Ember.nowInk : Ember.ink2,
                                ),
                              ),
                            if (project != null)
                              Tag(
                                project.name,
                                background: ProjectColors.of(project.color)
                                    .soft,
                                foreground: ProjectColors.of(project.color)
                                    .text,
                              ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    final adder = _adding
        ? CallbackShortcuts(
            key: const ValueKey('adding'),
            bindings: {
              const SingleActivator(LogicalKeyboardKey.escape): _stopAdding,
            },
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    key: const Key('today-add-field'),
                    controller: _title,
                    focusNode: _focus,
                    onSubmitted: (_) => _save(day),
                    decoration: InputDecoration(
                      hintText: isToday
                          ? 'Add a task for today'
                          : 'Add a task for ${formatRelativeDay(day, today: today).toLowerCase()}',
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                FilledButton(
                  key: const Key('today-add-save'),
                  onPressed: _busy ? null : () => _save(day),
                  child: const Text('Add'),
                ),
                IconButton(
                  key: const Key('today-add-cancel'),
                  tooltip: 'Cancel',
                  iconSize: 16,
                  color: Ember.ink2,
                  onPressed: _stopAdding,
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
          )
        : Align(
            key: const ValueKey('button'),
            alignment: Alignment.centerLeft,
            child: SoftButton(
              key: const Key('today-add-task'),
              icon: Icons.add,
              label: 'Add one',
              onPressed: _startAdding,
            ),
          );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionHeader(
          icon: Icons.check_circle_outline,
          title: 'Tasks',
          trailing: isToday
              ? null
              : TextButton(
                  key: const Key('today-tasks-back'),
                  onPressed: () =>
                      ref.read(selectedDayProvider.notifier).pick(null),
                  child: const Text('Back to today'),
                ),
        ),
        if (overdue.isNotEmpty) ...[
          Text(
            'Overdue · ${overdue.length}',
            style: Ember.caption.copyWith(color: Ember.nowInk),
          ),
          const SizedBox(height: 10),
          for (final task in overdue) row(task),
        ],
        Text(
          '${isToday ? 'Today' : formatLongDay(day)} · ${dueOnDay.length}',
          key: const Key('today-tasks-day'),
          style: Ember.caption,
        ),
        const SizedBox(height: 10),
        if (dueOnDay.isEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Text(
              isToday ? 'Nothing else due today.' : 'No tasks due this day.',
              style: Ember.meta,
            ),
          )
        else
          for (final task in dueOnDay) row(task),
        SoftSwitcher(child: adder),
      ],
    );
  }
}

/// A row with a coloured icon square, a name, a percent, a bar and a line.
class _ProgressRow extends StatelessWidget {
  const _ProgressRow({
    super.key,
    required this.icon,
    required this.swatch,
    required this.name,
    required this.percent,
    required this.detail,
    required this.onTap,
  });

  final IconData icon;
  final Swatch swatch;
  final String name;
  final int percent;
  final String detail;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: swatch.soft,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, size: 15, color: swatch.text),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          name,
                          overflow: TextOverflow.ellipsis,
                          style: Ember.item.copyWith(color: Ember.ink),
                        ),
                      ),
                      Text('$percent%', style: Ember.meta),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ProgressBar(percent),
                  const SizedBox(height: 6),
                  Text(detail, style: Ember.meta),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProjectsSection extends ConsumerWidget {
  const _ProjectsSection({required this.open});

  final ValueChanged<AppPage> open;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final now = ref.watch(clockProvider)();
    final today = dayKey(now);
    final projects = ref.watch(projectsProvider).value ?? const <Project>[];
    final tasks = ref.watch(tasksProvider).value ?? const <Task>[];
    final sessions =
        ref.watch(focusSessionsProvider).value ?? const <FocusSession>[];
    final byTask = secondsByTask(sessions);
    final month = '${now.year}-${now.month.toString().padLeft(2, '0')}';
    final thisMonth = sessions
        .where((s) => (dayKeyOfStoredTime(s.startedAt) ?? '').startsWith(month))
        .fold<int>(0, (sum, s) => sum + s.focusSeconds);
    final shown = projects.take(5).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionHeader(
          icon: Icons.folder_outlined,
          title: 'Projects',
          trailing: Text(
            '${formatWorked(thisMonth)} this month',
            style: Ember.meta,
          ),
        ),
        if (shown.isEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Text('No projects yet.', style: Ember.meta),
          ),
        for (final project in shown)
          _projectRow(ref, project, tasks, byTask, today),
        Align(
          alignment: Alignment.centerLeft,
          child: SoftButton(
            icon: Icons.add,
            label: 'Add project',
            onPressed: () => open(AppPage.projects),
          ),
        ),
      ],
    );
  }

  Widget _projectRow(
    WidgetRef ref,
    Project project,
    List<Task> tasks,
    Map<String, int> byTask,
    String today,
  ) {
    final own = tasks.where((t) => t.projectId == project.id).toList();
    final done = own.where((t) => t.status == TaskStatus.done).length;
    final seconds = secondsOfProject(project.id, tasks, byTask);
    return _ProgressRow(
      key: Key('today-project-${project.id}'),
      icon: ItemIcons.of(project.icon),
      swatch: ProjectColors.of(project.color),
      name: project.name,
      percent: percentDone(own),
      detail:
          '$done of ${countOf(own.length, 'task')}'
          '${seconds == 0 ? '' : ' · ${formatWorked(seconds)}'}'
          '${project.deadline == null ? '' : ' · Due ${formatRelativeDay(project.deadline!, today: today)}'}',
      // Opens this project, not the list of projects.
      onTap: () {
        ref.read(openProjectRequestProvider.notifier).ask(project.id);
        open(AppPage.projects);
      },
    );
  }
}

class _GoalsSection extends ConsumerWidget {
  const _GoalsSection({required this.open});

  final ValueChanged<AppPage> open;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final today = dayKey(ref.watch(clockProvider)());
    final goals = ref.watch(goalsProvider).value ?? const <Goal>[];
    final projects = ref.watch(projectsProvider).value ?? const <Project>[];
    final tasks = ref.watch(tasksProvider).value ?? const <Task>[];
    final areas = ref.watch(lifeAreasProvider).value ?? const <LifeArea>[];
    final shown = goals.take(5).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionHeader(
          icon: Icons.flag_outlined,
          title: 'Goals',
          trailing: Text('${goals.length} active', style: Ember.meta),
        ),
        if (shown.isEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Text('No goals yet.', style: Ember.meta),
          ),
        for (final goal in shown)
          _ProgressRow(
            key: Key('today-goal-${goal.id}'),
            icon: ItemIcons.of(goal.icon, orElse: ItemIcons.goalFallback),
            swatch: GoalColors.of(goal.color),
            name: goal.title,
            percent: percentDone(
              tasksOfGoal(goal.id, projects: projects, tasks: tasks),
            ),
            detail: [
              areas.where((a) => a.id == goal.lifeAreaId).firstOrNull?.name ??
                  'No life area',
              if (goal.targetDate != null)
                formatShortDay(goal.targetDate!, today: today),
            ].join(' · '),
            onTap: () => open(AppPage.goals),
          ),
        Align(
          alignment: Alignment.centerLeft,
          child: SoftButton(
            icon: Icons.add,
            label: 'Add goal',
            onPressed: () => open(AppPage.goals),
          ),
        ),
      ],
    );
  }
}
