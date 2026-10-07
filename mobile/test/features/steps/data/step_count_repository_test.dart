import 'package:dio/dio.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifey/core/local_db/app_database.dart';
import 'package:lifey/core/sync/outbox_writer.dart';
import 'package:lifey/core/sync/sync_engine.dart';
import 'package:lifey/features/steps/data/step_count_repository.dart';

class _NoopSyncEngine extends SyncEngine {
  _NoopSyncEngine(super.db, super.dio);

  @override
  Future<void> sync() async {}
}

void main() {
  late AppDatabase db;
  late StepCountRepository repo;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    repo = StepCountRepository(db, OutboxWriter(db, _NoopSyncEngine(db, Dio())));
  });

  tearDown(() => db.close());

  test('upsertForDay rewrites the same day instead of adding a row', () async {
    await repo.upsertForDay(date: DateTime(2026, 10, 6, 9), steps: 1000);
    await repo.upsertForDay(date: DateTime(2026, 10, 6, 21), steps: 8000);

    final rows = await db.select(db.dailyStepCounts).get();
    expect(rows, hasLength(1));
    expect(rows.single.steps, 8000);
  });

  test('upsertForDay does not fail when a day briefly has two local rows', () async {
    // One created here while offline, one pulled from another device for the same date.
    await db.into(db.dailyStepCounts).insert(DailyStepCountsCompanion.insert(
        clientId: 'a', date: DateTime(2026, 10, 6), steps: 500, serverId: const Value(9)));
    await db.into(db.dailyStepCounts).insert(
        DailyStepCountsCompanion.insert(clientId: 'b', date: DateTime(2026, 10, 6), steps: 700));

    await repo.upsertForDay(date: DateTime(2026, 10, 6, 20), steps: 9000);

    final rows = await db.select(db.dailyStepCounts).get();
    expect(rows, hasLength(2));
    expect(rows.where((r) => r.steps == 9000), hasLength(1));
  });
}
