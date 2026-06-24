import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/local_db/app_database.dart';
import '../../../core/local_db/database_provider.dart';
import '../../../core/sync/client_id.dart';
import '../../../core/sync/outbox_writer.dart';
import '../../../core/sync/pending_delete_filter.dart';
import '../../../core/utils/combine_latest.dart';
import '../domain/daily_step_count.dart';

/// Local-first access to daily step counts. One row per calendar day;
/// calling [upsertForDay] rewrites the day's total rather than creating a
/// new row each time.
class StepCountRepository {
  StepCountRepository(this._db, this._outbox);

  final AppDatabase _db;
  final OutboxWriter _outbox;

  static final _dateFormat = DateFormat('yyyy-MM-dd');

  Stream<List<DailyStepCount>> watchAll() {
    final rows$ = (_db.select(_db.dailyStepCounts)
          ..orderBy([(t) => OrderingTerm.desc(t.date)]))
        .watch();
    final pendingOps$ = _db.select(_db.pendingOperations).watch();
    return combineLatest2(rows$, pendingOps$, (rows, ops) {
      final blocked = blockedByActiveDelete(ops);
      return rows.where((r) => !blocked.contains(r.clientId)).map(_toDomain).toList();
    });
  }

  /// Inserts a new row if no row exists for [date], otherwise updates the
  /// existing row's step count. In the insert case a `create` outbox entry
  /// is queued; in the update case an `update` entry is queued so the sync
  /// engine sends a PUT to the already-created server row.
  Future<void> upsertForDay({required DateTime date, required int steps}) async {
    final dayStart = DateTime(date.year, date.month, date.day);
    final dayEnd = dayStart.add(const Duration(days: 1));

    final existing = await (_db.select(_db.dailyStepCounts)
          ..where((t) => t.date.isBiggerOrEqualValue(dayStart) & t.date.isSmallerThanValue(dayEnd)))
        .getSingleOrNull();

    if (existing == null) {
      final clientId = newClientId();
      await _db.into(_db.dailyStepCounts).insert(DailyStepCountsCompanion.insert(
            clientId: clientId,
            date: dayStart,
            steps: steps,
          ));
      await _outbox.enqueueCreate(
        clientId: clientId,
        entityType: 'daily_step_count',
        payload: {'date': _dateFormat.format(dayStart), 'steps': steps},
      );
    } else {
      await (_db.update(_db.dailyStepCounts)
            ..where((t) => t.clientId.equals(existing.clientId)))
          .write(DailyStepCountsCompanion(steps: Value(steps)));
      await _outbox.enqueueUpdate(
        clientId: existing.clientId,
        entityType: 'daily_step_count',
        payload: {'date': _dateFormat.format(dayStart), 'steps': steps},
      );
    }
  }

  Future<void> delete(String clientId) async {
    final queued =
        await _outbox.enqueueDelete(clientId: clientId, entityType: 'daily_step_count');
    if (!queued) {
      await (_db.delete(_db.dailyStepCounts)..where((t) => t.clientId.equals(clientId))).go();
    }
  }

  DailyStepCount _toDomain(DailyStepCountRow row) {
    return DailyStepCount(
      clientId: row.clientId,
      id: row.serverId,
      date: row.date,
      steps: row.steps,
    );
  }
}

final stepCountRepositoryProvider = Provider<StepCountRepository>((ref) {
  return StepCountRepository(
    ref.watch(appDatabaseProvider),
    ref.watch(outboxWriterProvider),
  );
});

final allStepCountsProvider = StreamProvider<List<DailyStepCount>>((ref) {
  return ref.watch(stepCountRepositoryProvider).watchAll();
});
