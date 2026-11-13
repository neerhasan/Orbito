import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbito/app/app.dart';
import 'package:orbito/app/providers.dart';
import 'package:orbito/app/shell.dart';
import 'package:orbito/data/local/app_database.dart';
import 'package:orbito/data/sync/sync_status_text.dart';
import 'package:orbito/ui/ember.dart';

const _area = LifeArea(
  id: 'area-1',
  userId: 'user-a',
  name: 'Health',
  color: 'green',
  createdAt: '2026-11-11T10:00:00.000Z',
  updatedAt: '2026-11-11T10:00:00.000Z',
);

/// The app frame with made-up data, at the size of a desktop window.
Future<void> _pumpShell(
  WidgetTester tester, {
  List<LifeArea> areas = const [],
  SyncStatusText status = const SyncStatusText('Synced'),
}) async {
  tester.view.physicalSize = const Size(1280, 800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        lifeAreasProvider.overrideWith((ref) => Stream.value(areas)),
        focusTimerProvider.overrideWith((ref) => Stream.value(null)),
        tasksProvider.overrideWith((ref) => Stream.value(const <Task>[])),
        habitsProvider.overrideWith((ref) => Stream.value(const <Habit>[])),
        habitLogsProvider.overrideWith(
          (ref) => Stream.value(const <HabitLog>[]),
        ),
        syncStatusTextProvider.overrideWithValue(status),
      ],
      child: MaterialApp(
        theme: Ember.theme(),
        home: AppShell(
          email: 'a@example.com',
          pageBuilder: (page) => Text('page: ${page.name}'),
        ),
      ),
    ),
  );
  await tester.pump();
}

void main() {
  testWidgets('the setup screen names the missing values', (tester) async {
    await tester.pumpWidget(
      const SetupNeededApp(missing: ['SUPABASE_URL', 'POWERSYNC_URL']),
    );

    expect(find.text('Orbito is not set up yet'), findsOneWidget);
    expect(find.textContaining('SUPABASE_URL'), findsOneWidget);
    expect(find.textContaining('POWERSYNC_URL'), findsOneWidget);
  });

  group('the app frame', () {
    testWidgets('opens on Today and shows the menu, email and sync status', (
      tester,
    ) async {
      await _pumpShell(
        tester,
        status: const SyncStatusText(
          'Offline',
          detail: '1 change waiting to upload',
        ),
      );

      expect(find.text('page: today'), findsOneWidget);
      expect(find.text('Tasks'), findsOneWidget);
      expect(find.text('Projects'), findsOneWidget);
      expect(find.text('Goals'), findsOneWidget);
      expect(find.text('Orbito'), findsOneWidget);
      expect(find.text('A'), findsOneWidget);
      expect(find.text('Sync: Offline'), findsOneWidget);
      expect(find.text('1 change waiting to upload'), findsOneWidget);
      expect(find.byKey(const Key('search')), findsOneWidget);

      // The account button shows the email and signs out.
      await tester.tap(find.byKey(const Key('account-menu')));
      await tester.pumpAndSettle();
      expect(find.text('a@example.com'), findsOneWidget);
      expect(find.byKey(const Key('sign-out')), findsOneWidget);
    });

    testWidgets('a menu item opens its page', (tester) async {
      await _pumpShell(tester);

      await tester.tap(find.byKey(const Key('menu-goals')));
      await tester.pump();
      expect(find.text('page: goals'), findsOneWidget);

      await tester.tap(find.byKey(const Key('menu-areas')));
      await tester.pump();
      expect(find.text('page: areas'), findsOneWidget);
    });

    testWidgets('pages cross-fade softly instead of jumping', (tester) async {
      await _pumpShell(tester);

      await tester.tap(find.byKey(const Key('menu-goals')));
      await tester.pump(const Duration(milliseconds: 100));
      // Halfway through, the old page is fading out as the new one arrives.
      expect(find.text('page: today'), findsOneWidget);
      expect(find.text('page: goals'), findsOneWidget);

      await tester.pumpAndSettle();
      expect(find.text('page: today'), findsNothing);
      expect(find.text('page: goals'), findsOneWidget);
    });

    testWidgets('with no life areas the menu invites the first one', (
      tester,
    ) async {
      await _pumpShell(tester);
      expect(find.text('Add your first area'), findsOneWidget);
    });

    testWidgets('life areas are listed in the menu', (tester) async {
      await _pumpShell(tester, areas: const [_area]);
      expect(find.text('Health'), findsOneWidget);
    });
  });
}
