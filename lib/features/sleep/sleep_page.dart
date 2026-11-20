import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../data/local/app_database.dart';
import '../../domain/dates.dart';
import '../../domain/sleep.dart';
import '../../domain/sleep_view.dart';
import '../../ui/ember.dart';
import '../../ui/motion.dart';
import '../../ui/widgets.dart';

/// The status colours of the founder's Sleep log app: goal met, up to 1h
/// short, 1h to 2h short, over 2h short.
const _sevColors = [
  Color(0xFF2E9E5B),
  Color(0xFFF2C230),
  Color(0xFFE5484D),
  Color(0xFF8E1B21),
];
const _sevLabels = [
  'Goal met',
  'Up to 1h short',
  '1h to 2h short',
  'Over 2h short',
];

/// Text and background of good, bad and neutral changes.
const _goodInk = Color(0xFF23804A);
const _goodBg = Color(0xFFE3F5E9);
const _badInk = Color(0xFFC8242F);
const _badBg = Color(0xFFFDE8E8);

/// The Sleep page, after the founder's Sleep log app
/// (`F:\Neeret\sleep-tracker`): Week, Month and Year; four cards (average
/// sleep, bedtime, wake-up, nights at goal); the tracking list of nights
/// on a 3 PM to 3 PM line, coloured by how far each night was from the
/// goal; for a year, the months and every night. The form on the right
/// logs a night, or changes the one clicked.
///
/// The targets are the bedtime and wake-up time from Settings, and the goal
/// is the time between them (founder's choice).
class SleepPage extends ConsumerStatefulWidget {
  const SleepPage({super.key});

  @override
  ConsumerState<SleepPage> createState() => _SleepPageState();
}

class _SleepPageState extends ConsumerState<SleepPage> {
  var _view = SleepView.week;

  /// A day in the shown week, month or year; null follows today.
  String? _anchor;

  /// The morning clicked in the list, shown in the form; null for a new
  /// night this morning.
  String? _picked;

