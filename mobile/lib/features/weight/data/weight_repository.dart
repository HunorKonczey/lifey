import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/local_db/app_database.dart';
import '../../../core/local_db/database_provider.dart';
import '../../../core/sync/client_id.dart';
import '../../../core/sync/outbox_writer.dart';
import '../../../core/sync/pending_delete_filter.dart';
import '../../../core/utils/combine_latest.dart';
import '../domain/weight_entry.dart';

/// Local-first access to weight entries. Reads stream from the on-device
/// cache; writes land there immediately and queue an outbox operation for
/// the sync engine — this never calls the network directly.
class WeightRepository {
  WeightRepository(this._db, this._outbox);

  final AppDatabase _db;
  final OutboxWriter _outbox;

  static final _dateFormat = DateFormat('yyyy-MM-dd');

  Stream<List<WeightEntry>> watchAll() {
    final entries$ = (_db.select(_db.weightEntries)
          ..orderBy([
            (t) => OrderingTerm.desc(t.date),
            (t) => OrderingTerm.desc(t.recordedAt),
          ]))
        .watch();
    final pendingOps$ = _db.select(_db.pendingOperations).watch();
    return combineLatest2(entries$, pendingOps$, (rows, ops) {
      final blocked = blockedByActiveDelete(ops);
      return rows.where((r) => !blocked.contains(r.clientId)).map(_toDomain).toList();
    });
  }

  Future<void> create({required DateTime date, required double weight}) async {
    final clientId = newClientId();
    await _db.into(_db.weightEntries).insert(WeightEntriesCompanion.insert(
          clientId: clientId,
          date: date,
          weight: weight,
          recordedAt: DateTime.now(),
        ));
    await _outbox.enqueueCreate(
      clientId: clientId,
      entityType: 'weight_entry',
      payload: {'date': _dateFormat.format(date), 'weight': weight},
    );
  }

  /// Whether a weight entry already exists for today's calendar date — used
  /// by the weigh-in reminder to skip today's notification once it's no
  /// longer needed. Compares by day only, since [create]'s [date] can carry
  /// a same-day time-of-day component (the add-entry sheet defaults to
  /// `DateTime.now()` before the user picks a different day).
  Future<bool> hasEntryForToday() async {
    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day);
    final endOfDay = startOfDay.add(const Duration(days: 1));
    final rows = await (_db.select(_db.weightEntries)
          ..where((t) => t.date.isBiggerOrEqualValue(startOfDay) & t.date.isSmallerThanValue(endOfDay)))
        .get();
    if (rows.isEmpty) return false;
    final ops = await _db.select(_db.pendingOperations).get();
    final blocked = blockedByActiveDelete(ops);
    return rows.any((r) => !blocked.contains(r.clientId));
  }

  Future<void> delete(String clientId) async {
    // Must enqueue before the local row is gone — enqueueDelete needs to
    // read its serverId while the row still exists. If it queued a server
    // delete, the row stays (hidden by the controller's filter) until that
    // delete is confirmed — see EntitySyncConfig.cleanupChildren's doc.
    final queued = await _outbox.enqueueDelete(clientId: clientId, entityType: 'weight_entry');
    if (!queued) {
      await (_db.delete(_db.weightEntries)..where((t) => t.clientId.equals(clientId))).go();
    }
  }

  WeightEntry _toDomain(WeightEntryRow row) {
    return WeightEntry(
      clientId: row.clientId,
      id: row.serverId,
      date: row.date,
      weight: row.weight,
      recordedAt: row.recordedAt,
    );
  }
}

final weightRepositoryProvider = Provider<WeightRepository>((ref) {
  return WeightRepository(ref.watch(appDatabaseProvider), ref.watch(outboxWriterProvider));
});
