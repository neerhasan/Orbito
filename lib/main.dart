import 'package:drift_sqlite_async/drift_sqlite_async.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app/app.dart';
import 'app/env.dart';
import 'app/providers.dart';
import 'app/theme_mode.dart';
import 'ui/ember.dart';
import 'data/local/app_database.dart';
import 'data/sync/sync_service.dart';
import 'ui/window_frame.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // The light or dark theme this device chose last time.
  Ember.useDark(await loadThemeChoice());
  // Windows: Orbito's dark top bar replaces the system title bar.
  setUpWindow();

  final env = await AppEnv.load();
  if (!env.isComplete) {
    runApp(SetupNeededApp(missing: env.missing));
    return;
  }

  await Supabase.initialize(
    url: env.supabaseUrl,
    publishableKey: env.supabasePublishableKey,
  );
  final supabase = Supabase.instance.client;

  final powerSync = await openPowerSyncDatabase();
  final database = AppDatabase(SqliteAsyncDriftConnection(powerSync));
  final syncService = SyncService(
    powerSync: powerSync,
    supabase: supabase,
    powerSyncUrl: env.powerSyncUrl,
  );

  // Start syncing whenever a user is signed in: at start-up if a saved
  // sign-in exists, and again after each new sign-in.
  supabase.auth.onAuthStateChange.listen((change) {
    final signedIn = change.session != null;
    final starts =
        change.event == AuthChangeEvent.initialSession ||
        change.event == AuthChangeEvent.signedIn;
    if (signedIn && starts) syncService.connect();
  });

  runApp(
    ProviderScope(
      overrides: [
        supabaseProvider.overrideWithValue(supabase),
        powerSyncProvider.overrideWithValue(powerSync),
        syncServiceProvider.overrideWithValue(syncService),
        appDatabaseProvider.overrideWithValue(database),
      ],
      child: const OrbitoApp(),
    ),
  );
}
