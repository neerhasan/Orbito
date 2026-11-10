import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbito/data/local/app_database.dart';
import 'package:orbito/data/repositories/sync_test_repository.dart';

void main() {
  late AppDatabase db;
  late SyncTestRepository repository;
  late int counter;

  setUp(() {
    counter = 0;
    db = AppDatabase(NativeDatabase.memory(), tablesManagedBySync: false);
    repository = SyncTestRepository(
      db,
      newId: () => 'id-${++counter}',
      now: () => DateTime.utc(2026, 11, 11, 10, 0, counter),
    );
  });

  tearDown(() => db.close());

  test('a new row is saved with a UTC time and no delete mark', () async {
    final id = await repository.addRow(userId: 'user-a', text: '  hello  ');

    final rows = await repository.watchRows('user-a').first;
    expect(id, 'id-1');
    expect(rows, hasLength(1));
    expect(rows.single.id, 'id-1');
    expect(rows.single.userId, 'user-a');
    expect(rows.single.body, 'hello');
    expect(rows.single.createdAt, '2026-11-11T10:00:01.000Z');
    expect(rows.single.updatedAt, '2026-11-11T10:00:01.000Z');
    expect(rows.single.deletedAt, isNull);
  });

  test('rows come back newest first', () async {
    await repository.addRow(userId: 'user-a', text: 'first');
    await repository.addRow(userId: 'user-a', text: 'second');

    final rows = await repository.watchRows('user-a').first;
    expect(rows.map((row) => row.body), ['second', 'first']);
  });

  test('a user never sees another user\'s rows', () async {
    await repository.addRow(userId: 'user-a', text: 'private to a');
    await repository.addRow(userId: 'user-b', text: 'private to b');

    final rowsForA = await repository.watchRows('user-a').first;
    final rowsForB = await repository.watchRows('user-b').first;
    expect(rowsForA.map((row) => row.body), ['private to a']);
    expect(rowsForB.map((row) => row.body), ['private to b']);
  });

  test('rows marked as deleted are hidden', () async {
    final id = await repository.addRow(userId: 'user-a', text: 'gone');
    await repository.addRow(userId: 'user-a', text: 'kept');

    await (db.update(db.syncTestRows)..where((row) => row.id.equals(id))).write(
      const SyncTestRowsCompanion(deletedAt: Value('2026-11-11T11:00:00.000Z')),
    );

    final rows = await repository.watchRows('user-a').first;
    expect(rows.map((row) => row.body), ['kept']);
  });

  test('empty text is refused and nothing is saved', () async {
    await expectLater(
      repository.addRow(userId: 'user-a', text: '   '),
      throwsArgumentError,
    );
    expect(await repository.watchRows('user-a').first, isEmpty);
  });

  test('the list updates by itself when a row is added', () async {
    final updates = repository.watchRows('user-a').map((rows) => rows.length);
    final seen = expectLater(updates, emitsInOrder([0, 1]));
    await pumpEventQueue();
    await repository.addRow(userId: 'user-a', text: 'live');
    await seen;
  });
}
