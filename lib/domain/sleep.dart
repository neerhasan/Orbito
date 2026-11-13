/// The rules for the sleep log: how long a night was, the averages and the
/// consistency number. Plain functions, so they are easy to test.
library;

import '../data/local/app_database.dart';
import 'dates.dart';

/// Minutes after midnight of an `HH:MM` time, or null when unreadable.
int? minutesOf(String time) {
  final parts = time.split(':');
  if (parts.length != 2) return null;
  final hours = int.tryParse(parts[0]);
  final minutes = int.tryParse(parts[1]);
  if (hours == null || minutes == null) return null;
  if (hours < 0 || hours > 23 || minutes < 0 || minutes > 59) return null;
  return hours * 60 + minutes;
}

/// `HH:MM` from minutes after midnight (any number; it wraps around).
String timeOf(int minutes) {
  final wrapped = minutes % 1440;
  final hours = wrapped ~/ 60;
  final rest = wrapped % 60;
  return '${hours.toString().padLeft(2, '0')}:'
      '${rest.toString().padLeft(2, '0')}';
}

/// The time of day on a 12-hour clock: `11:30 PM`.
String formatTime(String time) {
  final minutes = minutesOf(time);
  if (minutes == null) return time;
  final hours = minutes ~/ 60;
  final rest = (minutes % 60).toString().padLeft(2, '0');
  final hour12 = hours % 12 == 0 ? 12 : hours % 12;
  return '$hour12:$rest ${hours < 12 ? 'AM' : 'PM'}';
}

/// How long a night lasted, in minutes. A wake time earlier than the
/// bedtime means the night crossed midnight.
int sleepMinutes(String bedTime, String wakeTime) {
  final bed = minutesOf(bedTime);
  final wake = minutesOf(wakeTime);
  if (bed == null || wake == null) return 0;
  return (wake - bed) % 1440;
}

/// True when a night is so short or so long that the times are probably
/// typed wrong, so the app asks the user to check them.
bool needsCheck(int minutes) => minutes == 0 || minutes > 16 * 60;

/// `7h 10m`, `45m`, `0m`.
String formatMinutes(int minutes) {
  final hours = minutes ~/ 60;
  final rest = minutes % 60;
  if (hours == 0) return '${rest}m';
  return rest == 0 ? '${hours}h' : '${hours}h ${rest}m';
}

/// The night filed under [day], or null.
SleepLog? nightOn(List<SleepLog> nights, String day) =>
    nights.where((night) => night.day == day).firstOrNull;

/// The nights of the [count] mornings that end with [end], oldest first;
/// null where no night was logged.
List<SleepLog?> nightsBefore(
  List<SleepLog> nights, {
  required String end,
  required int count,
}) => [for (var i = count - 1; i >= 0; i--) nightOn(nights, addDays(end, -i))];

/// The average length of the logged nights, in minutes, or null when none.
int? averageMinutes(Iterable<SleepLog?> nights) {
  final lengths = [
    for (final night in nights)
      if (night != null) sleepMinutes(night.bedTime, night.wakeTime),
  ];
  if (lengths.isEmpty) return null;
  return (lengths.reduce((a, b) => a + b) / lengths.length).round();
}

/// A bedtime on a scale that does not break at midnight: times before noon
/// count as the next day (00:30 is later than 23:30).
int _bedScale(String bedTime) {
  final minutes = minutesOf(bedTime) ?? 0;
  return minutes < 12 * 60 ? minutes + 1440 : minutes;
}

int _median(List<int> values) {
  final sorted = [...values]..sort();
  return sorted[sorted.length ~/ 2];
}

/// The usual bedtime and wake time (the middle value of each), or null when
/// no night is logged.
({String bed, String wake})? usualTimes(Iterable<SleepLog?> nights) {
  final logged = [for (final night in nights) ?night];
  if (logged.isEmpty) return null;
  final bed = _median([for (final night in logged) _bedScale(night.bedTime)]);
  final wake = _median([
    for (final night in logged) minutesOf(night.wakeTime) ?? 0,
  ]);
  return (bed: timeOf(bed), wake: timeOf(wake));
}

/// The share of logged nights whose bedtime was within 45 minutes of the
/// usual bedtime, 0 to 100, or null when no night is logged.
int? consistency(Iterable<SleepLog?> nights) {
  final bedtimes = [
    for (final night in nights)
      if (night != null) _bedScale(night.bedTime),
  ];
  if (bedtimes.isEmpty) return null;
  final usual = _median(bedtimes);
  final close = bedtimes.where((bed) => (bed - usual).abs() <= 45).length;
  return (close * 100 / bedtimes.length).round();
}

/// A bedtime in minutes on a scale that does not break at midnight (times
/// before noon count as the next day), for drawing the sleep chart.
int bedScale(String bedTime) => _bedScale(bedTime);
