import 'package:drift/drift.dart';

import '../local/app_database.dart';

/// Reads and writes the Inbox and the user's preferences. It only ever
/// touches the local database. Sync copies the changes to the server in the
/// background.
class CaptureRepository {
  CaptureRepository(
    this._db, {
    required this._newId,
    required this._stableId,
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now;

  final AppDatabase _db;
  final String Function() _newId;

  /// The same id for the same text on every device: the preferences row
  /// gets its id from the user, so there is one row per user.
  final String Function(String key) _stableId;
  final DateTime Function() _now;

  String _timestamp() => _now().toUtc().toIso8601String();

  // ---------------------------------------------------------------- inbox

  /// The user's Inbox, newest first. Removed items are left out.
  Stream<List<InboxItem>> watchInbox(String userId) {
    final query = _db.select(_db.inboxItems)
      ..where((row) => row.userId.equals(userId) & row.deletedAt.isNull())
      ..orderBy([(row) => OrderingTerm.desc(row.createdAt)]);
    return query.watch();
  }

  /// Puts a line in the Inbox and returns its id.
  Future<String> addToInbox({
    required String userId,
    required String text,
    String kind = InboxKind.inbox,
  }) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) {
      throw ArgumentError.value(text, 'text', 'Must not be empty');
    }
    if (kind != InboxKind.inbox && kind != InboxKind.note) {
      throw ArgumentError.value(kind, 'kind', 'Unknown kind');
    }
    final id = _newId();
    final timestamp = _timestamp();
    await _db
        .into(_db.inboxItems)
        .insert(
          InboxItemsCompanion.insert(
            id: id,
            userId: userId,
            body: trimmed,
            kind: kind,
            createdAt: timestamp,
            updatedAt: timestamp,
          ),
        );
    return id;
  }

  /// Removes an item from the Inbox (soft delete).
  Future<void> removeFromInbox(String id) {
    final timestamp = _timestamp();
    return (_db.update(
      _db.inboxItems,
    )..where((row) => row.id.equals(id))).write(
      InboxItemsCompanion(
        deletedAt: Value(timestamp),
        updatedAt: Value(timestamp),
      ),
    );
  }

  // ---------------------------------------------------------------- notes

  /// The user's notes, newest change first. Deleted ones are left out.
  Stream<List<Note>> watchNotes(String userId) {
    final query = _db.select(_db.notes)
      ..where((row) => row.userId.equals(userId) & row.deletedAt.isNull())
      ..orderBy([(row) => OrderingTerm.desc(row.updatedAt)]);
    return query.watch();
  }

  /// Adds a note and returns its id. A note needs a title or a body.
  Future<String> addNote({
    required String userId,
    String title = '',
    String body = '',
    String? projectId,
  }) async {
    if (title.trim().isEmpty && body.trim().isEmpty) {
      throw ArgumentError.value(title, 'title', 'A note needs some text');
    }
    final id = _newId();
    final timestamp = _timestamp();
    await _db
        .into(_db.notes)
        .insert(
          NotesCompanion.insert(
            id: id,
            userId: userId,
            title: title.trim(),
            body: body,
            projectId: Value(projectId),
            createdAt: timestamp,
            updatedAt: timestamp,
          ),
        );
    return id;
  }

  Future<void> updateNote(
    String id, {
    required String title,
    required String body,
    required String? projectId,
  }) {
    return (_db.update(_db.notes)..where((row) => row.id.equals(id))).write(
      NotesCompanion(
        title: Value(title.trim()),
        body: Value(body),
        projectId: Value(projectId),
        updatedAt: Value(_timestamp()),
      ),
    );
  }

  /// Removes a note (soft delete).
  Future<void> deleteNote(String id) {
    final timestamp = _timestamp();
    return (_db.update(_db.notes)..where((row) => row.id.equals(id))).write(
      NotesCompanion(
        deletedAt: Value(timestamp),
        updatedAt: Value(timestamp),
      ),
    );
  }

  // ---------------------------------------------------------- preferences

  /// The usual wake time and bedtime (`HH:MM`), null where not set.
  Stream<({String? wake, String? bed})> watchDayTimes(String userId) {
    final query = _db.select(_db.preferences)
      ..where((row) => row.userId.equals(userId) & row.deletedAt.isNull());
    return query.watch().map((rows) {
      final row = rows.firstOrNull;
      return (wake: row?.wakeTime, bed: row?.bedTime);
    });
  }

  Future<void> saveDayTimes({
    required String userId,
    required String? wake,
    required String? bed,
  }) {
    final id = _stableId('preferences:$userId');
    return _db.transaction(() async {
      final timestamp = _timestamp();
      final existing = await (_db.select(
        _db.preferences,
      )..where((row) => row.id.equals(id))).getSingleOrNull();
      if (existing == null) {
        await _db
            .into(_db.preferences)
            .insert(
              PreferencesCompanion.insert(
                id: id,
                userId: userId,
                todaySections: '',
                wakeTime: Value(wake),
                bedTime: Value(bed),
                createdAt: timestamp,
                updatedAt: timestamp,
              ),
            );
        return;
      }
      await (_db.update(
        _db.preferences,
      )..where((row) => row.id.equals(id))).write(
        PreferencesCompanion(
          wakeTime: Value(wake),
          bedTime: Value(bed),
          deletedAt: const Value(null),
          updatedAt: Value(timestamp),
        ),
      );
    });
  }

  /// The stored Today sections, or null before the user changed them.
  Stream<String?> watchTodaySections(String userId) {
    final query = _db.select(_db.preferences)
      ..where((row) => row.userId.equals(userId) & row.deletedAt.isNull());
    return query.watch().map((rows) => rows.firstOrNull?.todaySections);
  }

  Future<void> saveTodaySections({
    required String userId,
    required String sections,
  }) {
    final id = _stableId('preferences:$userId');
    return _db.transaction(() async {
      final timestamp = _timestamp();
      final existing = await (_db.select(
        _db.preferences,
      )..where((row) => row.id.equals(id))).getSingleOrNull();
      if (existing == null) {
        await _db
            .into(_db.preferences)
            .insert(
              PreferencesCompanion.insert(
                id: id,
                userId: userId,
                todaySections: sections,
                createdAt: timestamp,
                updatedAt: timestamp,
              ),
            );
        return;
      }
      await (_db.update(
        _db.preferences,
      )..where((row) => row.id.equals(id))).write(
        PreferencesCompanion(
          todaySections: Value(sections),
          deletedAt: const Value(null),
          updatedAt: Value(timestamp),
        ),
      );
    });
  }
}
