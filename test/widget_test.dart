import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbito/app/app.dart';
import 'package:orbito/app/providers.dart';
import 'package:orbito/data/local/app_database.dart';
import 'package:orbito/data/sync/sync_status_text.dart';
import 'package:orbito/features/sync_test/sync_test_screen.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  testWidgets('the setup screen names the missing values', (tester) async {
    await tester.pumpWidget(
      const SetupNeededApp(missing: ['SUPABASE_URL', 'POWERSYNC_URL']),
    );

    expect(find.text('Orbito is not set up yet'), findsOneWidget);
    expect(find.textContaining('SUPABASE_URL'), findsOneWidget);
    expect(find.textContaining('POWERSYNC_URL'), findsOneWidget);
  });

  testWidgets('the test screen shows rows, the add box and the sync status', (
    tester,
  ) async {
    const user = User(
      id: 'user-a',
      appMetadata: {},
      userMetadata: {},
      aud: 'authenticated',
      email: 'a@example.com',
      createdAt: '2026-11-11T00:00:00.000Z',
    );
    const row = SyncTestRow(
      id: 'id-1',
      userId: 'user-a',
      body: 'hello from the phone',
      createdAt: '2026-11-11T10:00:00.000Z',
      updatedAt: '2026-11-11T10:00:00.000Z',
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          syncTestRowsProvider('user-a').overrideWith(
            (ref) => Stream.value([row]),
          ),
          syncStatusTextProvider.overrideWithValue(
            const SyncStatusText('Offline', detail: '1 change waiting to upload'),
          ),
        ],
        child: const MaterialApp(home: SyncTestScreen(user: user)),
      ),
    );
    await tester.pump();

    expect(find.text('hello from the phone'), findsOneWidget);
    expect(find.text('Sync: Offline'), findsOneWidget);
    expect(find.text('1 change waiting to upload'), findsOneWidget);
    expect(find.text('Signed in as a@example.com'), findsOneWidget);
    expect(find.byKey(const Key('new-row-text')), findsOneWidget);
    expect(find.byKey(const Key('add-row')), findsOneWidget);
  });
}
