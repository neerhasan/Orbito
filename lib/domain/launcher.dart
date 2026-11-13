/// The Quick Launcher's line reader: one typed line becomes a task, a habit
/// mark, a night of sleep, a focus session, a note, or an Inbox item. It is
/// a port of `parseLine` and `parseTokens` from the prototype
/// (`docs/reference/prototype/orbito-prototype.html`).
///
/// Lines the app cannot act on yet (distractions, time blocks) and lines it
/// cannot understand go to the Inbox, so nothing typed is ever lost.
library;

import '../data/local/app_database.dart';
import 'dates.dart';
import 'sleep.dart' show formatMinutes, formatTime, sleepMinutes, timeOf;

/// The colour of a preview chip, after the design's tags.
enum ChipTone { ink, blue, green, orange, amber, violet, plain }

/// One chip of the preview the user sees before confirming.
typedef PreviewChip = (String label, ChipTone tone);

/// What a line will create.
sealed class ParsedLine {
  const ParsedLine(this.chips);

  /// What will be created, shown before the user confirms.
  final List<PreviewChip> chips;
}

class TaskLine extends ParsedLine {
  const TaskLine({
    required this.title,
    required List<PreviewChip> chips,
    this.dueDate,
    this.time,
    this.priority = TaskPriority.none,
    this.projectId,
    this.tags = const [],
  }) : super(chips);

  final String title;

  /// `YYYY-MM-DD`.
  final String? dueDate;

  /// `HH:MM`. Tasks have no time yet, so it is kept in the task's notes.
  final String? time;
  final String priority;
  final String? projectId;

  /// `#tags` that matched no project. Kept in the task's notes.
  final List<String> tags;

  /// The notes the task starts with: its time and tags, if any.
  String? get notes {
    final parts = [if (time != null) 'At ${formatTime(time!)}', ...tags];
    return parts.isEmpty ? null : parts.join(' · ');
  }
}

class HabitLine extends ParsedLine {
  const HabitLine({required this.habit, required List<PreviewChip> chips})
    : super(chips);

  final Habit habit;
}

class SleepLine extends ParsedLine {
  const SleepLine({
    required this.bedTime,
    required this.wakeTime,
    required List<PreviewChip> chips,
  }) : super(chips);

  /// `HH:MM`.
  final String bedTime;
  final String wakeTime;
}

class FocusLine extends ParsedLine {
  const FocusLine({required this.task, required List<PreviewChip> chips})
    : super(chips);

  final Task task;
}

class NoteLine extends ParsedLine {
  const NoteLine({required this.text, required List<PreviewChip> chips})
    : super(chips);

  final String text;
}

class InboxLine extends ParsedLine {
  const InboxLine({required this.text, required List<PreviewChip> chips})
    : super(chips);

  final String text;
}

String _cap(String text) =>
    text.isEmpty ? text : text[0].toUpperCase() + text.substring(1);

/// `Today`, `Tomorrow` or `Fri 20 Nov`.
String _day(String key, String today) {
  if (key == today) return 'Today';
  if (key == addDays(today, 1)) return 'Tomorrow';
  return formatWeekDay(key);
}

/// Hours from a typed hour and optional am/pm. Without am/pm, 1 to 6 means
/// the afternoon (people rarely plan tasks at 3 at night).
int _hour(String hour, String? amPm) {
  var h = int.parse(hour);
  final ap = amPm?.toLowerCase();
  if (ap == 'pm' && h < 12) h += 12;
  if (ap == 'am' && h == 12) h = 0;
  if (ap == null && h >= 1 && h <= 6) h += 12;
  return h;
}

/// A project whose name, without spaces, starts with [tag].
Project? _project(String tag, List<Project> projects) {
  final wanted = tag.toLowerCase();
  for (final project in projects) {
    final name = project.name.toLowerCase().replaceAll(RegExp(r'\s+'), '');
    if (name.startsWith(wanted)) return project;
  }
  return null;
}

