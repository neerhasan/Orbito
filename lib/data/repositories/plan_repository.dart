import 'package:drift/drift.dart';

import '../local/app_database.dart';

/// What happens to the items linked to something that is being deleted.
enum LinkedItems {
  /// Keep them and remove the link.
  keep,

  /// Delete them too, with everything linked to them.
  delete,
}

/// Thrown when a name is already used by another item of the same kind.
class DuplicateNameException implements Exception {
  const DuplicateNameException(this.name);

  final String name;

  @override
  String toString() => 'The name "$name" is already used.';
}

/// Reads and writes life areas, goals and projects (the chain life area,
/// goal, project). It only ever touches the local database. Sync copies the
/// changes to the server in the background.
class PlanRepository {
  PlanRepository(this._db, {required this._newId, DateTime Function()? now})
    : _now = now ?? DateTime.now;

  final AppDatabase _db;
  final String Function() _newId;
  final DateTime Function() _now;

  String _timestamp() => _now().toUtc().toIso8601String();

  static String _required(String value, String field) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) {
      throw ArgumentError.value(value, field, 'Must not be empty');
    }
    return trimmed;
  }

  static String? _optional(String? value) {
    final trimmed = value?.trim() ?? '';
    return trimmed.isEmpty ? null : trimmed;
  }

  /// For optional settings on update: null keeps the saved value, an empty
  /// text clears it, anything else replaces it.
  static Value<String?> _change(String? value) =>
      value == null ? const Value.absent() : Value(_optional(value));

  // ---------------------------------------------------------------- areas

  /// The user's life areas, oldest first. Deleted ones are left out.
  Stream<List<LifeArea>> watchAreas(String userId) {
    final query = _db.select(_db.lifeAreas)
      ..where((row) => row.userId.equals(userId) & row.deletedAt.isNull())
      ..orderBy([(row) => OrderingTerm.asc(row.createdAt)]);
    return query.watch();
  }

  /// Throws [DuplicateNameException] when the user already has a life area
  /// with this name. Capital letters and spaces around the name do not
  /// make a name different.
  Future<void> _checkAreaNameIsFree(
    String userId,
    String name, {
    String? exceptId,
  }) async {
    final areas =
        await (_db.select(_db.lifeAreas)..where(
              (row) => row.userId.equals(userId) & row.deletedAt.isNull(),
            ))
            .get();
    final wanted = name.toLowerCase();
    final taken = areas.any(
      (area) => area.id != exceptId && area.name.trim().toLowerCase() == wanted,
    );
    if (taken) throw DuplicateNameException(name);
  }

  /// Saves a new life area and returns its id. A name can be used once:
  /// a second area with the same name throws [DuplicateNameException].
  Future<String> addArea({
    required String userId,
    required String name,
    required String color,
    String? icon,
  }) async {
    final trimmed = _required(name, 'name');
    return _db.transaction(() async {
      await _checkAreaNameIsFree(userId, trimmed);
      final id = _newId();
      final timestamp = _timestamp();
      await _db
          .into(_db.lifeAreas)
          .insert(
            LifeAreasCompanion.insert(
              id: id,
              userId: userId,
              name: trimmed,
              color: color,
              icon: Value(_optional(icon)),
              createdAt: timestamp,
              updatedAt: timestamp,
            ),
          );
      return id;
    });
  }

  /// Renaming to the name of another area throws [DuplicateNameException].
  /// [icon]: null keeps the saved icon, an empty text removes it.
  Future<void> updateArea(
    String id, {
    required String name,
    required String color,
    String? icon,
  }) async {
    final trimmed = _required(name, 'name');
    return _db.transaction(() async {
      final area = await (_db.select(
        _db.lifeAreas,
      )..where((row) => row.id.equals(id))).getSingleOrNull();
      if (area == null) return;
      await _checkAreaNameIsFree(area.userId, trimmed, exceptId: id);
      await (_db.update(
        _db.lifeAreas,
      )..where((row) => row.id.equals(id))).write(
        LifeAreasCompanion(
          name: Value(trimmed),
          color: Value(color),
          icon: _change(icon),
          updatedAt: Value(_timestamp()),
        ),
      );
    });
  }

  /// How many goals belong to this life area.
  Future<int> countGoalsOfArea(String areaId) async {
    final goals = await _goalIdsOfArea(areaId);
    return goals.length;
  }

  Future<void> deleteArea(String id, {required LinkedItems linked}) {
    return _db.transaction(() async {
      final timestamp = _timestamp();
      final goalIds = await _goalIdsOfArea(id);
      if (linked == LinkedItems.delete) {
        for (final goalId in goalIds) {
          await _deleteGoal(goalId, LinkedItems.delete, timestamp);
        }
      } else if (goalIds.isNotEmpty) {
        await (_db.update(
          _db.goals,
        )..where((row) => row.id.isIn(goalIds))).write(
          GoalsCompanion(
            lifeAreaId: const Value(null),
            updatedAt: Value(timestamp),
          ),
        );
      }
      await (_db.update(
        _db.lifeAreas,
      )..where((row) => row.id.equals(id))).write(
        LifeAreasCompanion(
          deletedAt: Value(timestamp),
          updatedAt: Value(timestamp),
        ),
      );
    });
  }

  Future<List<String>> _goalIdsOfArea(String areaId) {
    final query = _db.selectOnly(_db.goals)
      ..addColumns([_db.goals.id])
      ..where(
        _db.goals.lifeAreaId.equals(areaId) & _db.goals.deletedAt.isNull(),
      );
    return query.map((row) => row.read(_db.goals.id)!).get();
  }

  // ---------------------------------------------------------------- goals

  /// The user's goals, oldest first. Deleted ones are left out.
  Stream<List<Goal>> watchGoals(String userId) {
    final query = _db.select(_db.goals)
      ..where((row) => row.userId.equals(userId) & row.deletedAt.isNull())
      ..orderBy([(row) => OrderingTerm.asc(row.createdAt)]);
    return query.watch();
  }

  Future<String> addGoal({
    required String userId,
    required String title,
    String? lifeAreaId,
    String? targetDate,
    String? doneWhen,
    String? color,
    String? icon,
  }) async {
    final id = _newId();
    final timestamp = _timestamp();
    await _db
        .into(_db.goals)
        .insert(
          GoalsCompanion.insert(
            id: id,
            userId: userId,
            title: _required(title, 'title'),
            lifeAreaId: Value(lifeAreaId),
            targetDate: Value(targetDate),
            doneWhen: Value(_optional(doneWhen)),
            progress: 0,
            color: Value(_optional(color)),
            icon: Value(_optional(icon)),
            createdAt: timestamp,
            updatedAt: timestamp,
          ),
        );
    return id;
  }

  Future<void> updateGoal(
    String id, {
    required String title,
    required String? lifeAreaId,
    required String? targetDate,
    required String? doneWhen,
    String? color,
    String? icon,
  }) {
    return (_db.update(_db.goals)..where((row) => row.id.equals(id))).write(
      GoalsCompanion(
        title: Value(_required(title, 'title')),
        lifeAreaId: Value(lifeAreaId),
        targetDate: Value(targetDate),
        doneWhen: Value(_optional(doneWhen)),
        color: _change(color),
        icon: _change(icon),
        updatedAt: Value(_timestamp()),
      ),
    );
  }

  /// Sets the progress the user reports, from 0 to 100.
  Future<void> setGoalProgress(String id, int progress) {
    return (_db.update(_db.goals)..where((row) => row.id.equals(id))).write(
      GoalsCompanion(
        progress: Value(progress.clamp(0, 100)),
        updatedAt: Value(_timestamp()),
      ),
    );
  }

  /// How many projects and tasks link straight to this goal. The app no
  /// longer links a task straight to a goal (a task serves a project, the
  /// project serves the goal), but older tasks may still carry such a link.
  Future<({int projects, int tasks})> countLinkedToGoal(String goalId) async {
    final projects = await _projectIdsOfGoal(goalId);
    final tasks = await _taskIds(_db.tasks.goalId.equals(goalId));
    return (projects: projects.length, tasks: tasks.length);
  }

  Future<void> deleteGoal(String id, {required LinkedItems linked}) {
    return _db.transaction(() => _deleteGoal(id, linked, _timestamp()));
  }

  Future<void> _deleteGoal(
    String id,
    LinkedItems linked,
    String timestamp,
  ) async {
    final projectIds = await _projectIdsOfGoal(id);
    if (linked == LinkedItems.delete) {
      for (final projectId in projectIds) {
        await _deleteProject(projectId, LinkedItems.delete, timestamp);
      }
      await _markTasksDeleted(_db.tasks.goalId.equals(id), timestamp);
    } else {
      if (projectIds.isNotEmpty) {
        await (_db.update(
          _db.projects,
        )..where((row) => row.id.isIn(projectIds))).write(
          ProjectsCompanion(
            goalId: const Value(null),
            updatedAt: Value(timestamp),
          ),
        );
      }
      await (_db.update(
        _db.tasks,
      )..where((row) => row.goalId.equals(id) & row.deletedAt.isNull())).write(
        TasksCompanion(goalId: const Value(null), updatedAt: Value(timestamp)),
      );
    }
    await (_db.update(_db.goals)..where((row) => row.id.equals(id))).write(
      GoalsCompanion(deletedAt: Value(timestamp), updatedAt: Value(timestamp)),
    );
  }

  Future<List<String>> _projectIdsOfGoal(String goalId) {
    final query = _db.selectOnly(_db.projects)
      ..addColumns([_db.projects.id])
      ..where(
        _db.projects.goalId.equals(goalId) & _db.projects.deletedAt.isNull(),
      );
    return query.map((row) => row.read(_db.projects.id)!).get();
  }

  // ------------------------------------------------------------- projects

  /// The user's projects, oldest first. Deleted ones are left out.
  Stream<List<Project>> watchProjects(String userId) {
    final query = _db.select(_db.projects)
      ..where((row) => row.userId.equals(userId) & row.deletedAt.isNull())
      ..orderBy([(row) => OrderingTerm.asc(row.createdAt)]);
    return query.watch();
  }

  Future<String> addProject({
    required String userId,
    required String name,
    required String color,
    String icon = 'folder',
    String? goalId,
  }) async {
    final id = _newId();
    final timestamp = _timestamp();
    await _db
        .into(_db.projects)
        .insert(
          ProjectsCompanion.insert(
            id: id,
            userId: userId,
            name: _required(name, 'name'),
            goalId: Value(goalId),
            color: color,
            icon: Value(icon),
            createdAt: timestamp,
            updatedAt: timestamp,
          ),
        );
    return id;
  }

  Future<void> updateProject(
    String id, {
    required String name,
    required String color,
    required String icon,
    required String? goalId,
  }) {
    return (_db.update(_db.projects)..where((row) => row.id.equals(id))).write(
      ProjectsCompanion(
        name: Value(_required(name, 'name')),
        color: Value(color),
        icon: Value(icon),
        goalId: Value(goalId),
        updatedAt: Value(_timestamp()),
      ),
    );
  }

  /// How many tasks belong to this project.
  Future<int> countTasksOfProject(String projectId) async {
    final tasks = await _taskIds(_db.tasks.projectId.equals(projectId));
    return tasks.length;
  }

  Future<void> deleteProject(String id, {required LinkedItems linked}) {
    return _db.transaction(() => _deleteProject(id, linked, _timestamp()));
  }

  Future<void> _deleteProject(
    String id,
    LinkedItems linked,
    String timestamp,
  ) async {
    if (linked == LinkedItems.delete) {
      await _markTasksDeleted(_db.tasks.projectId.equals(id), timestamp);
    } else {
      await (_db.update(_db.tasks)
            ..where((row) => row.projectId.equals(id) & row.deletedAt.isNull()))
          .write(
            TasksCompanion(
              projectId: const Value(null),
              updatedAt: Value(timestamp),
            ),
          );
    }
    await (_db.update(_db.projects)..where((row) => row.id.equals(id))).write(
      ProjectsCompanion(
        deletedAt: Value(timestamp),
        updatedAt: Value(timestamp),
      ),
    );
  }

  // ---------------------------------------------------------------- tasks

  Future<List<String>> _taskIds(Expression<bool> filter) {
    final query = _db.selectOnly(_db.tasks)
      ..addColumns([_db.tasks.id])
      ..where(filter & _db.tasks.deletedAt.isNull());
    return query.map((row) => row.read(_db.tasks.id)!).get();
  }

  Future<void> _markTasksDeleted(Expression<bool> filter, String timestamp) {
    return (_db.update(
      _db.tasks,
    )..where((row) => filter & row.deletedAt.isNull())).write(
      TasksCompanion(deletedAt: Value(timestamp), updatedAt: Value(timestamp)),
    );
  }
}
