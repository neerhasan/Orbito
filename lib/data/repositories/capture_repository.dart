import 'package:drift/drift.dart';

import '../../domain/note_tree.dart';
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
      NotesCompanion(deletedAt: Value(timestamp), updatedAt: Value(timestamp)),
    );
  }

  // ----------------------------------------------------------- note pages

  Future<List<Note>> _livePages(String userId) => (_db.select(
    _db.notes,
  )..where((row) => row.userId.equals(userId) & row.deletedAt.isNull())).get();

  Future<void> _writePage(String id, NotesCompanion change) =>
      (_db.update(_db.notes)..where((row) => row.id.equals(id))).write(
        change.copyWith(updatedAt: Value(_timestamp())),
      );

  /// Adds an empty page at the end of [parentId]'s pages (or the top
  /// level) and returns its id. Pages may be untitled, as in Notion.
  Future<String> createPage({
    required String userId,
    String? parentId,
    String? projectId,
    String title = '',
  }) async {
    final id = _newId();
    final timestamp = _timestamp();
    final order = nextSortOrder(await _livePages(userId), parentId);
    await _db
        .into(_db.notes)
        .insert(
          NotesCompanion.insert(
            id: id,
            userId: userId,
            title: title.trim(),
            body: '',
            projectId: Value(projectId),
            parentId: Value(parentId),
            sortOrder: Value(order),
            createdAt: timestamp,
            updatedAt: timestamp,
          ),
        );
    return id;
  }

  /// Saves a page's title and blocks. [body] is the plain text of the
  /// blocks, kept for search and previews.
  Future<void> savePage(
    String id, {
    required String title,
    required String content,
    required String body,
  }) => _writePage(
    id,
    NotesCompanion(
      title: Value(title.trim()),
      content: Value(content),
      body: Value(body),
    ),
  );

  Future<void> setPageIcon(String id, String? icon) =>
      _writePage(id, NotesCompanion(icon: Value(icon)));

  Future<void> setPageCover(String id, String? cover) =>
      _writePage(id, NotesCompanion(cover: Value(cover)));

  Future<void> setFavorite(String id, {required bool favorite}) =>
      _writePage(id, NotesCompanion(favorite: Value(favorite ? 1 : 0)));

  Future<void> setPageProject(String id, String? projectId) =>
      _writePage(id, NotesCompanion(projectId: Value(projectId)));

  /// Moves a page inside [parentId] (null: the top level) at [sortOrder].
  /// A page cannot move inside itself or a page inside it.
  Future<void> movePage(
    String id, {
    required String userId,
    required String? parentId,
    required double sortOrder,
  }) async {
    if (!canMoveUnder(await _livePages(userId), id, parentId)) {
      throw ArgumentError.value(parentId, 'parentId', 'A page is inside it');
    }
    await _writePage(
      id,
      NotesCompanion(parentId: Value(parentId), sortOrder: Value(sortOrder)),
    );
  }

  /// Puts a page (and so the pages inside it) in the Trash.
  Future<void> trashPage(String id) =>
      _writePage(id, NotesCompanion(trashedAt: Value(_timestamp())));

  /// Takes a page out of the Trash. When the page it sat inside is still
  /// in the Trash, it comes back at the top level.
  Future<void> restorePage(String id, {required String userId}) async {
    final pages = await _livePages(userId);
    final byId = pagesById(pages);
    final parent = byId[id]?.parentId;
    final parentHidden = parent != null && isHidden(byId, parent);
    await _writePage(
      id,
      NotesCompanion(
        trashedAt: const Value(null),
        parentId: parentHidden ? const Value(null) : const Value.absent(),
      ),
    );
  }

  /// Deletes a page and every page inside it for good (soft delete, so
  /// the deletion syncs).
  Future<void> deleteForever(String id, {required String userId}) async {
    final ids = {id, ...descendantsOf(await _livePages(userId), id)};
    final timestamp = _timestamp();
    await (_db.update(_db.notes)..where((row) => row.id.isIn(ids))).write(
      NotesCompanion(deletedAt: Value(timestamp), updatedAt: Value(timestamp)),
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

  /// The daily focus goal in minutes, or null before the user picked one.
  Stream<int?> watchFocusGoal(String userId) {
    final query = _db.select(_db.preferences)
      ..where((row) => row.userId.equals(userId) & row.deletedAt.isNull());
    return query.watch().map((rows) => rows.firstOrNull?.focusGoalMinutes);
  }

  Future<void> saveFocusGoal({required String userId, required int minutes}) {
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
                focusGoalMinutes: Value(minutes),
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
          focusGoalMinutes: Value(minutes),
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
