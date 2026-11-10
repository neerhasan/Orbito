import 'package:drift/drift.dart';

import '../local/app_database.dart';

/// Reads and writes the M0 test rows. It only ever touches the local
/// database. Sync copies the changes to the server in the background.
class SyncTestRepository {
  SyncTestRepository(
    this._db, {
    required this._newId,
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now;

  final AppDatabase _db;
  final String Function() _newId;
  final DateTime Function() _now;

  /// The signed-in user's rows, newest first. Deleted rows are left out.
  Stream<List<SyncTestRow>> watchRows(String userId) {
    final query = _db.select(_db.syncTestRows)
      ..where((row) => row.userId.equals(userId) & row.deletedAt.isNull())
      ..orderBy([(row) => OrderingTerm.desc(row.createdAt)]);
    return query.watch();
  }

  /// Saves a new row on the device and returns its id.
  Future<String> addRow({required String userId, required String text}) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) {
      throw ArgumentError.value(text, 'text', 'The text must not be empty');
    }
    final id = _newId();
    // The device time is only a placeholder. The server replaces
    // `updated_at` with its own time when the row is uploaded.
    final timestamp = _now().toUtc().toIso8601String();
    await _db
        .into(_db.syncTestRows)
        .insert(
          SyncTestRowsCompanion.insert(
            id: id,
            userId: userId,
            body: trimmed,
            createdAt: timestamp,
            updatedAt: timestamp,
          ),
        );
    return id;
  }
}
