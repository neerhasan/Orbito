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
    expect(readSections('tasks,greeting,unknown,tasks'), [
      TodaySection.tasks,
      TodaySection.greeting,
    ]);
    expect(
      writeSections(const [TodaySection.sleep, TodaySection.goals]),
      'sleep,goals',
    );
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
