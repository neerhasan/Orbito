/// The sections of the Today page (design: Today dashboard · Phase 1) and
/// how the user's choice of sections is stored: the names of the sections
/// that are on, in order, comma separated.
library;

import 'sleep.dart' show minutesOf;

/// Where a section sits: the big main panel or the panel on the right.
enum TodayColumn { main, side }

enum TodaySection {
  greeting(
    'Greeting',
    'How many tasks and habits are left today',
    TodayColumn.main,
  ),
  habits(
    'Habits',
    'Today’s habits and your day from waking to bedtime',
    TodayColumn.main,
  ),
  time('Time today', 'Focused time since you woke up', TodayColumn.main),
  sleep('Sleep', 'Last night and the last 7 nights', TodayColumn.main),
  calendar(
    'Calendar',
    'This month, with days that have tasks',
    TodayColumn.side,
  ),
  tasks('Tasks', 'Overdue and today’s tasks', TodayColumn.side),
  projects('Projects', 'Progress and focus time', TodayColumn.side),
  goals('Goals', 'Progress of your goals', TodayColumn.side);

  const TodaySection(this.label, this.description, this.column);

  final String label;
  final String description;
  final TodayColumn column;
}

/// Stored when the user turned every section off (an empty text means "no
/// choice yet", which shows the defaults).
const _none = 'none';

/// New users see every section, in the design's order.
const defaultSections = TodaySection.values;

/// The sections that are on, in order, from the stored text.
List<TodaySection> readSections(String? stored) {
  if (stored == null || stored.trim().isEmpty) return defaultSections;
  if (stored.trim() == _none) return const [];
  final byName = {
    for (final section in TodaySection.values) section.name: section,
  };
  final seen = <TodaySection>{};
  return [
    for (final name in stored.split(','))
      if (byName[name.trim()] case final section? when seen.add(section))
        section,
  ];
}

/// The text to store for [sections].
String writeSections(List<TodaySection> sections) =>
    sections.isEmpty ? _none : sections.map((s) => s.name).join(',');

/// [sections] with [section] switched on (added at the end) or off.
List<TodaySection> toggleSection(
  List<TodaySection> sections,
  TodaySection section,
) => sections.contains(section)
    ? [...sections.where((s) => s != section)]
    : [...sections, section];

/// [sections] with [section] moved one place up (-1) or down (+1) among the
/// sections of its own column.
List<TodaySection> moveSection(
  List<TodaySection> sections,
  TodaySection section,
  int by,
) {
  final same = sections.where((s) => s.column == section.column).toList();
  final from = same.indexOf(section);
  final to = from + by;
  if (from < 0 || to < 0 || to >= same.length) return sections;
  same
    ..removeAt(from)
    ..insert(to, section);
  final others = sections.where((s) => s.column != section.column);
  return [...same, ...others];
}

/// The greeting for the time of day.
String greetingFor(DateTime now) {
  final hour = now.hour;
  if (hour < 12) return 'Good morning';
  if (hour < 18) return 'Good afternoon';
  return 'Good evening';
}

/// Where "now" is on the 24-hour day bar. The day starts at the wake time
/// and lasts 24 hours, so the bar keeps running past bedtime.
class DayProgress {
  const DayProgress({
    required this.share,
    required this.bedShare,
    required this.pastBed,
    required this.awake,
  });

  /// How much of the waking day (wake time to bedtime) has passed: 1 at
  /// bedtime, more than 1 when the user stays up later.
  final double awake;

  /// 0 to 1: how much of the 24 hours since waking has passed.
  final double share;

  /// 0 to 1: where the bedtime dot sits on the bar.
  final double bedShare;

  /// True once the bedtime has passed (the user is up late).
  final bool pastBed;

  /// The whole percent shown next to the bar (founder): 100% at bedtime,
  /// 110%, 120% and so on after it.
  int get percent => (awake * 100).round();
}

/// The day bar for [now], with [wake] and [bed] as `HH:MM`. Before today's
/// wake time the day that began yesterday is still running.
DayProgress dayProgress(
  DateTime now, {
  required String wake,
  required String bed,
}) {
  final wakeMinutes = minutesOf(wake) ?? 7 * 60;
  final bedMinutes = minutesOf(bed) ?? 23 * 60;
  var start = DateTime(
    now.year,
    now.month,
    now.day,
    wakeMinutes ~/ 60,
    wakeMinutes % 60,
  );
  if (now.isBefore(start)) {
    start = DateTime(
      start.year,
      start.month,
      start.day - 1,
      start.hour,
      start.minute,
    );
  }
  final elapsed = now.difference(start).inSeconds / 60;
  final bedOffset = (bedMinutes - wakeMinutes) % 1440;
  return DayProgress(
    share: (elapsed / 1440).clamp(0.0, 1.0),
    bedShare: bedOffset / 1440,
    pastBed: elapsed >= bedOffset,
    awake: bedOffset == 0 ? 0 : elapsed / bedOffset,
  );
}