  @override
  Widget build(BuildContext context) {
    final nights = ref.watch(sleepLogsProvider).value ?? const <SleepLog>[];
    final times = ref.watch(dayTimesProvider).value;
    final bed = times?.bed ?? defaultBedTime;
    final wake = times?.wake ?? defaultWakeTime;
    final goal = sleepGoal(bed: bed, wake: wake);
    final today = dayKey(ref.watch(clockProvider)());
    final anchor = _anchor ?? today;
    final range = sleepRange(_view, anchor);
    final shown = nightsIn(nights, range);
    final current = sleepStats(shown, goal);
    final previous = sleepStats(
      nightsIn(nights, sleepRange(_view, shiftSleepAnchor(_view, anchor, -1))),
      goal,
    );
    final earlier = [
      for (final (label, earlierRange) in earlierRanges(anchor))
        (label, sleepStats(nightsIn(nights, earlierRange), goal)),
    ];
    final targets = (bed: axisMinutes(bed), wake: axisMinutes(wake));
    final byDay = {for (final night in nights) night.day: night};
    final showsToday =
        range.start.compareTo(today) <= 0 && range.end.compareTo(today) >= 0;
    final nextStart = sleepRange(
      _view,
      shiftSleepAnchor(_view, anchor, 1),
    ).start;
    final versus = 'vs last ${_view.name}';
    void pick(String day) =>
        setState(() => _picked = day == _picked ? null : day);

    return PageLayout(
      main: [
        Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 12,
          runSpacing: 10,
          children: [
            PageHeader(
              title: 'Sleep',
              subtitle: sleepPeriodLabel(_view, range),
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Segmented<String>(
                  keyPrefix: 'sleep-view',
                  value: _view.name,
                  options: const [
                    ('week', 'Week'),
                    ('month', 'Month'),
                    ('year', 'Year'),
                  ],
                  onChanged: (value) =>
                      setState(() => _view = SleepView.values.byName(value)),
                ),
                const SizedBox(width: 8),
                SoftButton(
                  key: const Key('sleep-today'),
                  label: 'Today',
                  onPressed: showsToday
                      ? null
                      : () => setState(() => _anchor = null),
                ),
                const SizedBox(width: 2),
                IconButton(
                  key: const Key('sleep-prev'),
                  tooltip: 'Previous ${_view.name}',
                  iconSize: 18,
                  visualDensity: VisualDensity.compact,
                  onPressed: () => setState(
                    () => _anchor = shiftSleepAnchor(_view, anchor, -1),
                  ),
                  icon: const Icon(Icons.chevron_left),
                ),
                IconButton(
                  key: const Key('sleep-next'),
                  tooltip: 'Next ${_view.name}',
                  iconSize: 18,
                  visualDensity: VisualDensity.compact,
                  onPressed: nextStart.compareTo(today) > 0
                      ? null
                      : () => setState(() {
                          final next = shiftSleepAnchor(_view, anchor, 1);
                          _anchor = next.compareTo(today) > 0 ? null : next;
                        }),
                  icon: const Icon(Icons.chevron_right),
                ),
              ],
            ),
          ],
        ),
        TileGrid(
          minWidth: 200,
          children: [
            _AverageCard(
              current: current,
              previous: previous,
              versus: versus,
              spark: _sparkValues(shown, range, today),
            ),
            _TimeCard(
              key: const Key('sleep-bedtime'),
              label: 'Average bedtime',
              value: current == null ? '—' : axisClock(current.bed),
              target: 'Target ${formatTime(bed)}',
              changes: [
                for (final (label, stats) in earlier)
                  (
                    label,
                    current == null || stats == null
                        ? null
                        : timeChange(
                            current.bed,
                            stats.bed,
                            target: targets.bed,
                          ),
                  ),
              ],
              extra: (
                'Bedtime consistency',
                current == null
                    ? '—'
                    : '±${formatMinutes(current.spread.round())}',
              ),
            ),
            _TimeCard(
              key: const Key('sleep-wakeup'),
              label: 'Average wake-up',
              value: current == null ? '—' : axisClock(current.wake),
              target: 'Target ${formatTime(wake)}',
              changes: [
                for (final (label, stats) in earlier)
                  (
                    label,
                    current == null || stats == null
                        ? null
                        : timeChange(
                            current.wake,
                            stats.wake,
                            target: targets.wake,
                          ),
                  ),
              ],
            ),
            _GoalCard(
              current: current,
              previous: previous,
              goal: goal,
              versus: versus,
            ),
          ],
        ),
        if (current == null)
          EmptyHint(
            title: 'No sleep logged this ${_view.name}',
            text:
                'Log a night on the right and it shows up here as a bar from '
                'bedtime to wake time.',
          )
        else if (_view == SleepView.year) ...[
          _MonthBars(nights: nights, year: range.start, goal: goal),
          _YearHeat(
            byDay: byDay,
            year: range.start,
            today: today,
            goal: goal,
            picked: _picked,
            onPick: pick,
          ),
        ] else
          _Tracking(
            days: trackedDays(range, today),
            byDay: byDay,
            today: today,
            goal: goal,
            targets: targets,
            compact: _view == SleepView.month,
            picked: _picked,
            onPick: pick,
          ),
      ],
      rail: [
        _NightForm(
          key: ValueKey(_picked ?? 'new'),
          day: _picked ?? today,
          picked: _picked != null,
          night: _picked == null ? null : byDay[_picked],
          nights: nights,
          today: today,
          bed: bed,
          wake: wake,
          goal: goal,
          onDone: () => setState(() => _picked = null),
        ),
      ],
    );
  }

  /// The small line on the dark card: each night of the range in order, or
  /// for a year each month's average.
  static List<double> _sparkValues(
    List<SleepLog> shown,
    ({String start, String end}) range,
    String today,
  ) {
    final sorted = [...shown]..sort((a, b) => a.day.compareTo(b.day));
    final start = parseDayKey(range.start)!;
    final end = parseDayKey(range.end)!;
    if (end.difference(start).inDays > 40) {
      return [
        for (var month = 1; month <= 12; month++)
          if (sleepStats(
                sorted.where((night) => parseDayKey(night.day)!.month == month),
                0,
              )
              case final stats?)
            stats.average,
      ];
    }
    return [
      for (final night in sorted)
        sleepMinutes(night.bedTime, night.wakeTime).toDouble(),
    ];
  }
}

/// A small coloured chip with a change in it.
class _Badge extends StatelessWidget {
  const _Badge(this.text, this.tone, {this.dark = false});

  final String text;
  final Tone tone;
  final bool dark;

  @override
  Widget build(BuildContext context) {
    final (background, ink) = switch (tone) {
      Tone.good => (_goodBg, _goodInk),
      Tone.bad => (_badBg, _badInk),
      Tone.flat =>
        dark ? (Ember.active, Ember.onShell2) : (Ember.neutral, Ember.ink2),
    };
    final icon = switch (tone) {
      Tone.flat => Icons.remove,
      _ => text.startsWith('Up') ? Icons.arrow_upward : Icons.arrow_downward,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (text != 'No nights logged' && !text.startsWith('No data')) ...[
            Icon(icon, size: 12, color: ink),
            const SizedBox(width: 3),
          ],
          Flexible(
            child: Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Ember.text(12, 15, weight: 600, color: ink),
            ),
          ),
        ],
      ),
    );
  }
}

