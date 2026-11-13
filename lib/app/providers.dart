import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:powersync/powersync.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../data/local/app_database.dart';
import '../data/repositories/capture_repository.dart';
import '../data/repositories/focus_repository.dart';
import '../data/repositories/habit_repository.dart';
import '../data/repositories/plan_repository.dart';
import '../data/repositories/sleep_repository.dart';
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

/// A fixed namespace for ids made from text (UUID version 5): the same text
/// gives the same id on every device. Never change it, or rows made before
/// the change get new ids.
const _orbitoNamespace = '0f1c6a52-5d8e-4b3a-9c7e-2b6f4e1d8a90';

String stableId(String key) => uuid.v5(_orbitoNamespace, key);

final habitRepositoryProvider = Provider<HabitRepository>(
  (ref) => HabitRepository(
    ref.watch(appDatabaseProvider),
    newId: () => uuid.v4(),
    stableId: stableId,
  ),
);

final sleepRepositoryProvider = Provider<SleepRepository>(
  (ref) => SleepRepository(ref.watch(appDatabaseProvider), stableId: stableId),
);

final focusRepositoryProvider = Provider<FocusRepository>(
  (ref) =>
      FocusRepository(ref.watch(appDatabaseProvider), newId: () => uuid.v4()),
);

/// The current time. The screens ask this instead of the system clock, so
/// tests can set the day.
final clockProvider = Provider<DateTime Function()>((ref) => DateTime.now);

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

final habitsProvider = StreamProvider<List<Habit>>((ref) {
  final userId = ref.watch(userIdProvider);
  if (userId == null) return Stream.value(const []);
  return ref.watch(habitRepositoryProvider).watchHabits(userId);
});

final habitLogsProvider = StreamProvider<List<HabitLog>>((ref) {
  final userId = ref.watch(userIdProvider);
  if (userId == null) return Stream.value(const []);
  return ref.watch(habitRepositoryProvider).watchLogs(userId);
});

final sleepLogsProvider = StreamProvider<List<SleepLog>>((ref) {
  final userId = ref.watch(userIdProvider);
  if (userId == null) return Stream.value(const []);
  return ref.watch(sleepRepositoryProvider).watchNights(userId);
});

final focusSessionsProvider = StreamProvider<List<FocusSession>>((ref) {
  final userId = ref.watch(userIdProvider);
  if (userId == null) return Stream.value(const []);
  return ref.watch(focusRepositoryProvider).watchSessions(userId);
});

final captureRepositoryProvider = Provider<CaptureRepository>(
  (ref) => CaptureRepository(
    ref.watch(appDatabaseProvider),
    newId: () => uuid.v4(),
    stableId: stableId,
  ),
);

/// The Inbox, newest first.
final inboxProvider = StreamProvider<List<InboxItem>>((ref) {
  final userId = ref.watch(userIdProvider);
  if (userId == null) return Stream.value(const []);
  return ref.watch(captureRepositoryProvider).watchInbox(userId);
});

/// The stored choice of Today sections, or null before the user made one.
final todaySectionsProvider = StreamProvider<String?>((ref) {
  final userId = ref.watch(userIdProvider);
  if (userId == null) return Stream.value(null);
  return ref.watch(captureRepositoryProvider).watchTodaySections(userId);
});

/// The focus timer running on this device, or null.
final focusTimerProvider = StreamProvider<FocusTimer?>((ref) {
  final userId = ref.watch(userIdProvider);
  if (userId == null) return Stream.value(null);
  return ref.watch(focusRepositoryProvider).watchTimer(userId);
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
