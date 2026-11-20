/// The rules behind the Sleep page, after the founder's Sleep log app:
/// week, month and year ranges, the numbers for a range, how far a night
/// was from the goal, and the changes against earlier periods. Plain
/// functions, so they are easy to test.
///
/// The targets are the wake-up time and bedtime from Settings; the goal is
/// the time between them (founder's choice).
library;

import 'dart:math' as math;

import '../data/local/app_database.dart';
import 'dates.dart';
import 'sleep.dart';

/// Week, month or year on the Sleep page.
enum SleepView { week, month, year }

/// The bedtime and wake time used when Settings has none.
const defaultBedTime = '23:00';
const defaultWakeTime = '07:00';

/// The tracking line starts at 3 PM and runs 24 hours, like the notebook
/// page of the Sleep log app.
const sleepAxisStart = 15 * 60;

/// Minutes after 3 PM of an `HH:MM` time, 0 to 1439.
int axisMinutes(String time) =>
    ((minutesOf(time) ?? 0) - sleepAxisStart) % 1440;

/// The clock time of a point on the 3 PM line: `11:30 PM`.
String axisClock(num axis) => formatTime(timeOf(axis.round() + sleepAxisStart));

/// The sleep goal in minutes: the time from the target bedtime to the
/// target wake time (8h by default).
int sleepGoal({String? bed, String? wake}) {
  final minutes = sleepMinutes(bed ?? defaultBedTime, wake ?? defaultWakeTime);
  return minutes == 0 ? 8 * 60 : minutes;
}

/// How far a night was from the goal: 0 goal met (green), 1 up to 1h short
/// (yellow), 2 up to 2h short (red), 3 more than 2h short (deep red).
int severity(int minutes, int goal) {
  final short = goal - minutes;
  if (short <= 0) return 0;
  if (short <= 60) return 1;
  if (short <= 120) return 2;
  return 3;
}

/// `goal met` or `1h 10m short`.
String goalGap(int minutes, int goal) {
  final short = goal - minutes;
  return short <= 0 ? 'goal met' : '${formatMinutes(short)} short';
}

/// The Monday of the week [day] is in.
String mondayOf(String day) => addDays(day, 1 - parseDayKey(day)!.weekday);

/// The first and last day of the week (Monday to Sunday), month or year
/// that [anchor] is in.
({String start, String end}) sleepRange(SleepView view, String anchor) {
  final date = parseDayKey(anchor)!;
  return switch (view) {
    SleepView.week => (
      start: mondayOf(anchor),
      end: addDays(mondayOf(anchor), 6),
    ),
    SleepView.month => (
      start: dayKey(DateTime(date.year, date.month)),
      end: dayKey(DateTime(date.year, date.month + 1, 0)),
    ),
    SleepView.year => (
      start: dayKey(DateTime(date.year)),
      end: dayKey(DateTime(date.year, 12, 31)),
    ),
  };
}

/// [anchor] moved one week, month or year back (-1) or forward (1).
String shiftSleepAnchor(SleepView view, String anchor, int step) {
  final date = parseDayKey(anchor)!;
  return switch (view) {
    SleepView.week => addDays(anchor, 7 * step),
    SleepView.month => dayKey(DateTime(date.year, date.month + step)),
    SleepView.year => dayKey(DateTime(date.year + step)),
  };
}

String _monthDay(DateTime date) =>
    '${monthNames[date.month - 1].substring(0, 3)} ${date.day}';

/// `Nov 16 to 22, 2026`, `Oct 26 to Nov 1, 2026`, `November 2026`, `2026`.
String sleepPeriodLabel(SleepView view, ({String start, String end}) range) {
  final start = parseDayKey(range.start)!;
  final end = parseDayKey(range.end)!;
  switch (view) {
    case SleepView.year:
      return '${start.year}';
    case SleepView.month:
      return '${monthNames[start.month - 1]} ${start.year}';
    case SleepView.week:
      if (start.year != end.year) {
        return '${_monthDay(start)}, ${start.year} to '
            '${_monthDay(end)}, ${end.year}';
      }
      if (start.month == end.month) {
        return '${_monthDay(start)} to ${end.day}, ${end.year}';
      }
      return '${_monthDay(start)} to ${_monthDay(end)}, ${end.year}';
  }
}