/// A change against the period before, or why there is none.
Widget _delta(
  SleepStats? current,
  SleepStats? previous,
  ({String text, Tone tone}) Function(SleepStats, SleepStats) change, {
  required String versus,
  bool dark = false,
}) {
  if (current == null) return _Badge('No nights logged', Tone.flat, dark: dark);
  if (previous == null) {
    return _Badge(
      'No data ${versus.replaceFirst('vs ', 'for ')}',
      Tone.flat,
      dark: dark,
    );
  }
  final result = change(current, previous);
  return Wrap(
    spacing: 6,
    runSpacing: 4,
    crossAxisAlignment: WrapCrossAlignment.center,
    children: [
      _Badge(result.text, result.tone, dark: dark),
      Text(
        versus,
        style: Ember.meta.copyWith(color: dark ? Ember.onShell2 : null),
      ),
    ],
  );
}

/// The dark card: average sleep, its change, and a small line of nights.
class _AverageCard extends StatelessWidget {
  const _AverageCard({
    required this.current,
    required this.previous,
    required this.versus,
    required this.spark,
  });

  final SleepStats? current;
  final SleepStats? previous;
  final String versus;
  final List<double> spark;

  @override
  Widget build(BuildContext context) {
    final current = this.current;
    return Tile(
      key: const Key('sleep-average'),
      color: Ember.chart,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Average sleep',
            style: Ember.meta.copyWith(color: Ember.onShell2),
          ),
          const SizedBox(height: 6),
          Text(
            current == null ? '—' : formatMinutes(current.average.round()),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Ember.stat.copyWith(
              color: Ember.onShell,
              fontSize: 34,
              height: 40 / 34,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            current == null
                ? 'Nothing logged yet'
                : 'across ${countOf(current.count, 'night')}',
            style: Ember.meta.copyWith(color: Ember.onShell2),
          ),
          const SizedBox(height: 10),
          _delta(
            current,
            previous,
            (a, b) => sleepChange(a.average, b.average),
            versus: versus,
            dark: true,
          ),
          if (spark.length >= 2) ...[
            const SizedBox(height: 12),
            SizedBox(
              height: 44,
              width: double.infinity,
              child: CustomPaint(painter: _SparkPainter(spark)),
            ),
          ],
        ],
      ),
    );
  }
}

class _SparkPainter extends CustomPainter {
  _SparkPainter(this.values);

  final List<double> values;

  @override
  void paint(Canvas canvas, Size size) {
    final low = values.reduce(math.min);
    final high = values.reduce(math.max);
    final span = math.max(high - low, 60);
    Offset at(int i) => Offset(
      4 + i / (values.length - 1) * (size.width - 8),
      size.height - 4 - (values[i] - low) / span * (size.height - 8),
    );
    final line = Path()..moveTo(at(0).dx, at(0).dy);
    for (var i = 1; i < values.length; i++) {
      line.lineTo(at(i).dx, at(i).dy);
    }
    final fill = Path.from(line)
      ..lineTo(at(values.length - 1).dx, size.height)
      ..lineTo(at(0).dx, size.height)
      ..close();
    canvas.drawPath(
      fill,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Ember.onShell.withValues(alpha: 0.18),
            Ember.onShell.withValues(alpha: 0),
          ],
        ).createShader(Offset.zero & size),
    );
    canvas.drawPath(
      line,
      Paint()
        ..color = Ember.onShell2
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
    // The latest night is the one that is "now".
    canvas.drawCircle(at(values.length - 1), 3.5, Paint()..color = Ember.now);
  }

  @override
  bool shouldRepaint(_SparkPainter old) => old.values != values;
}

/// Average bedtime or wake-up, its target, and how it moved against the
/// last week, month and year.
class _TimeCard extends StatelessWidget {
  const _TimeCard({
    super.key,
    required this.label,
    required this.value,
    required this.target,
    required this.changes,
    this.extra,
  });

  final String label;
  final String value;
  final String target;
  final List<(String, ({String text, Tone tone})?)> changes;
  final (String, String)? extra;

