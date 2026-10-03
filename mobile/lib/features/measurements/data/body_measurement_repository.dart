import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/local_db/app_database.dart';
import '../../../core/local_db/database_provider.dart';
import '../../../core/sync/client_id.dart';
import '../../../core/sync/outbox_writer.dart';
import '../../../core/sync/pending_delete_filter.dart';
import '../../../core/utils/combine_latest.dart';
import '../domain/body_measurement.dart';

/// Local-first access to body measurements (docs/80). Reads stream from the
/// on-device cache; writes land there immediately and queue an outbox
/// operation — this never calls the network directly.
class BodyMeasurementRepository {
  BodyMeasurementRepository(this._db, this._outbox);

  final AppDatabase _db;
  final OutboxWriter _outbox;

  static final _dateFormat = DateFormat('yyyy-MM-dd');

  Stream<List<BodyMeasurement>> watchAll() {
    final rows$ = (_db.select(_db.bodyMeasurements)
          ..orderBy([
            (t) => OrderingTerm.desc(t.date),
            (t) => OrderingTerm.desc(t.recordedAt),
          ]))
        .watch();
    final pendingOps$ = _db.select(_db.pendingOperations).watch();
    return combineLatest2(rows$, pendingOps$, (rows, ops) {
      final blocked = blockedByActiveDelete(ops);
      return rows
          .where((r) => !blocked.contains(r.clientId))
          .map(_toDomain)
          .whereType<BodyMeasurement>()
          .toList();
    });
  }

  Future<void> create({
    required DateTime date,
    required MeasurementSite site,
    required double valueCm,
  }) async {
    final clientId = newClientId();
    await _db.into(_db.bodyMeasurements).insert(BodyMeasurementsCompanion.insert(
          clientId: clientId,
          date: date,
          site: site.wire,
          valueCm: valueCm,
          recordedAt: DateTime.now(),
        ));
    await _outbox.enqueueCreate(
      clientId: clientId,
      entityType: 'body_measurement',
      payload: {'date': _dateFormat.format(date), 'site': site.wire, 'valueCm': valueCm},
    );
  }

  Future<void> delete(String clientId) async {
    // Enqueue before the local row can go — enqueueDelete reads its serverId.
    // When a server delete is queued the row stays (hidden by watchAll's
    // filter) until the engine confirms it.
    final queued = await _outbox.enqueueDelete(clientId: clientId, entityType: 'body_measurement');
    if (!queued) {
      await (_db.delete(_db.bodyMeasurements)..where((t) => t.clientId.equals(clientId))).go();
    }
  }

  BodyMeasurement? _toDomain(BodyMeasurementRow row) {
    final site = MeasurementSite.fromWire(row.site);
    if (site == null) return null;
    return BodyMeasurement(
      clientId: row.clientId,
      id: row.serverId,
      date: row.date,
      site: site,
      valueCm: row.valueCm,
      recordedAt: row.recordedAt,
    );
  }
}

final bodyMeasurementRepositoryProvider = Provider<BodyMeasurementRepository>((ref) {
  return BodyMeasurementRepository(ref.watch(appDatabaseProvider), ref.watch(outboxWriterProvider));
});
