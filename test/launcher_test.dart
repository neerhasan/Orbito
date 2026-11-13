import 'package:flutter_test/flutter_test.dart';
import 'package:orbito/data/local/app_database.dart';
import 'package:orbito/domain/launcher.dart';

// 2026-11-13 is a Friday.
const _today = '2026-11-13';

const _meditate = Habit(
  id: 'h1',
  userId: 'u',
  name: 'Meditate',
  days: '1234567',
  createdAt: '',
  updatedAt: '',
);
const _readBook = Habit(
  id: 'h2',
  userId: 'u',
  name: 'Read book',
  days: '1234567',
  createdAt: '',
  updatedAt: '',
);
const _work = Project(
  id: 'p1',
  userId: 'u',
  name: 'Work stuff',
  color: 'blue',
  createdAt: '',
  updatedAt: '',
);
const _plan = Task(
  id: 't1',
  userId: 'u',
  title: 'Write the plan',
  priority: 'none',
  status: 'open',
  createdAt: '',
  updatedAt: '',
);

ParsedLine? _parse(String line) => parseLine(
  line,
  today: _today,
  habits: const [_meditate, _readBook],
  projects: const [_work],
  tasks: const [_plan],
);

void main() {
  test('an empty line is nothing', () {
    expect(_parse('   '), isNull);
  });

  group('tasks', () {
    test('1: date, time, project, priority', () {
      final line = _parse('task call bank tomorrow 10am #work high')!;
      expect(line, isA<TaskLine>());
      final task = line as TaskLine;
      expect(task.title, 'Call bank');
      expect(task.dueDate, '2026-11-14');
      expect(task.time, '10:00');
      expect(task.projectId, 'p1');
      expect(task.priority, TaskPriority.high);
      expect(task.notes, 'At 10:00 AM');
    });

    test('2: a weekday means the next one, never today', () {
      final task = _parse('review contract friday 3pm') as TaskLine;
      expect(task.title, 'Review contract');
      expect(task.dueDate, '2026-11-20');
      expect(task.time, '15:00');
    });

    test('3: "today" alone makes a task', () {
      final task = _parse('buy milk today') as TaskLine;
      expect(task.title, 'Buy milk');
      expect(task.dueDate, _today);
      expect(task.time, isNull);
    });

    test('4: a time alone puts it on today; 3 without am/pm is the '
        'afternoon', () {
      final task = _parse('call mum at 3') as TaskLine;
      expect(task.title, 'Call mum');
      expect(task.dueDate, _today);
      expect(task.time, '15:00');
    });

    test('5: "in 3 days"', () {
      final task = _parse('task renew passport in 3 days') as TaskLine;
      expect(task.dueDate, '2026-11-16');
      expect(task.title, 'Renew passport');
    });

    test('6: a #tag that is no project is kept in the notes', () {
      final task = _parse('todo fix the bike #garage') as TaskLine;
      expect(task.title, 'Fix the bike');
      expect(task.projectId, isNull);
      expect(task.tags, ['#garage']);
      expect(task.notes, '#garage');
    });

    test('7: medium priority and next week', () {
      final task = _parse('plan trip next week medium') as TaskLine;
      expect(task.priority, TaskPriority.medium);
      expect(task.dueDate, '2026-11-20');
      expect(task.title, 'Plan trip');
    });

    test('8: a time range keeps the start', () {
      final task = _parse('task deep work 9-11am') as TaskLine;
      expect(task.time, '09:00');
      expect(task.title, 'Deep work');
    });

    test('9: the preview names what will be created', () {
      final line = _parse('task call bank tomorrow 10am #work high')!;
      final labels = [for (final (label, _) in line.chips) label];
      expect(labels, [
        'Task',
        'Call bank',
        'Tomorrow',
        '10:00 AM',
        'Work stuff',
        'High priority',
      ]);
    });
  });

  group('habits, sleep, focus and notes', () {
    test('10: a habit name marks it done', () {
      final line = _parse('meditated') as HabitLine;
      expect(line.habit.id, 'h1');
    });

    test('11: "read book done" marks the habit', () {
      final line = _parse('read book done') as HabitLine;
      expect(line.habit.id, 'h2');
    });

    test('12: "slept 11 to 6:30" is last night', () {
      final line = _parse('slept 11 to 6:30') as SleepLine;
      expect(line.bedTime, '23:00');
      expect(line.wakeTime, '06:30');
      expect([for (final (label, _) in line.chips) label], contains('7h 30m'));
    });

    test('13: "sleep 12:30am to 8" handles am', () {
      final line = _parse('sleep 12:30am to 8') as SleepLine;
      expect(line.bedTime, '00:30');
      expect(line.wakeTime, '08:00');
    });

    test('14: "focus write" starts focus on a task', () {
      final line = _parse('focus write') as FocusLine;
      expect(line.task.id, 't1');
    });

    test('15: "note meeting ideas" is a note', () {
      final line = _parse('note meeting ideas') as NoteLine;
      expect(line.text, 'Meeting ideas');
    });
  });

  group('the Inbox: nothing is lost', () {
    test('16: a plain thought goes to the Inbox', () {
      final line = _parse('maybe learn the guitar') as InboxLine;
      expect(line.text, 'maybe learn the guitar');
    });

    test('17: a distraction goes to the Inbox for now', () {
      expect(_parse('distracted 20 min by phone'), isA<InboxLine>());
    });

    test('18: a time block goes to the Inbox for now', () {
      expect(_parse('event review at 3pm'), isA<InboxLine>());
    });

    test('19: "focus" on an unknown task is not lost', () {
      expect(_parse('focus on something new'), isA<InboxLine>());
    });

    test('20: "slept" with impossible times is not lost', () {
      expect(_parse('slept 25 to 99'), isA<InboxLine>());
    });
  });
}