  @override
  Widget build(BuildContext context) {
    final extra = this.extra;
    return Tile(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: Ember.meta),
          const SizedBox(height: 6),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Ember.stat.copyWith(color: Ember.ink),
          ),
          const SizedBox(height: 4),
          Text(target, style: Ember.meta),
          const SizedBox(height: 10),
          for (final (period, change) in changes)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                children: [
                  Expanded(child: Text(period, style: Ember.meta)),
                  if (change == null)
                    Text('No data', style: Ember.caption)
                  else
                    Text(
                      change.text,
                      style: Ember.text(
                        12,
                        15,
                        weight: 600,
                        color: switch (change.tone) {
                          Tone.good => _goodInk,
                          Tone.bad => _badInk,
                          Tone.flat => Ember.ink2,
                        },
                      ),
                    ),
                ],
              ),
            ),
          if (extra != null) ...[
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              decoration: BoxDecoration(
                color: Ember.neutral,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Expanded(child: Text(extra.$1, style: Ember.meta)),
                  Text(
                    extra.$2,
                    style: Ember.text(12, 15, weight: 600, color: Ember.ink),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Nights at goal: how many, a bar, and the change.
class _GoalCard extends StatelessWidget {
  const _GoalCard({
    required this.current,
    required this.previous,
    required this.goal,
    required this.versus,
  });

  final SleepStats? current;
  final SleepStats? previous;
  final int goal;
  final String versus;

  @override
  Widget build(BuildContext context) {
    final current = this.current;
    return Tile(
      key: const Key('sleep-goal'),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Nights at goal', style: Ember.meta),
          const SizedBox(height: 6),
          Text(
            current == null ? '—' : '${current.atGoal} of ${current.count}',
            style: Ember.stat.copyWith(color: Ember.ink),
          ),
          const SizedBox(height: 4),
          Text('Goal is ${formatMinutes(goal)} or more', style: Ember.meta),
          if (current != null) ...[
            const SizedBox(height: 10),
            ProgressBar((current.rate * 100).round()),
          ],
          const SizedBox(height: 10),
          _delta(
            current,
            previous,
            (a, b) => rateChange(a.rate, b.rate),
            versus: versus,
          ),
        ],
      ),
    );
  }
}

/// The colour key of the charts.
class _Legend extends StatelessWidget {
  const _Legend({this.target = false, this.noData = false});

  final bool target;
  final bool noData;

  @override
  Widget build(BuildContext context) {
    Widget key(Widget mark, String label) => Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        mark,
        const SizedBox(width: 6),
        Text(label, style: Ember.meta),
      ],
    );
    Widget swatch(Color color) => Container(
      width: 10,
      height: 10,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(3),
      ),
    );
    return Wrap(
      spacing: 12,
      runSpacing: 4,
      children: [
        for (var i = 0; i < 4; i++) key(swatch(_sevColors[i]), _sevLabels[i]),
        if (target)
          key(
            Container(width: 2, height: 12, color: Ember.ink2),
            'Target times',
          ),
        if (noData) key(swatch(Ember.neutral), 'No data'),
      ],
    );
  }
}

/// The tracking list: one row per morning, newest first. The bar runs from
/// bedtime to wake time on a line from 3 PM to 3 PM; the dashed lines are
/// the target times. Clicking a row opens that night in the form.
class _Tracking extends StatelessWidget {
  const _Tracking({
    required this.days,
    required this.byDay,
    required this.today,
    required this.goal,
    required this.targets,
    required this.compact,
    required this.picked,
    required this.onPick,
  });

  final List<String> days;
  final Map<String, SleepLog> byDay;
  final String today;
  final int goal;
  final ({int bed, int wake}) targets;
  final bool compact;
  final String? picked;
  final ValueChanged<String> onPick;

  static const _ticks = [
    '3 PM',
    '6 PM',
    '9 PM',
    '12 AM',
    '3 AM',
    '6 AM',
    '9 AM',
    '12 PM',
    '3 PM',
  ];

  @override
  Widget build(BuildContext context) {
    final dayWidth = compact ? 32.0 : 60.0;
    final durationWidth = compact ? 64.0 : 72.0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SectionHeader(
          icon: Icons.bedtime_outlined,
          title: 'Tracking',
          trailing: _Legend(target: true),
        ),
        Tile(
          padding: const EdgeInsets.fromLTRB(12, 14, 12, 12),
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: 1),
            duration: Motion.of(context, Motion.slow),
            curve: Motion.soft,
            builder: (context, grow, _) => Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    SizedBox(width: dayWidth),
                    Expanded(
                      child: SizedBox(
                        height: 16,
                        child: CustomPaint(painter: _TicksPainter(_ticks)),
                      ),
                    ),
                    SizedBox(width: durationWidth),
                  ],
                ),
                const SizedBox(height: 8),
                for (final day in days)
                  _TrackRow(
                    day: day,
                    night: byDay[day],
                    today: today,
                    goal: goal,
                    targets: targets,
                    compact: compact,
                    dayWidth: dayWidth,
                    durationWidth: durationWidth,
                    grow: grow,
                    selected: day == picked,
                    onTap: () => onPick(day),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Newest night first. Warmer colours are further from your goal. '
          'Click a night to change it. Targets come from Settings.',
          style: Ember.meta,
        ),
      ],
    );
  }
}

class _TrackRow extends StatelessWidget {
  const _TrackRow({
    required this.day,
    required this.night,
    required this.today,
    required this.goal,
    required this.targets,
    required this.compact,
    required this.dayWidth,
    required this.durationWidth,
    required this.grow,
    required this.selected,
    required this.onTap,
  });

