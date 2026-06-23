import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/local_db/app_database.dart';
import '../../../core/local_db/database_provider.dart';
import '../../../core/sync/client_id.dart';
import '../../../core/sync/client_ref.dart';
import '../../../core/sync/outbox_writer.dart';
import '../../../core/sync/pending_delete_filter.dart';
import '../../../core/utils/combine_latest.dart';
import '../domain/water_entry.dart';

/// Local-first access to logging water intake. There's no list/edit UI for
/// past entries, only the dashboard's daily total — read locally (see
/// [watchTodayTotalLiters]) rather than from `/statistics/daily`, since that
/// endpoint only reflects an entry once it's synced, and a just-logged entry
/// hasn't necessarily synced yet by the time the dashboard re-reads.
class WaterEntryRepository {
  WaterEntryRepository(this._db, this._outbox);

  final AppDatabase _db;
  final OutboxWriter _outbox;

  /// Sum of every entry logged today (device-local day), live — updates the
  /// instant a local write lands, independent of sync timing.
  ///
  /// The "today" boundary is computed inside [_isToday] on every emission
  /// rather than once up front: a SQL `WHERE` clause bakes the boundary in
  /// at query-build time, so a stream built before midnight would keep
  /// comparing against yesterday's window for as long as it stayed
  /// subscribed — including entries logged just after midnight, which would
  /// fall outside that stale window and silently vanish from the total.
  Stream<double> watchTodayTotalLiters() {
    return _db.select(_db.waterEntries).watch().map(
          (rows) => rows
              .where((row) => _isToday(row.consumedAt))
              .fold<double>(0, (sum, row) => sum + row.volumeLiters),
        );
  }

  bool _isToday(DateTime dateTime) {
    final now = DateTime.now();
    final local = dateTime.toLocal();
    return local.year == now.year && local.month == now.month && local.day == now.day;
  }

  /// Every logged entry, most recent first — used by the statistics screen
  /// to aggregate daily totals across an arbitrary range (the dashboard's
  /// [watchTodayTotalLiters] only covers today).
  Stream<List<WaterEntry>> watchAll() {
    final entries$ = (_db.select(_db.waterEntries)
          ..orderBy([(t) => OrderingTerm.desc(t.consumedAt)]))
        .watch();
    final pendingOps$ = _db.select(_db.pendingOperations).watch();
    return combineLatest2(entries$, pendingOps$, (rows, ops) {
      final blocked = blockedByActiveDelete(ops);
      return rows.where((r) => !blocked.contains(r.clientId)).map(_toDomain).toList();
    });
  }

  WaterEntry _toDomain(WaterEntryRow row) => WaterEntry(
        clientId: row.clientId,
        id: row.serverId,
        consumedAt: row.consumedAt,
        volumeLiters: row.volumeLiters,
        sourceClientId: row.sourceClientId,
      );

  Future<void> create({
    required DateTime consumedAt,
    String? sourceClientId,
    required double volumeLiters,
  }) async {
    final clientId = newClientId();
    await _db.into(_db.waterEntries).insert(WaterEntriesCompanion.insert(
          clientId: clientId,
          sourceClientId: Value(sourceClientId),
          volumeLiters: volumeLiters,
          consumedAt: consumedAt,
        ));
    await _outbox.enqueueCreate(
      clientId: clientId,
      entityType: 'water_entry',
      payload: {
        'consumedAt': consumedAt.toUtc().toIso8601String(),
        'volumeLiters': volumeLiters,
        if (sourceClientId != null) 'sourceId': clientRef(sourceClientId),
      },
      // Waits for the source's own create to sync first, if it hasn't yet —
      // harmless (resolves immediately) when the source already has synced.
      dependsOnClientId: sourceClientId,
    );
  }
}

final waterEntryRepositoryProvider = Provider<WaterEntryRepository>((ref) {
  return WaterEntryRepository(ref.watch(appDatabaseProvider), ref.watch(outboxWriterProvider));
});

final todayWaterTotalProvider = StreamProvider<double>((ref) {
  return ref.watch(waterEntryRepositoryProvider).watchTodayTotalLiters();
});

final allWaterEntriesProvider = StreamProvider<List<WaterEntry>>((ref) {
  return ref.watch(waterEntryRepositoryProvider).watchAll();
});