/// The nights filed under a morning inside [range].
List<SleepLog> nightsIn(
  List<SleepLog> nights,
  ({String start, String end}) range,
) => [
  for (final night in nights)
    if (night.day.compareTo(range.start) >= 0 &&
        night.day.compareTo(range.end) <= 0)
      night,
];

/// The numbers for some nights.
class SleepStats {
  const SleepStats({
    required this.count,
    required this.average,
    required this.atGoal,
    required this.bed,
    required this.wake,
    required this.spread,
    required this.shortest,
    required this.longest,
  });

  final int count;

  /// Average length, in minutes.
  final double average;

  /// Nights that reached the goal.
  final int atGoal;

  /// Average bedtime and wake time, as minutes after 3 PM.
  final double bed;
  final double wake;

  /// How much the bedtime moves from night to night (standard deviation,
  /// minutes): smaller is steadier.
  final double spread;
  final int shortest;
  final int longest;

  /// 0 to 1.
  double get rate => atGoal / count;
}

/// The numbers for [nights], or null when there are none.
SleepStats? sleepStats(Iterable<SleepLog> nights, int goal) {
  final list = nights.toList();
  if (list.isEmpty) return null;
  final lengths = [
    for (final night in list) sleepMinutes(night.bedTime, night.wakeTime),
  ];
  final beds = [for (final night in list) axisMinutes(night.bedTime)];
  final wakes = [for (final night in list) axisMinutes(night.wakeTime)];
  double mean(List<int> values) =>
      values.reduce((a, b) => a + b) / values.length;
  final bed = mean(beds);
  var variance = 0.0;
  for (final value in beds) {
    variance += (value - bed) * (value - bed);
  }
  return SleepStats(
    count: list.length,
    average: mean(lengths),
    atGoal: lengths.where((minutes) => minutes >= goal).length,
    bed: bed,
    wake: mean(wakes),
    spread: math.sqrt(variance / list.length),
    shortest: lengths.reduce(math.min),
    longest: lengths.reduce(math.max),
  );
}

/// Whether a change is good news, bad news, or no change.
enum Tone { good, bad, flat }

/// A change in average sleep: `Up 25m` (good) or `Down 1h` (bad).
({String text, Tone tone}) sleepChange(double current, double previous) {
  final diff = (current - previous).round();
  if (diff == 0) return (text: 'No change', tone: Tone.flat);
  return diff > 0
      ? (text: 'Up ${formatMinutes(diff)}', tone: Tone.good)
      : (text: 'Down ${formatMinutes(-diff)}', tone: Tone.bad);
}

/// A change in the share of nights at goal: `Up 12 points`.
({String text, Tone tone}) rateChange(double current, double previous) {
  final diff = ((current - previous) * 100).round();
  if (diff == 0) return (text: 'No change', tone: Tone.flat);
  return diff > 0
      ? (text: 'Up $diff points', tone: Tone.good)
      : (text: 'Down ${-diff} points', tone: Tone.bad);
}

/// A change in average bedtime or wake time: `20m earlier`. Closer to the
/// [target] (minutes after 3 PM) is good.
({String text, Tone tone}) timeChange(
  double current,
  double previous, {
  required int target,
}) {
  final diff = (current - previous).round();
  if (diff == 0) return (text: 'No change', tone: Tone.flat);
  final text = '${formatMinutes(diff.abs())} ${diff > 0 ? 'later' : 'earlier'}';
  final now = (current - target).abs();
  final before = (previous - target).abs();
  final tone = (now - before).abs() < 1
      ? Tone.flat
      : now < before
      ? Tone.good
      : Tone.bad;
  return (text: text, tone: tone);
}

/// The full week, month and year before the one [anchor] is in, for the
/// "Last week / Last month / Last year" comparisons.
List<(String, ({String start, String end}))> earlierRanges(String anchor) => [
  for (final (label, view) in const [
    ('Last week', SleepView.week),
    ('Last month', SleepView.month),
    ('Last year', SleepView.year),
  ])
    (label, sleepRange(view, shiftSleepAnchor(view, anchor, -1))),
];

/// The days of [range] that have started, newest first (today on top, no
/// future days).
List<String> trackedDays(({String start, String end}) range, String today) {
  final last = range.end.compareTo(today) < 0 ? range.end : today;
  return [
    for (
      var day = last;
      day.compareTo(range.start) >= 0;
      day = addDays(day, -1)
    )
      day,
  ];
}
