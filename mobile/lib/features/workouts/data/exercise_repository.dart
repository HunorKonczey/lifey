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

  Future<void> create(String name) async {
    final clientId = newClientId();
    await _db.into(_db.exercises).insert(
          ExercisesCompanion.insert(clientId: clientId, name: name),
        );
    await _outbox.enqueueCreate(
      clientId: clientId,
      entityType: 'exercise',
      payload: {'name': name},
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
    return Exercise(clientId: row.clientId, id: row.serverId, name: row.name);
  }
}

final exerciseRepositoryProvider = Provider<ExerciseRepository>((ref) {
  return ExerciseRepository(ref.watch(appDatabaseProvider), ref.watch(outboxWriterProvider));
});
