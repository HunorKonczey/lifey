import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/local_db/app_database.dart';
import '../../../core/local_db/database_provider.dart';
import '../../../core/sync/client_id.dart';
import '../../../core/sync/outbox_writer.dart';
import '../../../core/sync/pending_delete_filter.dart';
import '../../../core/utils/combine_latest.dart';
import '../domain/exercise.dart';

/// Local-first access to the shared exercise master list.
class ExerciseRepository {
  ExerciseRepository(this._db, this._outbox);

  final AppDatabase _db;
  final OutboxWriter _outbox;

  Stream<List<Exercise>> watchAll() {
    final exercises$ =
        (_db.select(_db.exercises)..orderBy([(t) => OrderingTerm.asc(t.name)])).watch();
    final pendingOps$ = _db.select(_db.pendingOperations).watch();
    return combineLatest2(exercises$, pendingOps$, (rows, ops) {
      final blocked = blockedByActiveDelete(ops);
      return rows.where((r) => !blocked.contains(r.clientId)).map(_toDomain).toList();
    });
  }

  /// Returns the newly generated [Exercise.clientId] — [getOrCreateByName]
  /// needs it to resolve a lookup miss into a usable id.
  Future<String> create(
    String name, {
    String? category,
    String? equipment,
    String? description,
    int? defaultRestSeconds,
  }) async {
    final clientId = newClientId();
    await _db.into(_db.exercises).insert(
          ExercisesCompanion.insert(
            clientId: clientId,
            name: name,
            category: Value(category),
            equipment: Value(equipment),
            description: Value(description),
            defaultRestSeconds: Value(defaultRestSeconds),
          ),
        );
    await _outbox.enqueueCreate(
      clientId: clientId,
      entityType: 'exercise',
      payload: {
        'name': name,
        'category': category,
        'equipment': equipment,
        'description': description,
        'defaultRestSeconds': defaultRestSeconds,
      },
    );
    return clientId;
  }

  /// Looks up an exercise by exact [name] match and returns its `clientId`;
  /// creates one via [create] if none exists yet. Used by the standalone
  /// (phone-less) workout processor to resolve its generic placeholder
  /// exercise (the `standaloneSessionTitle` text) without duplicating it on
  /// every synced session (docs/watch/44-watch-f6-standalone-plan.md D-F6.3).
  Future<String> getOrCreateByName(String name) async {
    final existing =
        await (_db.select(_db.exercises)..where((t) => t.name.equals(name))).getSingleOrNull();
    if (existing != null) return existing.clientId;
    return create(name);
  }

  /// Which of [clientIds] this device actually has an exercise row for — the
  /// standalone processor's check before trusting an `exerciseId` the watch
  /// sent with a logged set (docs/watch/50-watch-f6c-session-plan-sync-plan.md):
  /// the id came from this phone in the first place, but the exercise can have
  /// been deleted since, and a dangling reference must fall back rather than
  /// write a set nothing can render.
  Future<Set<String>> existingClientIds(Set<String> clientIds) async {
    if (clientIds.isEmpty) return const {};
    final rows = await (_db.select(_db.exercises)
          ..where((t) => t.clientId.isIn(clientIds)))
        .get();
    return {for (final row in rows) row.clientId};
  }

  Future<void> update(
    String clientId, {
    required String name,
    String? category,
    String? equipment,
    String? description,
    int? defaultRestSeconds,
  }) async {
    await (_db.update(_db.exercises)..where((t) => t.clientId.equals(clientId))).write(
          ExercisesCompanion(
            name: Value(name),
            category: Value(category),
            equipment: Value(equipment),
            description: Value(description),
            defaultRestSeconds: Value(defaultRestSeconds),
          ),
        );
    await _outbox.enqueueUpdate(
      clientId: clientId,
      entityType: 'exercise',
      payload: {
        'name': name,
        'category': category,
        'equipment': equipment,
        'description': description,
        'defaultRestSeconds': defaultRestSeconds,
      },
    );
  }

  Future<void> delete(String clientId) async {
    // Must enqueue before the local row is gone — enqueueDelete needs to
    // read its serverId while the row still exists. If it queued a server
    // delete, the row stays (hidden by the controller's filter) until that
    // delete is confirmed — see EntitySyncConfig.cleanupChildren's doc.
    final queued = await _outbox.enqueueDelete(clientId: clientId, entityType: 'exercise');
    if (!queued) {
      await (_db.delete(_db.exercises)..where((t) => t.clientId.equals(clientId))).go();
    }
  }

  Exercise _toDomain(ExerciseRow row) {
    return Exercise(
      clientId: row.clientId,
      id: row.serverId,
      name: row.name,
      category: row.category,
      equipment: row.equipment,
      description: row.description,
      defaultRestSeconds: row.defaultRestSeconds,
    );
  }
}

final exerciseRepositoryProvider = Provider<ExerciseRepository>((ref) {
  return ExerciseRepository(ref.watch(appDatabaseProvider), ref.watch(outboxWriterProvider));
});
