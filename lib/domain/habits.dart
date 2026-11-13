/// The rules for habits: which days count, what each day shows, and the
/// numbers on the Habits page. Plain functions, so they are easy to test.
///
/// The wording rule: a missed day is data, not a failure. There are no
/// streaks: the page shows how many planned days were kept, never a run of
/// days that can be "broken".
library;

import '../data/local/app_database.dart';
import 'dates.dart';

/// Monday = 1 ... Sunday = 7, as stored in `habits.days`.
const allDays = '1234567';

/// The short names of the weekdays, Monday first, for the day picker.
const dayLetters = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];

/// The weekday number (Monday = 1) of a day key.
int weekdayOf(String day) => parseDayKey(day)!.weekday;

/// True when [habit] is planned on [day].
bool isPlanned(Habit habit, String day) =>
    habit.days.contains('${weekdayOf(day)}');

/// The days a habit is planned on, in plain words: "Every day", "Weekdays",
/// or "Mon, Wed, Fri".
String describeDays(String days) {
  final sorted = (days.split('').toSet().toList()..sort()).join();
  if (sorted == allDays) return 'Every day';
  if (sorted == '12345') return 'Weekdays';
  if (sorted == '67') return 'Weekends';
  if (sorted.isEmpty) return 'No days';
  return [
    for (final digit in sorted.split('')) weekdayShort[int.parse(digit) - 1],
  ].join(', ');
}

/// What one day of one habit shows.
enum HabitDay {
  /// Marked done.
  done,

  /// Skipped on purpose (a planned rest day). Does not count against it.
  skipped,

  /// A past planned day that was not marked.
  missed,

  /// Today, planned and not marked yet.
  open,

  /// Not a planned day, or before the habit existed, or in the future.
  off,
}

/// The marks of one habit, by day.
Map<String, String> marksOf(String habitId, List<HabitLog> logs) => {
  for (final log in logs)
    if (log.habitId == habitId) log.day: log.status,
};

/// The day the habit was created, in the device's time zone.
String createdDay(Habit habit) =>
    dayKeyOfStoredTime(habit.createdAt) ?? '0000-01-01';

/// What [day] shows for [habit].
HabitDay dayState(
  Habit habit,
  Map<String, String> marks,
  String day, {
  required String today,
}) {
  final mark = marks[day];
  if (mark == HabitMark.done) return HabitDay.done;
  if (mark == HabitMark.skip) return HabitDay.skipped;
  if (day.compareTo(today) > 0) return HabitDay.off;
  if (day.compareTo(createdDay(habit)) < 0) return HabitDay.off;
  if (!isPlanned(habit, day)) return HabitDay.off;
  return day == today ? HabitDay.open : HabitDay.missed;
}

/// The states of the last [count] days, oldest first, ending with [today].
List<HabitDay> lastDays(
  Habit habit,
  Map<String, String> marks, {
  required String today,
  int count = 7,
}) => [
  for (var i = count - 1; i >= 0; i--)
    dayState(habit, marks, addDays(today, -i), today: today),
];

/// Kept days out of counted days over a stretch of days.
class Kept {
  const Kept(this.done, this.counted);

  final int done;

  /// Days that count: planned days that were done or missed. Skipped days,
  /// days off and today while it is still open do not count.
  final int counted;

  /// 0 to 100, or null when no day counted yet.
  int? get percent => counted == 0 ? null : (done * 100 / counted).round();

  Kept operator +(Kept other) =>
      Kept(done + other.done, counted + other.counted);
}

/// How well [habit] was kept over the [days] days that end with [end].
Kept keptOver(
  Habit habit,
  Map<String, String> marks, {
  required String end,
  required String today,
  int days = 30,
}) {
  var done = 0;
  var counted = 0;
  for (var i = 0; i < days; i++) {
    switch (dayState(habit, marks, addDays(end, -i), today: today)) {
      case HabitDay.done:
        done++;
        counted++;
      case HabitDay.missed:
        counted++;
      case HabitDay.skipped || HabitDay.open || HabitDay.off:
        break;
    }
  }
  return Kept(done, counted);
}

/// The same over all [habits].
Kept keptOverAll(
  List<Habit> habits,
  List<HabitLog> logs, {
  required String end,
  required String today,
  int days = 30,
}) => habits.fold(
  const Kept(0, 0),
  (sum, habit) =>
      sum +
      keptOver(
        habit,
        marksOf(habit.id, logs),
        end: end,
        today: today,
        days: days,
      ),
);

/// Today's progress: habits done today out of habits planned today.
({int done, int planned}) todayProgress(
  List<Habit> habits,
  List<HabitLog> logs, {
  required String today,
}) {
  var done = 0;
  var planned = 0;
  for (final habit in habits) {
    final state = dayState(habit, marksOf(habit.id, logs), today, today: today);
    if (state == HabitDay.done) {
      done++;
      planned++;
    } else if (state == HabitDay.open) {
      planned++;
    }
  }
  return (done: done, planned: planned);
}

/// The habit kept best over the last 30 days, with its percent, or null
/// when no habit has a counted day yet.
({Habit habit, int percent})? mostKept(
  List<Habit> habits,
  List<HabitLog> logs, {
  required String today,
}) {
  ({Habit habit, int percent})? best;
  for (final habit in habits) {
    final percent = keptOver(
      habit,
      marksOf(habit.id, logs),
      end: today,
      today: today,
    ).percent;
    if (percent == null) continue;
    if (best == null || percent > best.percent) {
      best = (habit: habit, percent: percent);
    }
  }
  return best;
}
