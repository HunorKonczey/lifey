import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/local_db/app_database.dart';
import '../../../core/local_db/database_provider.dart';
import '../../../core/sync/client_id.dart';
import '../../../core/sync/outbox_writer.dart';
import '../../../core/sync/pending_delete_filter.dart';
import '../../../core/utils/combine_latest.dart';
import '../domain/sleep_session.dart';

/// Local-first access to sleep sessions (docs/integrations/89 D-G7). Reads
/// stream from the on-device cache; writes land there immediately and queue
/// an outbox operation. This never calls the network directly.
///
/// There is no update: the values are the watch's measurement (D-G6).
class SleepSessionRepository {
  SleepSessionRepository(this._db, this._outbox);

  final AppDatabase _db;
  final OutboxWriter _outbox;

  static const entityType = 'sleep_session';

  /// Every session, newest wake-up first, without those being deleted.
  Stream<List<SleepSession>> watchAll() {
    final rows$ = (_db.select(_db.sleepSessions)
          ..orderBy([
            (t) => OrderingTerm.desc(t.endedAt),
            (t) => OrderingTerm.desc(t.startedAt),
          ]))
        .watch();
    final pendingOps$ = _db.select(_db.pendingOperations).watch();
    return combineLatest2(rows$, pendingOps$, (rows, ops) {
      final blocked = blockedByActiveDelete(ops);
      return rows.where((r) => !blocked.contains(r.clientId)).map(_toDomain).toList();
    });
  }

  /// Stores one session and queues its create. Returns the new clientId.
  ///
  /// Blank [sourceAppName] / [healthRecordId] are stored as null, the same
  /// as the server does, so the local row never disagrees with the pulled one.
  Future<String> create({
    required DateTime startedAt,
    required DateTime endedAt,
    int? asleepMinutes,
    int? deepMinutes,
    int? lightMinutes,
    int? remMinutes,
    int? awakeMinutes,
    String? sourceAppName,
    String? healthRecordId,
  }) async {
    final clientId = newClientId();
    final app = _blankToNull(sourceAppName);
    final recordId = _blankToNull(healthRecordId);
    await _db.into(_db.sleepSessions).insert(SleepSessionsCompanion.insert(
          clientId: clientId,
          startedAt: startedAt,
          endedAt: endedAt,
          asleepMinutes: Value(asleepMinutes),
          deepMinutes: Value(deepMinutes),
          lightMinutes: Value(lightMinutes),
          remMinutes: Value(remMinutes),
          awakeMinutes: Value(awakeMinutes),
          sourceAppName: Value(app),
          healthRecordId: Value(recordId),
        ));
    await _outbox.enqueueCreate(
      clientId: clientId,
      entityType: entityType,
      payload: {
        'startedAt': startedAt.toUtc().toIso8601String(),
        'endedAt': endedAt.toUtc().toIso8601String(),
        if (asleepMinutes != null) 'asleepMinutes': asleepMinutes,
        if (deepMinutes != null) 'deepMinutes': deepMinutes,
        if (lightMinutes != null) 'lightMinutes': lightMinutes,
        if (remMinutes != null) 'remMinutes': remMinutes,
        if (awakeMinutes != null) 'awakeMinutes': awakeMinutes,
        if (app != null) 'sourceAppName': app,
        if (recordId != null) 'healthRecordId': recordId,
      },
    );
    return clientId;
  }

  Future<void> delete(String clientId) async {
    // Enqueue before the local row can go — enqueueDelete reads its serverId.
    // When a server delete is queued the row stays (hidden by watchAll's
    // filter) until the engine confirms it.
    final queued = await _outbox.enqueueDelete(clientId: clientId, entityType: entityType);
    if (!queued) {
      await (_db.delete(_db.sleepSessions)..where((t) => t.clientId.equals(clientId))).go();
    }
  }

  /// Whether a local session was imported from this health-store record:
  /// the importer's local dedupe check (D-G3).
  ///
  /// A session the user deleted is gone locally once the server confirms,
  /// so it is not seen here. The server's 409 on the re-import catches that
  /// case, and the sync engine then drops the local copy
  /// (EntitySyncConfig.dropLocalOnCreateConflict).
  Future<bool> existsByHealthRecordId(String healthRecordId) async {
    final row = await (_db.select(_db.sleepSessions)
          ..where((t) => t.healthRecordId.equals(healthRecordId))
          ..limit(1))
        .getSingleOrNull();
    return row != null;
  }

  SleepSession _toDomain(SleepSessionRow row) => SleepSession(
        clientId: row.clientId,
        id: row.serverId,
        startedAt: row.startedAt,
        endedAt: row.endedAt,
        asleepMinutes: row.asleepMinutes,
        deepMinutes: row.deepMinutes,
        lightMinutes: row.lightMinutes,
        remMinutes: row.remMinutes,
        awakeMinutes: row.awakeMinutes,
        sourceAppName: row.sourceAppName,
        healthRecordId: row.healthRecordId,
      );

  static String? _blankToNull(String? value) {
    final trimmed = value?.trim();
    return trimmed == null || trimmed.isEmpty ? null : trimmed;
  }
}

final sleepSessionRepositoryProvider = Provider<SleepSessionRepository>((ref) {
  return SleepSessionRepository(ref.watch(appDatabaseProvider), ref.watch(outboxWriterProvider));
});
