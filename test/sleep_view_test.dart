import 'package:flutter_test/flutter_test.dart';
import 'package:orbito/data/local/app_database.dart';
import 'package:orbito/domain/sleep_view.dart';

SleepLog _night(String day, String bed, String wake) => SleepLog(
  id: day,
  userId: 'u',
  day: day,
  bedTime: bed,
  wakeTime: wake,
  createdAt: '',
  updatedAt: '',
);

void main() {
  const today = '2026-11-20'; // Friday

  test('weeks run Monday to Sunday; months and years are whole', () {
    expect(sleepRange(SleepView.week, today), (
      start: '2026-11-16',
      end: '2026-11-22',
    ));
    expect(sleepRange(SleepView.month, today), (
      start: '2026-11-01',
      end: '2026-11-30',
    ));
    expect(sleepRange(SleepView.year, today), (
      start: '2026-01-01',
      end: '2026-12-31',
    ));
    expect(shiftSleepAnchor(SleepView.week, today, -1), '2026-11-13');
    expect(shiftSleepAnchor(SleepView.month, '2026-01-31', -1), '2025-12-01');
    expect(shiftSleepAnchor(SleepView.year, today, 1), '2027-01-01');
  });

  test('names the period like the Sleep log app', () {
    String week(String day) =>
        sleepPeriodLabel(SleepView.week, sleepRange(SleepView.week, day));
    expect(week(today), 'Nov 16 to 22, 2026');
    expect(week('2026-10-28'), 'Oct 26 to Nov 1, 2026');
    expect(week('2026-12-30'), 'Dec 28, 2026 to Jan 3, 2027');
    expect(
      sleepPeriodLabel(SleepView.month, sleepRange(SleepView.month, today)),
      'November 2026',
    );
    expect(
      sleepPeriodLabel(SleepView.year, sleepRange(SleepView.year, today)),
      '2026',
    );
  });

  test('the goal is the time between the Settings bedtime and wake time', () {
    expect(sleepGoal(), 8 * 60);
    expect(sleepGoal(bed: '22:30', wake: '06:00'), 7 * 60 + 30);
    expect(sleepGoal(bed: '07:00', wake: '07:00'), 8 * 60);
  });

  test('colours a night by how far it was from the goal', () {
    expect(severity(480, 480), 0);
    expect(severity(500, 480), 0);
    expect(severity(420, 480), 1);
    expect(severity(419, 480), 2);
    expect(severity(360, 480), 2);
    expect(severity(359, 480), 3);
    expect(goalGap(480, 480), 'goal met');
    expect(goalGap(410, 480), '1h 10m short');
  });

  test('times sit on a line that starts at 3 PM', () {
    expect(axisMinutes('15:00'), 0);
    expect(axisMinutes('23:00'), 8 * 60);
    expect(axisMinutes('07:00'), 16 * 60);
    expect(axisClock(8 * 60), '11:00 PM');
    expect(axisClock(16 * 60 + 30), '7:30 AM');
  });

  test('the numbers of a range', () {
    final nights = [
      _night('2026-11-19', '23:00', '07:00'), // 8h
      _night('2026-11-20', '00:00', '06:00'), // 6h
      _night('2026-11-02', '23:00', '07:00'), // another week
    ];
    final week = nightsIn(nights, sleepRange(SleepView.week, today));
    final stats = sleepStats(week, 480)!;
    expect(stats.count, 2);
    expect(stats.average, 420);
    expect(stats.atGoal, 1);
    expect(stats.rate, 0.5);
    expect(axisClock(stats.bed), '11:30 PM');
    expect(axisClock(stats.wake), '6:30 AM');
    expect(stats.spread, 30);
    expect(stats.shortest, 360);
    expect(stats.longest, 480);
    expect(sleepStats(const [], 480), isNull);
  });

  test('changes against an earlier period say if they are good news', () {
    expect(sleepChange(450, 420), (text: 'Up 30m', tone: Tone.good));
    expect(sleepChange(420, 480), (text: 'Down 1h', tone: Tone.bad));
    expect(sleepChange(420, 420.3), (text: 'No change', tone: Tone.flat));
    expect(rateChange(0.75, 0.5), (text: 'Up 25 points', tone: Tone.good));
    // Target 11 PM (480 after 3 PM): from 12 AM to 11:30 PM is good news.
    expect(timeChange(510, 540, target: 480), (
      text: '30m earlier',
      tone: Tone.good,
    ));
    expect(timeChange(540, 510, target: 480), (
      text: '30m later',
      tone: Tone.bad,
    ));
  });

  test('the earlier periods are the full week, month and year before', () {
    final ranges = earlierRanges(today);
    expect(ranges.map((range) => range.$1), [
      'Last week',
      'Last month',
      'Last year',
    ]);
    expect(ranges[0].$2, (start: '2026-11-09', end: '2026-11-15'));
    expect(ranges[1].$2, (start: '2026-10-01', end: '2026-10-31'));
    expect(ranges[2].$2, (start: '2025-01-01', end: '2025-12-31'));
  });

  test('tracks the started days of a range, newest first', () {
    expect(trackedDays(sleepRange(SleepView.week, today), today), [
      '2026-11-20',
      '2026-11-19',
      '2026-11-18',
      '2026-11-17',
      '2026-11-16',
    ]);
    expect(
      trackedDays(sleepRange(SleepView.week, '2026-11-10'), today).length,
      7,
    );
  });
}
