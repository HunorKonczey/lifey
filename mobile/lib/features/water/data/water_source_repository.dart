import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/local_db/app_database.dart';
import '../../../core/local_db/database_provider.dart';
import '../../../core/sync/client_id.dart';
import '../../../core/sync/outbox_writer.dart';
import '../../../core/sync/pending_delete_filter.dart';
import '../../../core/utils/combine_latest.dart';
import '../domain/water_source.dart';

/// Local-first access to water sources. Reads stream from the on-device
/// cache; writes land there immediately and queue an outbox operation.
class WaterSourceRepository {
  WaterSourceRepository(this._db, this._outbox);

  final AppDatabase _db;
  final OutboxWriter _outbox;

  Stream<List<WaterSource>> watchAll() {
    final sources$ =
        (_db.select(_db.waterSources)..orderBy([(t) => OrderingTerm.asc(t.name)])).watch();
    final pendingOps$ = _db.select(_db.pendingOperations).watch();
    return combineLatest2(sources$, pendingOps$, (rows, ops) {
      final blocked = blockedByActiveDelete(ops);
      return rows.where((r) => !blocked.contains(r.clientId)).map(_toDomain).toList();
    });
  }

  Future<void> create({required String name, required double volumeLiters}) async {
    final clientId = newClientId();
    await _db.into(_db.waterSources).insert(
        WaterSourcesCompanion.insert(clientId: clientId, name: name, volumeLiters: volumeLiters));
    await _outbox.enqueueCreate(
      clientId: clientId,
      entityType: 'water_source',
      payload: {'name': name, 'volumeLiters': volumeLiters},
    );
  }

  Future<void> update(String clientId, {required String name, required double volumeLiters}) async {
    await (_db.update(_db.waterSources)..where((t) => t.clientId.equals(clientId)))
        .write(WaterSourcesCompanion(name: Value(name), volumeLiters: Value(volumeLiters)));
    await _outbox.enqueueUpdate(
      clientId: clientId,
      entityType: 'water_source',
      payload: {'name': name, 'volumeLiters': volumeLiters},
    );
  }

  Future<void> delete(String clientId) async {
    // Must enqueue before the local row is gone — enqueueDelete needs to
    // read its serverId while the row still exists. If it queued a server
    // delete, the row stays (hidden by the controller's filter) until that
    // delete is confirmed — see EntitySyncConfig.cleanupChildren's doc.
    final queued = await _outbox.enqueueDelete(clientId: clientId, entityType: 'water_source');
    if (!queued) {
      await (_db.delete(_db.waterSources)..where((t) => t.clientId.equals(clientId))).go();
    }
  }

  WaterSource _toDomain(WaterSourceRow row) {
    return WaterSource(clientId: row.clientId, id: row.serverId, name: row.name, volumeLiters: row.volumeLiters);
  }
}

final waterSourceRepositoryProvider = Provider<WaterSourceRepository>((ref) {
  return WaterSourceRepository(ref.watch(appDatabaseProvider), ref.watch(outboxWriterProvider));
});
