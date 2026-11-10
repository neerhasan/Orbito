import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:powersync/powersync.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../data/local/app_database.dart';
import '../data/repositories/sync_test_repository.dart';
import '../data/sync/sync_service.dart';
import '../data/sync/sync_status_text.dart';

/// These three are created in `main()` and handed in when the app starts.
final supabaseProvider = Provider<SupabaseClient>(
  (ref) => throw UnimplementedError('Set in main()'),
);
final powerSyncProvider = Provider<PowerSyncDatabase>(
  (ref) => throw UnimplementedError('Set in main()'),
);
final syncServiceProvider = Provider<SyncService>(
  (ref) => throw UnimplementedError('Set in main()'),
);
final appDatabaseProvider = Provider<AppDatabase>(
  (ref) => throw UnimplementedError('Set in main()'),
);

final syncTestRepositoryProvider = Provider<SyncTestRepository>(
  (ref) => SyncTestRepository(
    ref.watch(appDatabaseProvider),
    newId: () => uuid.v4(),
  ),
);

/// The signed-in user, or null when nobody is signed in.
final currentUserProvider = StreamProvider<User?>((ref) async* {
  final auth = ref.watch(supabaseProvider).auth;
  yield auth.currentUser;
  await for (final change in auth.onAuthStateChange) {
    yield change.session?.user;
  }
});

/// The signed-in user's test rows, read from the local database.
final syncTestRowsProvider = StreamProvider.family<List<SyncTestRow>, String>(
  (ref, userId) => ref.watch(syncTestRepositoryProvider).watchRows(userId),
);

/// How many local changes have not reached the server yet.
final pendingUploadsProvider = StreamProvider<int>((ref) {
  return ref
      .watch(powerSyncProvider)
      .watch('SELECT count(*) AS pending FROM ps_crud')
      .map((rows) => rows.first['pending'] as int);
});

final _rawSyncStatusProvider = StreamProvider<SyncStatus>((ref) async* {
  final powerSync = ref.watch(powerSyncProvider);
  yield powerSync.currentStatus;
  yield* powerSync.statusStream;
});

/// The words for the sync status line.
final syncStatusTextProvider = Provider<SyncStatusText>((ref) {
  final status =
      ref.watch(_rawSyncStatusProvider).value ??
      ref.watch(powerSyncProvider).currentStatus;
  final pending = ref.watch(pendingUploadsProvider).value ?? 0;
  final error = status.downloadError ?? status.uploadError;
  return describeSyncStatus(
    connected: status.connected,
    connecting: status.connecting,
    transferring: status.downloading || status.uploading,
    hasSyncedBefore: status.hasSynced ?? false,
    pendingUploads: pending,
    lastSyncedAt: status.lastSyncedAt,
    error: error?.toString(),
  );
});