/// An open task whose title starts with, or else contains, [query].
Task? _findTask(String query, List<Task> tasks) {
  final q = query.toLowerCase().trim();
  final open = tasks.where((task) => task.status != TaskStatus.done);
  return open.where((t) => t.title.toLowerCase().startsWith(q)).firstOrNull ??
      open.where((t) => t.title.toLowerCase().contains(q)).firstOrNull;
}

/// Reads one line. [today] is a day key. Returns null for an empty line.
ParsedLine? parseLine(
  String raw, {
  required String today,
  List<Habit> habits = const [],
  List<Project> projects = const [],
  List<Task> tasks = const [],
}) {
  final text = raw.trim();
  if (text.isEmpty) return null;
  final low = text.toLowerCase();

  // "slept 11 to 6:30"
  final sleep = RegExp(
    r'^(?:slept|sleep)\s+(?:from\s+)?(\d{1,2})(?::(\d{2}))?\s*(am|pm)?\s*'
    r'(?:to|-|–|until|till)\s*(\d{1,2})(?::(\d{2}))?\s*(am|pm)?',
  ).firstMatch(low);
  if (sleep != null) {
    var bedHour = int.parse(sleep[1]!);
    final bedMinute = int.parse(sleep[2] ?? '0');
    var wakeHour = int.parse(sleep[4]!);
    final wakeMinute = int.parse(sleep[5] ?? '0');
    if (sleep[3] == 'pm' && bedHour < 12) {
      bedHour += 12;
    } else if (sleep[3] == 'am' && bedHour == 12) {
      bedHour = 0;
    } else if (sleep[3] == null && bedHour >= 6 && bedHour < 12) {
      bedHour += 12;
    }
    if (sleep[6] == 'pm' && wakeHour < 12) wakeHour += 12;
    if (sleep[6] == 'am' && wakeHour == 12) wakeHour = 0;
    if (bedHour <= 23 && wakeHour <= 23 && bedMinute < 60 && wakeMinute < 60) {
      final bed = timeOf(bedHour * 60 + bedMinute);
      final wake = timeOf(wakeHour * 60 + wakeMinute);
      return SleepLine(
        bedTime: bed,
        wakeTime: wake,
        chips: [
          ('Sleep log', ChipTone.ink),
          ('Night ending today', ChipTone.blue),
          ('${formatTime(bed)} to ${formatTime(wake)}', ChipTone.plain),
          (formatMinutes(sleepMinutes(bed, wake)), ChipTone.plain),
        ],
      );
    }
  }

  // "distracted 20 min by phone": no distraction log yet, so the Inbox.
  if (RegExp(r'^distract(?:ed|ion)?\s+\d+').hasMatch(low)) {
    return InboxLine(
      text: text,
      chips: [
        ('Inbox', ChipTone.plain),
        (text, ChipTone.plain),
        ('Distractions come later', ChipTone.blue),
      ],
    );
  }

  // "meditated", "read done": marks a habit done today.
  final words = low.split(RegExp(r'\s+'));
  final first = words.first;
  if (!RegExp(r'^(task|todo|note|event|block|focus|start)$').hasMatch(first) &&
      words.length <= 3) {
    for (final habit in habits) {
      final name = habit.name.toLowerCase();
      var match = low == name || low == '$name done' || low == 'done $name';
      if (!match) {
        final head = name.split(RegExp(r'\s+')).first;
        if (head.length >= 4) {
          final n = head.length < 5 ? head.length : 5;
          match =
              first.length >= n &&
              first.substring(0, n) == head.substring(0, n);
        }
      }
      if (match) {
        return HabitLine(
          habit: habit,
          chips: [
            ('Habit done', ChipTone.green),
            (habit.name, ChipTone.plain),
            ('Today', ChipTone.blue),
          ],
        );
      }
    }
  }

  // "focus write the plan": starts the timer on a task.
  final focus = RegExp(
    r'^(?:focus|start)\s+(?:on\s+)?(.+)',
    caseSensitive: false,
  ).firstMatch(text);
  if (focus != null) {
    final task = _findTask(focus[1]!, tasks);
    if (task != null) {
      return FocusLine(
        task: task,
        chips: [('Start focus', ChipTone.orange), (task.title, ChipTone.plain)],
      );
    }
  }

  // "note meeting ideas"
  final note = RegExp(
    r'^note[:\s]+(.+)',
    caseSensitive: false,
  ).firstMatch(text);
  if (note != null) {
    final body = _cap(note[1]!.trim());
    return NoteLine(
      text: body,
      chips: [
        ('Note', ChipTone.violet),
        (body, ChipTone.plain),
        ('Kept in the Inbox', ChipTone.blue),
      ],
    );
  }

  // "event review at 3pm": no time blocks yet, so the Inbox.
  if (RegExp(r'^(event|block)\b', caseSensitive: false).hasMatch(text)) {
    return InboxLine(
      text: text,
      chips: [
        ('Inbox', ChipTone.plain),
        (text, ChipTone.plain),
        ('Time blocks come later', ChipTone.blue),
      ],
    );
  }

  final explicit = RegExp(
    r'^(task|todo)\b',
    caseSensitive: false,
  ).hasMatch(text);
  final tokens = _Tokens.read(
    text.replaceFirst(RegExp(r'^(task|todo)[:\s]+', caseSensitive: false), ''),
    today: today,
    projects: projects,
  );
  if (explicit ||
      tokens.due != null ||
      tokens.time != null ||
      tokens.priority != null ||
      tokens.project != null) {
    final title = tokens.title.isEmpty ? 'Untitled task' : tokens.title;
    final priority = tokens.priority ?? TaskPriority.none;
    return TaskLine(
      title: title,
      dueDate: tokens.due,
      time: tokens.time,
      priority: priority,
      projectId: tokens.project?.id,
      tags: tokens.tags,
      chips: [
        ('Task', ChipTone.ink),
        (title, ChipTone.plain),
        if (tokens.due != null) (_day(tokens.due!, today), ChipTone.blue),
        if (tokens.time != null) (formatTime(tokens.time!), ChipTone.blue),
        for (final tag in tokens.tags) (tag, ChipTone.amber),
        if (tokens.project != null) (tokens.project!.name, ChipTone.orange),
        if (priority == TaskPriority.high) ('High priority', ChipTone.orange),
        if (priority == TaskPriority.medium)
          ('Medium priority', ChipTone.amber),
      ],
    );
  }

  return InboxLine(
    text: text,
    chips: [
      ('Inbox', ChipTone.plain),
      (text, ChipTone.plain),
      ('Sort it later', ChipTone.blue),
    ],
  );
}

