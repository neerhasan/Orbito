import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../data/local/app_database.dart';
import '../../domain/dates.dart';
import '../../domain/focus.dart';
import '../../domain/focus_report.dart';
import '../../ui/ember.dart';
import '../../ui/widgets.dart';
import 'focus_parts.dart';

/// The Focus report (after the founder's inspiration images, in Orbito's
/// style): six numbers, the records grid, focus time by project or task,
/// the share of each project, focus by day, and the daily focus goal.
class FocusReportView extends ConsumerStatefulWidget {
  const FocusReportView({super.key, required this.onBack});

  final VoidCallback onBack;

  @override
  ConsumerState<FocusReportView> createState() => _FocusReportViewState();
}

class _FocusReportViewState extends ConsumerState<FocusReportView> {
  var _period = FocusPeriod.week;
  String? _anchor;
  String? _goalMonth;
  var _byTask = false;
  var _recordDays = 14;

  @override
  Widget build(BuildContext context) {
    final tasks = ref.watch(tasksProvider).value ?? const <Task>[];
    final projects = ref.watch(projectsProvider).value ?? const <Project>[];
    final sessions =
        ref.watch(focusSessionsProvider).value ?? const <FocusSession>[];
    final goal = ref.watch(focusGoalProvider).value ?? defaultFocusGoalMinutes;
    final today = dayKey(ref.watch(clockProvider)());
    final tasksById = {for (final task in tasks) task.id: task};
    final projectsById = {for (final project in projects) project.id: project};
    final anchor = _anchor ?? today;
    final range = focusRange(_period, anchor);
    final inPeriod = sessionsIn(sessions, range);
    final todayRange = focusRange(FocusPeriod.day, today);
    final weekRange = focusRange(FocusPeriod.week, today);

    String projectName(String? id) => projectsById[id]?.name ?? 'No project';
    String taskName(String? id) => tasksById[id]?.title ?? 'No task';

    final shares = _byTask
        ? secondsByTaskSorted(inPeriod)
        : secondsByProject(inPeriod, tasksById);
    final projectShares = secondsByProject(inPeriod, tasksById);

    return PageLayout(
      main: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Expanded(
              child: PageHeader(
                title: 'Focus report',
                subtitle: 'Where your focus time went.',
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: SoftButton(
                key: const Key('focus-report-back'),
                label: 'Back to the timer',
                icon: Icons.arrow_back,
                onPressed: widget.onBack,
              ),
            ),
          ],
        ),
        TileGrid(
          minWidth: 150,
          children: [
            StatTile(
              key: const Key('report-total'),
              label: 'Total focus time',
              value: formatWorked(totalSeconds(sessions)),
            ),
            StatTile(
              key: const Key('report-week'),
              label: 'Focus this week',
              value: formatWorked(
                totalSeconds(sessionsIn(sessions, weekRange)),
              ),
            ),
            StatTile(
              key: const Key('report-today'),
              label: 'Focus today',
              value: formatWorked(
                totalSeconds(sessionsIn(sessions, todayRange)),
              ),
            ),
            StatTile(
              key: const Key('report-done-total'),
              label: 'Tasks done in total',
              value: '${completedEver(tasks)}',
            ),
            StatTile(
              key: const Key('report-done-week'),
              label: 'Tasks done this week',
              value: '${completedIn(tasks, weekRange)}',
            ),
            StatTile(
              key: const Key('report-done-today'),
              label: 'Tasks done today',
              value: '${completedIn(tasks, todayRange)}',
            ),
          ],
        ),
        _Card(
          title: 'Focus records',
          icon: Icons.view_timeline_outlined,
          trailing: TextButton(
            key: const Key('report-records-more'),
            onPressed: () =>
                setState(() => _recordDays = _recordDays == 14 ? 60 : 14),
            child: Text(_recordDays == 14 ? 'Show 60 days' : 'Show 14 days'),
          ),
          child: _RecordsGrid(
            sessions: sessions,
            today: today,
            days: _recordDays,
            colorOf: (session) => swatchOfProject(
              projectOfSession(session, tasksById),
              projectsById,
            ).dot,
          ),
        ),
        // One period for the three charts below.
        Wrap(
          spacing: 10,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Segmented<FocusPeriod>(
              keyPrefix: 'report-period',
              value: _period,
              options: const [
                (FocusPeriod.day, 'Daily'),
                (FocusPeriod.week, 'Weekly'),
                (FocusPeriod.month, 'Monthly'),
                (FocusPeriod.year, 'Yearly'),
              ],
              onChanged: (value) => setState(() => _period = value),
            ),
            IconButton(
              key: const Key('report-prev'),
              tooltip: 'Earlier',
              onPressed: () => setState(
                () => _anchor = shiftFocusAnchor(_period, anchor, -1),
              ),
              icon: const Icon(Icons.chevron_left),
            ),
            Text(
              focusPeriodLabel(_period, anchor, today: today),
              key: const Key('report-period-label'),
              style: Ember.h3,
            ),
            IconButton(
              key: const Key('report-next'),
              tooltip: 'Later',
              onPressed: () => setState(
                () => _anchor = shiftFocusAnchor(_period, anchor, 1),
              ),
              icon: const Icon(Icons.chevron_right),
            ),
            if (_anchor != null && _anchor != today)
              SoftButton(
                key: const Key('report-today-button'),
                label: 'Today',
                onPressed: () => setState(() => _anchor = null),
              ),
          ],
        ),
        _TwoUp(
          left: _Card(
            title: 'Focus time',
            icon: Icons.bar_chart_rounded,
            trailing: Segmented<bool>(
              keyPrefix: 'report-by-task',
              value: _byTask,
              options: const [(false, 'Projects'), (true, 'Tasks')],
              onChanged: (value) => setState(() => _byTask = value),
            ),
            child: _ShareBars(
              total: totalSeconds(inPeriod),
              shares: [
                for (final entry in shares)
                  (
                    name: _byTask
                        ? taskName(entry.key)
                        : projectName(entry.key),
                    seconds: entry.value,
                    color: _byTask
                        ? swatchOfProject(
                            tasksById[entry.key]?.projectId,
                            projectsById,
                          ).dot
                        : swatchOfProject(entry.key, projectsById).dot,
                  ),
              ],
            ),
          ),
          right: _Card(
            title: 'Project share',
            icon: Icons.donut_large_rounded,
            child: _Donut(
              shares: [
                for (final entry in projectShares)
                  (
                    name: projectName(entry.key),
                    seconds: entry.value,
                    color: swatchOfProject(entry.key, projectsById).dot,
                  ),
              ],
            ),
          ),
        ),
        _TwoUp(
          left: _Card(
            title: 'Focus by day',
            icon: Icons.stacked_bar_chart_rounded,
            child: _StackedBars(
              buckets: chartBuckets(_period, anchor),
              sessions: sessions,
              today: today,
              tasks: tasksById,
              projects: projectsById,
            ),
          ),
          right: _Card(
            title: 'Focus goal',
            icon: Icons.flag_outlined,
            trailing: _GoalButton(goal: goal),
            child: _GoalCalendar(
              byDay: secondsByDay(sessions),
              month: _goalMonth ?? today,
              today: today,
              goal: goal,
              onShift: (step) => setState(
                () => _goalMonth = shiftFocusAnchor(
                  FocusPeriod.month,
                  _goalMonth ?? today,
                  step,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// A report card: a title row, then its content.
class _Card extends StatelessWidget {
  const _Card({
    required this.title,
    required this.icon,
    required this.child,
    this.trailing,
  });

  final String title;
  final IconData icon;
  final Widget child;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Tile(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SectionHeader(icon: icon, title: title, trailing: trailing),
          child,
        ],
      ),
    );
  }
}

/// Two cards side by side when there is room, one under the other when not.
class _TwoUp extends StatelessWidget {
  const _TwoUp({required this.left, required this.right});

  final Widget left;
  final Widget right;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 760) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [left, const SizedBox(height: 12), right],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(flex: 3, child: left),
            const SizedBox(width: 12),
            Expanded(flex: 2, child: right),
          ],
        );
      },
    );
  }
}

