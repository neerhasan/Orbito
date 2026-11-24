import 'package:flutter_test/flutter_test.dart';
import 'package:orbito/domain/today.dart';

void main() {
  test('no choice yet shows every section; "none" shows nothing', () {
    expect(readSections(null), defaultSections);
    expect(readSections(''), defaultSections);
    expect(readSections(writeSections(const [])), isEmpty);
  });

  test('the stored text keeps the order and drops unknown or repeated '
      'names', () {
    expect(readSections('tasks,greeting,unknown,tasks,-schedule'), [
      TodaySection.tasks,
      TodaySection.greeting,
    ]);
    expect(
      writeSections(const [TodaySection.sleep, TodaySection.goals]),
      'sleep,goals,-schedule',
    );
  });

  test('the Schedule shows up by itself after the greeting until it is '
      'switched off', () {
    // A choice saved before the Schedule existed.
    expect(readSections('greeting,habits,tasks'), [
      TodaySection.greeting,
      TodaySection.schedule,
      TodaySection.habits,
      TodaySection.tasks,
    ]);
    final off = toggleSection(
      readSections('greeting,habits'),
      TodaySection.schedule,
    );
    expect(readSections(writeSections(off)), [
      TodaySection.greeting,
      TodaySection.habits,
    ]);
  });

  test('Time today and Schedule are on the right; the rest in the main '
      'panel', () {
    final side = [
      for (final section in defaultSections)
        if (section.column == TodayColumn.side) section,
    ];
    expect(side, [TodaySection.time, TodaySection.schedule]);
  });

  test('a section is switched off, and back on at the end', () {
    final off = toggleSection(defaultSections, TodaySection.greeting);
    expect(off.contains(TodaySection.greeting), isFalse);
    final on = toggleSection(off, TodaySection.greeting);
    expect(on.last, TodaySection.greeting);
  });

  test('moving stays inside the section\'s own panel', () {
    final moved = moveSection(defaultSections, TodaySection.habits, -1);
    final main = moved.where((s) => s.column == TodayColumn.main).toList();
    expect(main.take(2), [TodaySection.habits, TodaySection.greeting]);
    // The first one cannot move further up.
    expect(moveSection(moved, TodaySection.habits, -1), moved);
  });

  test('the greeting follows the time of day', () {
    expect(greetingFor(DateTime(2026, 11, 13, 8)), 'Good morning');
    expect(greetingFor(DateTime(2026, 11, 13, 14)), 'Good afternoon');
    expect(greetingFor(DateTime(2026, 11, 13, 21)), 'Good evening');
  });
}