  final String day;
  final SleepLog? night;
  final String today;
  final int goal;
  final ({int bed, int wake}) targets;
  final bool compact;
  final double dayWidth;
  final double durationWidth;
  final double grow;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final night = this.night;
    final date = parseDayKey(day)!;
    final isToday = day == today;
    final minutes = night == null
        ? null
        : sleepMinutes(night.bedTime, night.wakeTime);
    final words = formatWeekDay(day);
    final tip = night == null
        ? '$words, no sleep logged'
        : '$words, ${formatTime(night.bedTime)} to '
              '${formatTime(night.wakeTime)}, ${formatMinutes(minutes!)}, '
              '${goalGap(minutes, goal)}';
    return Tooltip(
      message: tip,
      waitDuration: const Duration(milliseconds: 400),
      child: Material(
        color: selected ? Ember.neutral : Colors.transparent,
        borderRadius: BorderRadius.circular(6),
        child: InkWell(
          key: Key('night-$day'),
          borderRadius: BorderRadius.circular(6),
          onTap: onTap,
          child: SizedBox(
            height: compact ? 24 : 44,
            child: Row(
              children: [
                SizedBox(
                  width: dayWidth,
                  child: Padding(
                    padding: const EdgeInsets.only(right: 10),
                    child: Text(
                      compact
                          ? '${date.day}'
                          : '${weekdayShort[date.weekday - 1]} ${date.day}',
                      textAlign: TextAlign.right,
                      maxLines: 1,
                      style: Ember.text(
                        12,
                        15,
                        weight: isToday ? 600 : 400,
                        // Today is live, so it takes the "now" colour.
                        color: isToday ? Ember.nowInk : Ember.ink2,
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: CustomPaint(
                    size: Size.infinite,
                    painter: _TrackPainter(
                      start: night == null ? null : axisMinutes(night.bedTime),
                      length: minutes,
                      color: minutes == null
                          ? null
                          : _sevColors[severity(minutes, goal)],
                      targets: targets,
                      barHeight: compact ? 12 : 24,
                      grow: grow,
                    ),
                  ),
                ),
                SizedBox(
                  width: durationWidth,
                  child: Padding(
                    padding: const EdgeInsets.only(left: 10),
                    child: Text(
                      minutes == null ? '—' : formatMinutes(minutes),
                      maxLines: 1,
                      style: minutes == null
                          ? Ember.text(12, 15, weight: 400, color: Ember.ink3)
                          : Ember.text(12, 15, weight: 600, color: Ember.ink),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The hour labels over the tracking list.
class _TicksPainter extends CustomPainter {
  _TicksPainter(this.ticks);

  final List<String> ticks;

  @override
  void paint(Canvas canvas, Size size) {
    for (var i = 0; i < ticks.length; i++) {
      final painter = TextPainter(
        text: TextSpan(
          text: ticks[i],
          style: Ember.text(11, 13, color: Ember.ink2),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      final x = (size.width * i / (ticks.length - 1) - painter.width / 2).clamp(
        0.0,
        math.max(0.0, size.width - painter.width),
      );
      painter.paint(canvas, Offset(x.toDouble(), 0));
    }
  }

  @override
  bool shouldRepaint(_TicksPainter old) => false;
}

/// One row's track: grid lines every 3 hours, the dashed target lines, and
/// the night's bar.
class _TrackPainter extends CustomPainter {
  _TrackPainter({
    required this.start,
    required this.length,
    required this.color,
    required this.targets,
    required this.barHeight,
    required this.grow,
  });

  final int? start;
  final int? length;
  final Color? color;
  final ({int bed, int wake}) targets;
  final double barHeight;
  final double grow;

  @override
  void paint(Canvas canvas, Size size) {
    final grid = Paint()
      ..color = Ember.line
      ..strokeWidth = 1;
    for (var i = 0; i <= 8; i++) {
      final x = math.min(size.width - 0.5, size.width * i / 8);
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), grid);
    }
    canvas.drawLine(
      Offset(0, size.height - 0.5),
      Offset(size.width, size.height - 0.5),
      grid,
    );

    final start = this.start;
    final length = this.length;
    if (start != null && length != null && color != null) {
      final left = size.width * start / 1440;
      final right = size.width * math.min(start + length, 1440) / 1440;
      final width = math.max(2.0, (right - left) * grow);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(left, (size.height - barHeight) / 2, width, barHeight),
          Radius.circular(barHeight >= 20 ? 6 : 4),
        ),
        Paint()..color = color!,
      );
    }

    final dash = Paint()
      ..color = Ember.ink2
      ..strokeWidth = 1.5;
    for (final target in [targets.bed, targets.wake]) {
      final x = size.width * target / 1440;
      for (var y = 0.0; y < size.height; y += 6) {
        canvas.drawLine(
          Offset(x, y),
          Offset(x, math.min(y + 3, size.height)),
          dash,
        );
      }
    }
  }

  @override
  bool shouldRepaint(_TrackPainter old) =>
      old.start != start ||
      old.length != length ||
      old.color != color ||
      old.targets != targets ||
      old.grow != grow;
}

/// Year view: average sleep for each month, with the goal as a dashed line.
class _MonthBars extends StatelessWidget {
  const _MonthBars({
    required this.nights,
    required this.year,
    required this.goal,
  });

  final List<SleepLog> nights;
  final String year;
  final int goal;

  @override
  Widget build(BuildContext context) {
    final y = parseDayKey(year)!.year;
    final averages = [
      for (var month = 1; month <= 12; month++)
        sleepStats(
          nightsIn(nights, (
            start: dayKey(DateTime(y, month)),
            end: dayKey(DateTime(y, month + 1, 0)),
          )),
          goal,
        )?.average,
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SectionHeader(
          icon: Icons.bar_chart,
          title: 'Average sleep by month',
          trailing: _Legend(),
        ),
        Tile(
          padding: const EdgeInsets.fromLTRB(12, 16, 12, 10),
          child: SizedBox(
            height: 220,
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: 1),
              duration: Motion.of(context, Motion.slow),
              curve: Motion.soft,
              builder: (context, grow, _) => CustomPaint(
                size: Size.infinite,
                painter: _MonthBarsPainter(
                  averages: averages,
                  goal: goal,
                  grow: grow,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _MonthBarsPainter extends CustomPainter {
  _MonthBarsPainter({
    required this.averages,
    required this.goal,
    required this.grow,
  });

  final List<double?> averages;
  final int goal;
  final double grow;

  void _label(
    Canvas canvas,
    String text,
    Offset center, {
    Color? color,
    bool boxed = false,
  }) {
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: Ember.text(11, 13, color: color ?? Ember.ink2),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    if (boxed) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(
            center: center,
            width: painter.width + 6,
            height: painter.height + 2,
          ),
          const Radius.circular(3),
        ),
        Paint()..color = Ember.tile,
      );
    }
    painter.paint(
      canvas,
      Offset(center.dx - painter.width / 2, center.dy - painter.height / 2),
    );
  }

  @override
  void paint(Canvas canvas, Size size) {
    const top = 18.0;
    const bottom = 20.0;
    final chart = size.height - top - bottom;
    final highest = averages.whereType<double>().fold<double>(
      goal.toDouble(),
      math.max,
    );
    final scale = math.max(600.0, (highest / 60).ceil() * 60 + 60.0);
    double yOf(double minutes) => top + chart * (1 - minutes / scale);
    // The goal line goes under the bars and their numbers.
    final goalY = yOf(goal.toDouble());
    final dash = Paint()
      ..color = Ember.ink2
      ..strokeWidth = 1.5;
    for (var x = 0.0; x < size.width; x += 8) {
      canvas.drawLine(
        Offset(x, goalY),
        Offset(math.min(x + 4, size.width), goalY),
        dash,
      );
    }
    final slot = size.width / 12;
    final barWidth = math.min(28.0, slot * 0.6);
    for (var i = 0; i < 12; i++) {
      final center = slot * (i + 0.5);
      _label(
        canvas,
        monthNames[i].substring(0, 3),
        Offset(center, size.height - bottom / 2),
      );
      final average = averages[i];
      if (average == null) {
        _label(canvas, '—', Offset(center, top + chart - 8), color: Ember.ink3);
        continue;
      }
      final barTop = yOf(average * grow);
      canvas.drawRRect(
        RRect.fromRectAndCorners(
          Rect.fromLTRB(
            center - barWidth / 2,
            barTop,
            center + barWidth / 2,
            top + chart,
          ),
          topLeft: const Radius.circular(5),
          topRight: const Radius.circular(5),
        ),
        Paint()..color = _sevColors[severity(average.round(), goal)],
      );
      _label(
        canvas,
        formatMinutes(average.round()),
        Offset(center, barTop - 9),
        color: Ember.ink,
        boxed: true,
      );
    }
  }

  @override
  bool shouldRepaint(_MonthBarsPainter old) =>
      old.averages != averages || old.goal != goal || old.grow != grow;
}

/// Year view: every night as a small square, a column per week (Monday on
/// top), coloured by how far it was from the goal. Today has an orange
/// ring. Clicking a day opens it in the form.
class _YearHeat extends StatelessWidget {
  const _YearHeat({
    required this.byDay,
    required this.year,
    required this.today,
    required this.goal,
    required this.picked,
    required this.onPick,
  });

  final Map<String, SleepLog> byDay;
  final String year;
  final String today;
  final int goal;
  final String? picked;
  final ValueChanged<String> onPick;

  static const _cell = 14.0;
  static const _gap = 4.0;

  @override
  Widget build(BuildContext context) {
    final y = parseDayKey(year)!.year;
    final first = mondayOf(dayKey(DateTime(y)));
    final last = dayKey(DateTime(y, 12, 31));
    final weeks = <List<String>>[];
    for (
      var monday = first;
      monday.compareTo(last) <= 0;
      monday = addDays(monday, 7)
    ) {
      weeks.add([for (var i = 0; i < 7; i++) addDays(monday, i)]);
    }
    String? monthStarting(List<String> week) {
      for (final day in week) {
        final date = parseDayKey(day)!;
        if (date.year == y && date.day == 1) {
          return monthNames[date.month - 1].substring(0, 3);
        }
      }
      return null;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SectionHeader(
          icon: Icons.grid_view,
          title: 'Every night',
          trailing: _Legend(noData: true),
        ),
        Tile(
          padding: const EdgeInsets.all(14),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final week in weeks)
                  Padding(
                    padding: const EdgeInsets.only(right: _gap),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(
                          width: _cell,
                          height: 18,
                          child: OverflowBox(
                            alignment: Alignment.topLeft,
                            maxWidth: 40,
                            child: Text(
                              monthStarting(week) ?? '',
                              style: Ember.caption,
                            ),
                          ),
                        ),
                        for (final day in week) ...[
                          _HeatCell(
                            day: day,
                            inYear: parseDayKey(day)!.year == y,
                            night: byDay[day],
                            today: today,
                            goal: goal,
                            selected: day == picked,
                            onTap: () => onPick(day),
                          ),
                          const SizedBox(height: _gap),
                        ],
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _HeatCell extends StatelessWidget {
  const _HeatCell({
    required this.day,
    required this.inYear,
    required this.night,
    required this.today,
    required this.goal,
    required this.selected,
    required this.onTap,
  });

  final String day;
  final bool inYear;
  final SleepLog? night;
  final String today;
  final int goal;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    const size = _YearHeat._cell;
    if (!inYear) return const SizedBox(width: size, height: size);
    final night = this.night;
    final future = day.compareTo(today) > 0;
    final minutes = night == null
        ? null
        : sleepMinutes(night.bedTime, night.wakeTime);
    final words = formatWeekDay(day);
    final tip = minutes == null
        ? '$words, nothing logged'
        : '$words, ${formatMinutes(minutes)}, ${goalGap(minutes, goal)}';
    final box = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: minutes == null || future
            ? Ember.neutral
            : _sevColors[severity(minutes, goal)],
        borderRadius: BorderRadius.circular(3),
        border: day == today
            ? Border.all(color: Ember.now, width: 2)
            : selected
            ? Border.all(color: Ember.ink, width: 2)
            : null,
      ),
    );
    if (future) return box;
    return Tooltip(
      message: tip,
      waitDuration: const Duration(milliseconds: 300),
      child: InkWell(
        key: Key('sleep-cell-$day'),
        borderRadius: BorderRadius.circular(3),
        onTap: onTap,
        child: box,
      ),
    );
  }
}

/// The form on the right: log a night, or change the one clicked in the
/// list. A new night starts at the target times from Settings.
class _NightForm extends ConsumerStatefulWidget {
  const _NightForm({
    super.key,
    required this.day,
    required this.picked,
    required this.night,
    required this.nights,
    required this.today,
    required this.bed,
    required this.wake,
    required this.goal,
    required this.onDone,
  });

  /// The morning shown: the one clicked, or today.
  final String day;

  /// True when a day was clicked in the list (the form can be closed).
  final bool picked;

  /// The night being changed, or null for a new one.
  final SleepLog? night;
  final List<SleepLog> nights;
  final String today;

  /// The target bedtime and wake time, and the goal in minutes.
  final String bed;
  final String wake;
  final int goal;
  final VoidCallback onDone;

  @override
  ConsumerState<_NightForm> createState() => _NightFormState();
}

class _NightFormState extends ConsumerState<_NightForm> {
  late String _day = widget.night?.day ?? widget.day;
  late String _bed = widget.night?.bedTime ?? widget.bed;
  late String _wake = widget.night?.wakeTime ?? widget.wake;
  late String? _rested = widget.night?.rested;
  late final _note = TextEditingController(text: widget.night?.note ?? '');

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  Future<void> _pickDay() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: parseDayKey(_day)!,
      firstDate: DateTime(2020),
      lastDate: parseDayKey(widget.today)!,
      helpText: 'The morning you woke up',
    );
    if (picked != null && mounted) setState(() => _day = dayKey(picked));
  }

  Future<void> _pickTime({required bool bed}) async {
    final minutes = minutesOf(bed ? _bed : _wake) ?? 0;
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: minutes ~/ 60, minute: minutes % 60),
      helpText: bed ? 'Bedtime' : 'Woke up',
    );
    if (picked == null || !mounted) return;
    final value = timeOf(picked.hour * 60 + picked.minute);
    setState(() => bed ? _bed = value : _wake = value);
  }

  Future<void> _save() async {
    final userId = ref.read(userIdProvider);
    if (userId == null) return;
    final minutes = sleepMinutes(_bed, _wake);
    if (needsCheck(minutes)) {
      final keep = await confirmDialog(
        context,
        title: 'Check the times',
        message:
            'This night is ${formatMinutes(minutes)} long. Are the bedtime '
            'and the wake time right?',
        confirmLabel: 'Save anyway',
        cancelLabel: 'Go back',
      );
      if (!keep || !mounted) return;
    }
    try {
      await ref
          .read(sleepRepositoryProvider)
          .saveNight(
            userId: userId,
            day: _day,
            bedTime: _bed,
            wakeTime: _wake,
            rested: _rested,
            note: _note.text,
          );
      if (!mounted) return;
      showMessage(context, 'Night saved.');
      widget.onDone();
    } catch (error) {
      if (mounted) showMessage(context, 'Could not save. Try again. ($error)');
    }
  }

  Future<void> _delete() async {
    final night = widget.night!;
    final confirmed = await confirmDialog(
      context,
      title: 'Delete this night?',
      message: 'The night of ${formatWeekDay(night.day)} is removed.',
      confirmLabel: 'Delete',
    );
    if (!confirmed) return;
    try {
      await ref.read(sleepRepositoryProvider).deleteNight(night.id);
      widget.onDone();
    } catch (error) {
      if (mounted) showMessage(context, 'Could not delete. ($error)');
    }
  }

  @override
  Widget build(BuildContext context) {
    final editing = widget.night != null;
    final minutes = sleepMinutes(_bed, _wake);
    final replaces =
        !editing && widget.nights.any((night) => night.day == _day);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Icon(editing ? Icons.edit_outlined : Icons.add, size: 16),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                editing ? 'Change a night' : 'Log a night',
                style: Ember.h2,
              ),
            ),
            if (editing || widget.picked)
              IconButton(
                tooltip: 'Close',
                iconSize: 16,
                visualDensity: VisualDensity.compact,
                onPressed: widget.onDone,
                icon: const Icon(Icons.close),
              ),
          ],
        ),
        const SizedBox(height: 14),
        const FieldLabel('Night of'),
        OutlinedButton.icon(
          key: const Key('sleep-day'),
          onPressed: editing ? null : _pickDay,
          icon: const Icon(Icons.event_outlined, size: 16),
          label: Text(
            '${formatWeekDay(addDays(_day, -1))} → ${formatWeekDay(_day)}',
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const FieldLabel('Bedtime'),
                  OutlinedButton(
                    key: const Key('sleep-bed'),
                    onPressed: () => _pickTime(bed: true),
                    child: Text(formatTime(_bed)),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const FieldLabel('Woke up'),
                  OutlinedButton(
                    key: const Key('sleep-wake'),
                    onPressed: () => _pickTime(bed: false),
                    child: Text(formatTime(_wake)),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        AnimatedContainer(
          duration: Motion.of(context, Motion.base),
          curve: Motion.soft,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: Ember.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: needsCheck(minutes) ? Ember.amber : Ember.line,
            ),
          ),
          child: Row(
            children: [
              Text('Duration', style: Ember.meta),
              const Spacer(),
              Text(
                formatMinutes(minutes),
                key: const Key('sleep-duration'),
                style: Ember.text(13, 16, weight: 600, color: Ember.ink),
              ),
            ],
          ),
        ),
        if (!needsCheck(minutes)) ...[
          const SizedBox(height: 6),
          Text(
            goalGap(minutes, widget.goal).replaceFirst('g', 'G'),
            style: Ember.meta,
          ),
        ],
        if (needsCheck(minutes)) ...[
          const SizedBox(height: 6),
          Text(
            'Check the times: a night this long is unusual.',
            style: Ember.meta.copyWith(color: Ember.amberInk),
          ),
        ],
        const SizedBox(height: 12),
        const FieldLabel('How rested? Optional'),
        Segmented<String?>(
          keyPrefix: 'sleep-rested',
          expand: true,
          value: _rested,
          options: const [
            ('poor', 'Poor'),
            ('okay', 'Okay'),
            ('good', 'Good'),
            ('great', 'Great'),
          ],
          // Tapping the chosen one again clears it.
          onChanged: (value) =>
              setState(() => _rested = value == _rested ? null : value),
        ),
        const SizedBox(height: 12),
        const FieldLabel('Note · optional'),
        TextField(
          key: const Key('sleep-note'),
          controller: _note,
          minLines: 2,
          maxLines: 4,
          decoration: const InputDecoration(
            hintText: 'Late coffee, noise, travel…',
          ),
        ),
        const SizedBox(height: 16),
        FilledButton(
          key: const Key('sleep-save'),
          onPressed: _save,
          child: Text(editing ? 'Save' : 'Save night'),
        ),
        const SizedBox(height: 8),
        Text(
          replaces
              ? 'This morning already has a night. Saving replaces it.'
              : 'Saving a night for a date that already has one replaces it.',
          style: Ember.caption,
        ),
        if (editing) ...[
          const SizedBox(height: 6),
          TextButton.icon(
            key: const Key('sleep-delete'),
            onPressed: _delete,
            icon: const Icon(Icons.delete_outline, size: 16),
            label: const Text('Delete night'),
          ),
        ],
      ],
    );
  }
}
