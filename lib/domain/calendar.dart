/// The rules of the Calendar page (design: `Calendar.dc.html`): which days
/// a view shows, how to step back and forward, and how blocks that overlap
/// sit side by side. Plain functions, so they are easy to test.
library;

import '../data/local/app_database.dart';
import 'dates.dart';
import 'sleep.dart' show minutesOf;

/// The views of the Calendar page. [days] is how many day columns the time
/// grid shows; the month view has no time grid.
enum CalendarView {
  month('Month', 0),
  week('Week', 7),
  four('4 day', 4),
  three('3 day', 3),
  two('2 day', 2);

  const CalendarView(this.label, this.days);
  final String label;
  final int days;
}

/// The Sunday on or before [day] (weeks start on Sunday, as in the design).
String weekStartOf(String day) {
  final date = parseDayKey(day)!;
  return addDays(day, -(date.weekday % 7));
}

/// The days a view shows around [anchor]: the week of [anchor], [anchor]
/// and the days after it, or six full weeks covering [anchor]'s month.
List<String> shownDays(CalendarView view, String anchor) {
  final String first;
  final int count;
  switch (view) {
    case CalendarView.month:
      final date = parseDayKey(anchor)!;
      first = weekStartOf(dayKey(DateTime(date.year, date.month)));
      count = 42;
    case CalendarView.week:
      first = weekStartOf(anchor);
      count = 7;
    default:
      first = anchor;
      count = view.days;
  }
  return [for (var i = 0; i < count; i++) addDays(first, i)];
}

/// The anchor one step back (`direction` -1) or forward (+1).
String stepAnchor(CalendarView view, String anchor, int direction) {
  if (view == CalendarView.month) {
    final date = parseDayKey(anchor)!;
    return dayKey(DateTime(date.year, date.month + direction));
  }
  return addDays(anchor, view.days * direction);
}

/// The ISO week number of [day] (weeks starting on Monday).
int weekNumber(String day) {
  final date = parseDayKey(day)!;
  final thursday = date.add(Duration(days: 4 - date.weekday));
  final firstOfYear = DateTime(thursday.year);
  return (thursday.difference(firstOfYear).inDays ~/ 7) + 1;
}

/// "15 to 21 November", or "29 November to 5 December" across months.
String rangeLabel(List<String> days) {
  final first = parseDayKey(days.first)!;
  final last = parseDayKey(days.last)!;
  if (days.length == 1) return '${first.day} ${monthNames[first.month - 1]}';
  final firstPart = first.month == last.month
      ? '${first.day}'
      : '${first.day} ${monthNames[first.month - 1]}';
  return '$firstPart to ${last.day} ${monthNames[last.month - 1]}';
}

/// The heading over the grid: the month, and the week or the days shown.
({String title, String subtitle}) calendarTitle(
  CalendarView view,
  String anchor,
) {
  final date = parseDayKey(anchor)!;
  final days = shownDays(view, anchor);
  final middle = parseDayKey(days[days.length ~/ 2])!;
  final title = view == CalendarView.month
      ? '${monthNames[date.month - 1]} ${date.year}'
      : '${monthNames[middle.month - 1]} ${middle.year}';
  final subtitle = switch (view) {
    CalendarView.month => '',
    CalendarView.week =>
      'Week ${weekNumber(addDays(days.first, 1))} · ${rangeLabel(days)}',
    _ => rangeLabel(days),
  };
  return (title: title, subtitle: subtitle);
}

/// A block on the time grid, in minutes after midnight.
class TimeBlock {
  const TimeBlock(this.id, this.start, this.end);

  final String id;
  final int start;
  final int end;
}

/// Where a block sits: its column among blocks that overlap it, out of
/// [columns] side by side.
class PlacedBlock {
  const PlacedBlock(this.block, this.column, this.columns);

  final TimeBlock block;
  final int column;
  final int columns;
}

/// Places blocks that overlap side by side. Blocks that touch (one ends
/// when the next starts) do not overlap.
List<PlacedBlock> layoutBlocks(List<TimeBlock> blocks) {
  final sorted = [...blocks]
    ..sort((a, b) {
      final byStart = a.start.compareTo(b.start);
      return byStart != 0 ? byStart : b.end.compareTo(a.end);
    });
  final placed = <PlacedBlock>[];
  var group = <(TimeBlock, int)>[];
  var groupEnd = -1;

  void closeGroup() {
    if (group.isEmpty) return;
    final columns =
        group.map((entry) => entry.$2).reduce((a, b) => a > b ? a : b) + 1;
    for (final (block, column) in group) {
      placed.add(PlacedBlock(block, column, columns));
    }
    group = [];
  }

  for (final block in sorted) {
    if (block.start >= groupEnd) {
      closeGroup();
      groupEnd = block.end;
    } else if (block.end > groupEnd) {
      groupEnd = block.end;
    }
    // The first column whose last block has ended.
    var column = 0;
    while (group.any(
      (entry) => entry.$2 == column && entry.$1.end > block.start,
    )) {
      column++;
    }
    group.add((block, column));
  }
  closeGroup();
  return placed;
}

/// The events of [day] as blocks.
List<TimeBlock> eventBlocksOn(String day, List<CalendarEvent> events) => [
  for (final event in events)
    if (event.day == day)
      if ((minutesOf(event.startTime), minutesOf(event.endTime))
          case (final int start, final int end) when end > start)
        TimeBlock(event.id, start, end),
];

/// The focus sessions that started on [day], as blocks from start to end
/// (cut at midnight).
List<TimeBlock> focusBlocksOn(String day, List<FocusSession> sessions) {
  final blocks = <TimeBlock>[];
  for (final session in sessions) {
    final start = parseStoredTime(session.startedAt);
    if (start == null || dayKey(start) != day) continue;
    final end =
        parseStoredTime(session.endedAt) ??
        start.add(Duration(seconds: session.focusSeconds));
    final from = start.hour * 60 + start.minute;
    final to = dayKey(end) == day ? end.hour * 60 + end.minute : 1440;
    blocks.add(TimeBlock(session.id, from, to > from ? to : from + 1));
  }
  return blocks;
}