/// The parts of a task line: date, time, priority, project and tags. What
/// is left becomes the title.
class _Tokens {
  _Tokens._();

  String title = '';
  String? due;
  String? time;
  String? priority;
  Project? project;
  final tags = <String>[];

  static _Tokens read(
    String body, {
    required String today,
    required List<Project> projects,
  }) {
    final r = _Tokens._();
    var s = ' $body ';

    s = s.replaceAllMapped(RegExp(r'\s#([\w-]+)'), (m) {
      final project = _project(m[1]!, projects);
      if (project != null && r.project == null) {
        r.project = project;
      } else {
        r.tags.add('#${m[1]!.toLowerCase()}');
      }
      return ' ';
    });
    s = s.replaceAllMapped(RegExp(r'\s\+([\w-]+)'), (m) {
      final project = _project(m[1]!, projects);
      if (project != null) r.project = project;
      return ' ';
    });
    s = s.replaceFirstMapped(
      RegExp(r'\s!?(high|urgent|medium|med|low)(?=\s)', caseSensitive: false),
      (m) {
        final p = m[1]!.toLowerCase();
        r.priority = p == 'high' || p == 'urgent'
            ? TaskPriority.high
            : p == 'low'
            ? TaskPriority.none
            : TaskPriority.medium;
        return ' ';
      },
    );
    s = s.replaceFirstMapped(
      RegExp(
        r'\s(today|tonight|tomorrow|tmrw|tmr|next week)(?=\s)',
        caseSensitive: false,
      ),
      (m) {
        final d = m[1]!.toLowerCase();
        r.due = d == 'today' || d == 'tonight'
            ? today
            : d == 'next week'
            ? addDays(today, 7)
            : addDays(today, 1);
        return ' ';
      },
    );
    s = s.replaceFirstMapped(
      RegExp(r'\sin (\d{1,2}) days?(?=\s)', caseSensitive: false),
      (m) {
        r.due = addDays(today, int.parse(m[1]!));
        return ' ';
      },
    );
    s = s.replaceFirstMapped(
      RegExp(
        r'\s(?:on\s)?(sun|mon|tue|tues|wed|thu|thur|thurs|fri|sat)'
        r'(?:day|nesday|sday|urday)?(?=\s)',
        caseSensitive: false,
      ),
      (m) {
        const days = ['sun', 'mon', 'tue', 'wed', 'thu', 'fri', 'sat'];
        final wanted = days.indexOf(m[1]!.toLowerCase().substring(0, 3));
        final current = parseDayKey(today)!.weekday % 7;
        var ahead = (wanted - current + 7) % 7;
        if (ahead == 0) ahead = 7;
        r.due = addDays(today, ahead);
        return ' ';
      },
    );

    // "3pm to 5pm" or "at 9-11": the start is the task's time.
    s = s.replaceFirstMapped(
      RegExp(
        r'\s(?:at\s|from\s)?(\d{1,2})(?::(\d{2}))?\s*(am|pm)?\s*(?:-|to|–)\s*'
        r'(\d{1,2})(?::(\d{2}))?\s*(am|pm)?(?=\s)',
        caseSensitive: false,
      ),
      (m) {
        final all = m[0]!;
        if (m[2] == null &&
            m[3] == null &&
            m[5] == null &&
            m[6] == null &&
            !RegExp(r'at|from', caseSensitive: false).hasMatch(all)) {
          return all;
        }
        final endAmPm = m[6];
        final startAmPm =
            m[3] ??
            (endAmPm != null && int.parse(m[1]!) <= int.parse(m[4]!)
                ? endAmPm
                : null);
        r.time = timeOf(_hour(m[1]!, startAmPm) * 60 + int.parse(m[2] ?? '0'));
        return ' ';
      },
    );
    if (r.time == null) {
      s = s.replaceFirstMapped(
        RegExp(
          r'\s(?:at\s)?(\d{1,2}):(\d{2})\s*(am|pm)?(?=\s)',
          caseSensitive: false,
        ),
        (m) {
          r.time = timeOf(_hour(m[1]!, m[3]) * 60 + int.parse(m[2]!));
          return ' ';
        },
      );
    }
    if (r.time == null) {
      s = s.replaceFirstMapped(
        RegExp(r'\s(?:at\s)?(\d{1,2})\s*(am|pm)(?=\s)', caseSensitive: false),
        (m) {
          r.time = timeOf(_hour(m[1]!, m[2]) * 60);
          return ' ';
        },
      );
    }
    if (r.time == null) {
      s = s.replaceFirstMapped(
        RegExp(r'\sat\s(\d{1,2})(?=\s)', caseSensitive: false),
        (m) {
          r.time = timeOf(_hour(m[1]!, null) * 60);
          return ' ';
        },
      );
    }
    if (r.time != null && r.due == null) r.due = today;
    r.title = _cap(
      s
          .replaceAll(RegExp(r'\s+'), ' ')
          .trim()
          .replaceFirst(RegExp(r'\s+(at|on|by)$', caseSensitive: false), ''),
    );
    return r;
  }
}