/// One row per day (newest first), 24 hours across, with a coloured block
/// for each session at its clock time.
class _RecordsGrid extends StatelessWidget {
  const _RecordsGrid({
    required this.sessions,
    required this.today,
    required this.days,
    required this.colorOf,
  });

  final List<FocusSession> sessions;
  final String today;
  final int days;
  final Color Function(FocusSession) colorOf;

  static const _labelWidth = 84.0;

  @override
  Widget build(BuildContext context) {
    String label(String day) {
      if (day == today) return 'Today';
      if (day == addDays(today, -1)) return 'Yesterday';
      return formatShortDay(day, today: today);
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth - _labelWidth;
        Widget gridLines() => Stack(
          children: [
            for (var hour = 0; hour <= 24; hour += 2)
              Positioned(
                left: width * hour / 24,
                top: 0,
                bottom: 0,
                child: Container(width: 1, color: Ember.line),
              ),
          ],
        );
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.only(left: _labelWidth),
              child: SizedBox(
                height: 16,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    for (var hour = 0; hour < 24; hour += 2)
                      Positioned(
                        left: width * hour / 24,
                        child: Text(
                          hour == 0 ? '0:00' : '$hour:00',
                          style: Ember.caption,
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 4),
            SizedBox(
              height: math.min(days, 14) * 22.0,
              child: ListView.builder(
                itemCount: days,
                itemExtent: 22,
                itemBuilder: (context, index) {
                  final day = addDays(today, -index);
                  final blocks = blocksOn(sessions, day);
                  return Row(
                    key: Key('report-row-$day'),
                    children: [
                      SizedBox(
                        width: _labelWidth,
                        child: Text(
                          label(day),
                          style: Ember.text(
                            12,
                            15,
                            weight: 400,
                            color: day == today ? Ember.nowInk : Ember.ink2,
                          ),
                        ),
                      ),
                      Expanded(
                        child: Stack(
                          children: [
                            Positioned.fill(child: gridLines()),
                            Positioned(
                              left: 0,
                              right: 0,
                              bottom: 0,
                              child: Container(height: 1, color: Ember.line),
                            ),
                            for (final block in blocks)
                              Positioned(
                                left: width * block.startMinute / 1440,
                                width: math.max(
                                  3,
                                  width *
                                      (block.endMinute - block.startMinute) /
                                      1440,
                                ),
                                top: 4,
                                bottom: 4,
                                child: Tooltip(
                                  message:
                                      '${clockOfMinute(block.startMinute)} · '
                                      '${formatWorked(block.session.focusSeconds)}',
                                  child: DecoratedBox(
                                    decoration: BoxDecoration(
                                      color: colorOf(block.session),
                                      borderRadius: BorderRadius.circular(3),
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }
}

typedef _Share = ({String name, int seconds, Color color});

/// "Total focus time" and one bar per project or task, longest first.
class _ShareBars extends StatelessWidget {
  const _ShareBars({required this.total, required this.shares});

  final int total;
  final List<_Share> shares;

  @override
  Widget build(BuildContext context) {
    if (shares.isEmpty) return const _NoData();
    final most = shares.first.seconds;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Total focus time: ${formatWorked(total)}',
          key: const Key('report-period-total'),
          style: Ember.meta,
        ),
        const SizedBox(height: 12),
        for (final share in shares.take(10))
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        share.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Ember.text(13, 16, color: Ember.ink),
                      ),
                    ),
                    Text(formatWorked(share.seconds), style: Ember.meta),
                  ],
                ),
                const SizedBox(height: 5),
                LayoutBuilder(
                  builder: (context, constraints) => Align(
                    alignment: Alignment.centerLeft,
                    child: Container(
                      height: 6,
                      width: math.max(
                        6,
                        constraints.maxWidth * share.seconds / most,
                      ),
                      decoration: BoxDecoration(
                        color: share.color,
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        if (shares.length > 10)
          Text('and ${shares.length - 10} more', style: Ember.caption),
      ],
    );
  }
}

/// A ring cut into each project's share, with a legend that names each
/// part (colours can repeat, so the names matter).
class _Donut extends StatelessWidget {
  const _Donut({required this.shares});

  final List<_Share> shares;

  @override
  Widget build(BuildContext context) {
    final total = shares.fold<int>(0, (sum, share) => sum + share.seconds);
    if (total == 0) return const _NoData();
    return Column(
      children: [
        SizedBox(
          width: 170,
          height: 170,
          child: Stack(
            alignment: Alignment.center,
            children: [
              CustomPaint(
                size: const Size(170, 170),
                painter: _DonutPainter(shares, total),
              ),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    formatWorked(total),
                    style: Ember.stat.copyWith(color: Ember.ink, fontSize: 22),
                  ),
                  Text('in total', style: Ember.caption),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        for (final share in shares)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(
              children: [
                ColorDot(share.color),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    share.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Ember.text(12, 15, color: Ember.ink),
                  ),
                ),
                Text(
                  '${(share.seconds * 100 / total).round()}% · '
                  '${formatWorked(share.seconds)}',
                  style: Ember.meta,
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _DonutPainter extends CustomPainter {
  _DonutPainter(this.shares, this.total);

  final List<_Share> shares;
  final int total;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromCircle(
      center: size.center(Offset.zero),
      radius: size.width / 2 - 12,
    );
    var start = -math.pi / 2;
    // A thin paper gap between parts, so equal colours stay apart.
    final gap = shares.length > 1 ? 0.03 : 0.0;
    for (final share in shares) {
      final sweep = 2 * math.pi * share.seconds / total;
      canvas.drawArc(
        rect,
        start + gap / 2,
        math.max(0.001, sweep - gap),
        false,
        Paint()
          ..color = share.color
          ..style = PaintingStyle.stroke
          ..strokeWidth = 22,
      );
      start += sweep;
    }
  }

  @override
  bool shouldRepaint(_DonutPainter old) =>
      old.total != total || old.shares != shares;
}

/// One bar per day (or month for a year), split by project.
class _StackedBars extends StatelessWidget {
  const _StackedBars({
    required this.buckets,
    required this.sessions,
    required this.today,
    required this.tasks,
    required this.projects,
  });

  final List<({String label, ({String start, String end}) range})> buckets;
  final List<FocusSession> sessions;
  final String today;
  final Map<String, Task> tasks;
  final Map<String, Project> projects;

  @override
  Widget build(BuildContext context) {
    final perBucket = [
      for (final bucket in buckets)
        secondsByProject(sessionsIn(sessions, bucket.range), tasks),
    ];
    final totals = [
      for (final parts in perBucket)
        parts.fold<int>(0, (sum, part) => sum + part.value),
    ];
    final most = totals.fold<int>(0, math.max);
    if (most == 0) return const _NoData();
    final legend = <String?>{
      for (final parts in perBucket) ...parts.map((part) => part.key),
    };
    const chartHeight = 150.0;
    final many = buckets.length > 12;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Most: ${formatWorked(most)}', style: Ember.caption),
        const SizedBox(height: 6),
        SizedBox(
          height: chartHeight + 18,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              for (var i = 0; i < buckets.length; i++)
                Expanded(
                  child: Tooltip(
                    message: '${buckets[i].label}: ${formatWorked(totals[i])}',
                    child: Padding(
                      padding: EdgeInsets.symmetric(horizontal: many ? 1 : 4),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          for (final part in perBucket[i].reversed)
                            Container(
                              height: chartHeight * part.value / most,
                              color: swatchOfProject(part.key, projects).dot,
                            ),
                          const SizedBox(height: 4),
                          SizedBox(
                            height: 14,
                            child: Text(
                              many && i % 5 != 0 ? '' : buckets[i].label,
                              maxLines: 1,
                              overflow: TextOverflow.clip,
                              style: Ember.text(
                                10,
                                13,
                                weight: 400,
                                color: inRange(today, buckets[i].range)
                                    ? Ember.nowInk
                                    : Ember.ink3,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 12,
          runSpacing: 6,
          children: [
            for (final project in legend)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ColorDot(swatchOfProject(project, projects).dot),
                  const SizedBox(width: 6),
                  Text(
                    projects[project]?.name ?? 'No project',
                    style: Ember.caption,
                  ),
                ],
              ),
          ],
        ),
      ],
    );
  }
}

/// "Goal: 4h" — opens a short list of goals to pick from.
class _GoalButton extends ConsumerWidget {
  const _GoalButton({required this.goal});

  final int goal;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return PopupMenuButton<int>(
      key: const Key('report-goal'),
      tooltip: 'Change the daily focus goal',
      initialValue: goal,
      onSelected: (minutes) async {
        final userId = ref.read(userIdProvider);
        if (userId == null) return;
        try {
          await ref
              .read(captureRepositoryProvider)
              .saveFocusGoal(userId: userId, minutes: minutes);
        } catch (error) {
          if (context.mounted) {
            showMessage(context, 'Could not save the goal. ($error)');
          }
        }
      },
      itemBuilder: (context) => [
        for (final minutes in focusGoalChoices)
          PopupMenuItem(
            key: Key('report-goal-$minutes'),
            value: minutes,
            child: Text('${formatWorked(minutes * 60)} a day'),
          ),
      ],
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: Ember.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Ember.line),
        ),
        child: Text(
          'Goal: ${formatWorked(goal * 60)}',
          style: Ember.text(12, 15, color: Ember.ink),
        ),
      ),
    );
  }
}

/// The month with a ring around each day that reached the goal and a small
/// dot under days with some focus.
class _GoalCalendar extends StatelessWidget {
  const _GoalCalendar({
    required this.byDay,
    required this.month,
    required this.today,
    required this.goal,
    required this.onShift,
  });

  final Map<String, int> byDay;
  final String month;
  final String today;
  final int goal;
  final ValueChanged<int> onShift;

  @override
  Widget build(BuildContext context) {
    final stats = focusGoalStats(byDay, month, goalMinutes: goal, today: today);
    final monthDate = parseDayKey(month)!;
    final days = monthGridDays(month);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Focus days: ${stats.focusDays} · Goal days: ${stats.goalDays} · '
          'Goal rate: ${stats.rate}%',
          key: const Key('report-goal-stats'),
          style: Ember.meta,
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            IconButton(
              key: const Key('report-goal-prev'),
              tooltip: 'Earlier month',
              visualDensity: VisualDensity.compact,
              onPressed: () => onShift(-1),
              icon: const Icon(Icons.chevron_left),
            ),
            Expanded(
              child: Text(
                '${monthNames[monthDate.month - 1].substring(0, 3)} '
                '${monthDate.year}',
                key: const Key('report-goal-month'),
                textAlign: TextAlign.center,
                style: Ember.h3,
              ),
            ),
            IconButton(
              key: const Key('report-goal-next'),
              tooltip: 'Later month',
              visualDensity: VisualDensity.compact,
              onPressed: () => onShift(1),
              icon: const Icon(Icons.chevron_right),
            ),
          ],
        ),
        const SizedBox(height: 4),
        GridView.count(
          crossAxisCount: 7,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          childAspectRatio: 1.15,
          children: [
            for (final name in weekdayShort)
              Center(child: Text(name.substring(0, 2), style: Ember.caption)),
            for (final day in days)
              _GoalDay(
                day: day,
                inMonth: parseDayKey(day)!.month == monthDate.month,
                isToday: day == today,
                seconds: byDay[day] ?? 0,
                reached: reachedGoal(byDay[day] ?? 0, goal),
              ),
          ],
        ),
      ],
    );
  }
}

class _GoalDay extends StatelessWidget {
  const _GoalDay({
    required this.day,
    required this.inMonth,
    required this.isToday,
    required this.seconds,
    required this.reached,
  });

  final String day;
  final bool inMonth;
  final bool isToday;
  final int seconds;
  final bool reached;

  @override
  Widget build(BuildContext context) {
    final number = parseDayKey(day)!.day;
    final color = isToday
        ? Ember.nowInk
        : inMonth
        ? Ember.ink
        : Ember.ink3;
    return Semantics(
      label:
          '${formatWeekDay(day)}: '
          '${seconds == 0 ? 'no focus' : formatWorked(seconds)}'
          '${reached ? ', goal reached' : ''}',
      child: Center(
        child: Container(
          key: Key('report-goal-day-$day'),
          width: 30,
          height: 30,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: reached ? Border.all(color: Ember.green, width: 2) : null,
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              Text(
                '$number',
                style: Ember.text(
                  12,
                  15,
                  weight: isToday ? 700 : 500,
                  color: color,
                ),
              ),
              if (seconds > 0 && !reached)
                Positioned(bottom: 2, child: ColorDot(Ember.ink3, size: 4)),
            ],
          ),
        ),
      ),
    );
  }
}

class _NoData extends StatelessWidget {
  const _NoData();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 28),
      child: Column(
        children: [
          const Icon(Icons.inventory_2_outlined, color: Ember.ink3, size: 28),
          const SizedBox(height: 6),
          Text('No focus in this period', style: Ember.meta),
        ],
      ),
    );
  }
}
