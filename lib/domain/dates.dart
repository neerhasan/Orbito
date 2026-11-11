/// Day and time helpers. Days are kept as `YYYY-MM-DD` text ("day keys"),
/// always in the device's time zone.
library;

const monthNames = [
  'January',
  'February',
  'March',
  'April',
  'May',
  'June',
  'July',
  'August',
  'September',
  'October',
  'November',
  'December',
];

const weekdayShort = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

String _two(int value) => value.toString().padLeft(2, '0');

/// The day key of a moment, read in the device's time zone.
String dayKey(DateTime moment) {
  final local = moment.toLocal();
  return '${local.year}-${_two(local.month)}-${_two(local.day)}';
}

/// The first moment of the day a key names, or null when the text is not a
/// day key.
DateTime? parseDayKey(String? key) {
  if (key == null) return null;
  final parts = key.split('-');
  if (parts.length != 3) return null;
  final year = int.tryParse(parts[0]);
  final month = int.tryParse(parts[1]);
  final day = int.tryParse(parts[2]);
  if (year == null || month == null || day == null) return null;
  return DateTime(year, month, day);
}

/// The key of the day [days] after (or before, when negative) [key].
String addDays(String key, int days) {
  final date = parseDayKey(key)!;
  return dayKey(DateTime(date.year, date.month, date.day + days));
}

/// A stored server or device time (ISO 8601) as a moment in the device's
/// time zone, or null when it is empty or unreadable.
DateTime? parseStoredTime(String? stored) {
  if (stored == null) return null;
  return DateTime.tryParse(stored)?.toLocal();
}

/// The day key of a stored time, in the device's time zone.
String? dayKeyOfStoredTime(String? stored) {
  final moment = parseStoredTime(stored);
  return moment == null ? null : dayKey(moment);
}

/// `20 Nov`, with the year added when it is not [today]'s year.
String formatShortDay(String key, {required String today}) {
  final date = parseDayKey(key);
  if (date == null) return key;
  final month = monthNames[date.month - 1].substring(0, 3);
  final sameYear = key.substring(0, 4) == today.substring(0, 4);
  return sameYear ? '${date.day} $month' : '${date.day} $month ${date.year}';
}

/// `Today`, `Tomorrow`, `Yesterday`, or the short day.
String formatRelativeDay(String key, {required String today}) {
  if (key == today) return 'Today';
  if (key == addDays(today, 1)) return 'Tomorrow';
  if (key == addDays(today, -1)) return 'Yesterday';
  return formatShortDay(key, today: today);
}
