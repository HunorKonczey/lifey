import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/local_db/app_database.dart';
import '../../../core/local_db/database_provider.dart';
import '../../../core/sync/client_id.dart';
import '../../../core/sync/outbox_writer.dart';
import '../../../core/sync/pending_delete_filter.dart';
import '../../../core/utils/combine_latest.dart';
import '../../../core/utils/date_math.dart';
import '../domain/daily_vitals.dart';

/// Local-first access to daily vitals (docs/integrations/89 D-G8). One row
/// per calendar day. Reads stream from the on-device cache; writes land there
/// immediately and queue an outbox operation. This never calls the network.
class DailyVitalsRepository {
  DailyVitalsRepository(this._db, this._outbox);

  final AppDatabase _db;
  final OutboxWriter _outbox;

  static const entityType = 'daily_vitals';
  static final _dateFormat = DateFormat('yyyy-MM-dd');

  /// Every day, newest first, without the days being deleted.
  Stream<List<DailyVitals>> watchAll() {
    final rows$ = (_db.select(_db.dailyVitalsTable)..orderBy([(t) => OrderingTerm.desc(t.date)])).watch();
    final pendingOps$ = _db.select(_db.pendingOperations).watch();
    return combineLatest2(rows$, pendingOps$, (rows, ops) {
      final blocked = blockedByActiveDelete(ops);
      return rows.where((r) => !blocked.contains(r.clientId)).map(_toDomain).toList();
    });
  }

  /// Records values for the day of [date], merged into what the day already
  /// has: resting HR and HRV usually arrive separately, so a value left null
  /// here keeps the stored one. [hrvMs] and [hrvMethod] go together.
  ///
  /// The server replaces the whole day on every write, so the payload always
  /// carries the merged day, never just the new value. Does nothing when there
  /// is no value at all, or when the merged day is unchanged.
  Future<void> upsertForDay({
    required DateTime date,
    int? restingHr,
    double? hrvMs,
    HrvMethod? hrvMethod,
  }) async {
    assert((hrvMs == null) == (hrvMethod == null), 'hrvMs and hrvMethod go together');
    if (restingHr == null && hrvMs == null) return;
    final dayStart = DateTime(date.year, date.month, date.day);
    final existing = await _rowForDay(dayStart);

    if (existing == null) {
      final clientId = newClientId();
      await _db.into(_db.dailyVitalsTable).insert(DailyVitalsTableCompanion.insert(
            clientId: clientId,
            date: dayStart,
            restingHr: Value(restingHr),
            hrvMs: Value(hrvMs),
            hrvMethod: Value(hrvMethod?.wire),
          ));
      await _outbox.enqueueCreate(
        clientId: clientId,
        entityType: entityType,
        payload: _payload(dayStart, restingHr, hrvMs, hrvMethod?.wire),
      );
      return;
    }

    final mergedHr = restingHr ?? existing.restingHr;
    final mergedHrv = hrvMs ?? existing.hrvMs;
    final mergedMethod = hrvMs != null ? hrvMethod!.wire : existing.hrvMethod;
    if (mergedHr == existing.restingHr && mergedHrv == existing.hrvMs && mergedMethod == existing.hrvMethod) {
      return;
    }
    await (_db.update(_db.dailyVitalsTable)..where((t) => t.clientId.equals(existing.clientId)))
        .write(DailyVitalsTableCompanion(
      restingHr: Value(mergedHr),
      hrvMs: Value(mergedHrv),
      hrvMethod: Value(mergedMethod),
    ));
    await _outbox.enqueueUpdate(
      clientId: existing.clientId,
      entityType: entityType,
      payload: _payload(dayStart, mergedHr, mergedHrv, mergedMethod),
    );
  }

  Future<void> delete(String clientId) async {
    // Enqueue before the local row can go — enqueueDelete reads its serverId.
    final queued = await _outbox.enqueueDelete(clientId: clientId, entityType: entityType);
    if (!queued) {
      await (_db.delete(_db.dailyVitalsTable)..where((t) => t.clientId.equals(clientId))).go();
    }
  }

  /// The row of the day starting at [dayStart]. A day can briefly have two
  /// rows (one created here offline, one pulled from another device); the
  /// first one wins, as for the step counts, rather than failing the write.
  Future<DailyVitalsRow?> _rowForDay(DateTime dayStart) {
    final dayEnd = addDays(dayStart, 1);
    return (_db.select(_db.dailyVitalsTable)
          ..where((t) => t.date.isBiggerOrEqualValue(dayStart) & t.date.isSmallerThanValue(dayEnd))
          ..orderBy([(t) => OrderingTerm.asc(t.clientId)])
          ..limit(1))
        .getSingleOrNull();
  }

  static Map<String, dynamic> _payload(DateTime day, int? restingHr, double? hrvMs, String? hrvMethod) => {
        'date': _dateFormat.format(day),
        if (restingHr != null) 'restingHr': restingHr,
        if (hrvMs != null) 'hrvMs': hrvMs,
        if (hrvMethod != null) 'hrvMethod': hrvMethod,
      };

  DailyVitals _toDomain(DailyVitalsRow row) => DailyVitals(
        clientId: row.clientId,
        id: row.serverId,
        date: row.date,
        restingHr: row.restingHr,
        hrvMs: row.hrvMs,
        hrvMethod: HrvMethod.fromWire(row.hrvMethod),
      );
}

final dailyVitalsRepositoryProvider = Provider<DailyVitalsRepository>((ref) {
  return DailyVitalsRepository(ref.watch(appDatabaseProvider), ref.watch(outboxWriterProvider));
});
