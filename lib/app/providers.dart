import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:powersync/powersync.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../data/local/app_database.dart';
import '../data/repositories/plan_repository.dart';
import '../data/repositories/task_repository.dart';
import '../data/sync/sync_service.dart';
import '../data/sync/sync_status_text.dart';

/// These are created in `main()` and handed in when the app starts.
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

final planRepositoryProvider = Provider<PlanRepository>(
  (ref) =>
      PlanRepository(ref.watch(appDatabaseProvider), newId: () => uuid.v4()),
);

final taskRepositoryProvider = Provider<TaskRepository>(
  (ref) =>
      TaskRepository(ref.watch(appDatabaseProvider), newId: () => uuid.v4()),
);

/// The signed-in user, or null when nobody is signed in.
final currentUserProvider = StreamProvider<User?>((ref) async* {
  final auth = ref.watch(supabaseProvider).auth;
  yield auth.currentUser;
  await for (final change in auth.onAuthStateChange) {
    yield change.session?.user;
  }
});

/// The id of the signed-in user, or null.
final userIdProvider = Provider<String?>(
  (ref) => ref.watch(currentUserProvider).value?.id,
);

// The signed-in user's data, read from the local database. The screens use
// only these, never the network.

final lifeAreasProvider = StreamProvider<List<LifeArea>>((ref) {
  final userId = ref.watch(userIdProvider);
  if (userId == null) return Stream.value(const []);
  return ref.watch(planRepositoryProvider).watchAreas(userId);
});

final goalsProvider = StreamProvider<List<Goal>>((ref) {
  final userId = ref.watch(userIdProvider);
  if (userId == null) return Stream.value(const []);
  return ref.watch(planRepositoryProvider).watchGoals(userId);
});

final projectsProvider = StreamProvider<List<Project>>((ref) {
  final userId = ref.watch(userIdProvider);
  if (userId == null) return Stream.value(const []);
  return ref.watch(planRepositoryProvider).watchProjects(userId);
});

final tasksProvider = StreamProvider<List<Task>>((ref) {
  final userId = ref.watch(userIdProvider);
  if (userId == null) return Stream.value(const []);
  return ref.watch(taskRepositoryProvider).watchTasks(userId);
});

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

/// True once this device has downloaded the user's data at least once.
/// Until then an empty list may only mean "not downloaded yet".
final firstSyncDoneProvider = Provider<bool>((ref) {
  final status =
      ref.watch(_rawSyncStatusProvider).value ??
      ref.watch(powerSyncProvider).currentStatus;
  return status.hasSynced ?? false;
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
