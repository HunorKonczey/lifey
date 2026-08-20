import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifey/core/local_db/app_database.dart';
import 'package:lifey/core/sync/outbox_writer.dart';
import 'package:lifey/core/sync/sync_engine.dart';
import 'package:lifey/features/workouts/data/cardio_interval_plan_repository.dart';
import 'package:lifey/features/workouts/domain/cardio_interval_plan.dart';

/// docs/cardio/60 C7.3 — kész-ha: a plan can be built offline and syncs.
/// "Offline" is the default here: nothing in these tests touches the
/// network, so what they check is exactly what an offline device does —
/// the local rows land immediately and the outbox carries the full plan.

class _NoopSyncEngine extends SyncEngine {
  _NoopSyncEngine(super.db, super.dio);

  @override
  Future<void> sync() async {}
}

/// 5:00 easy · 4× (4:00 hard + 3:00 easy) · 5:00 easy — the starter template
/// the editor offers on its empty state (docs/cardio/61 §3 M37).
List<IntervalStep> fourByFour() => const [
      IntervalStep.section(
          name: 'Bemelegítés', intensity: IntervalIntensity.easy, durationSeconds: 300),
      IntervalStep.block(repeatCount: 4, children: [
        IntervalStep.section(
            name: 'Kemény', intensity: IntervalIntensity.hard, durationSeconds: 240),
        IntervalStep.section(
            name: 'Pihenő', intensity: IntervalIntensity.easy, durationSeconds: 180),
      ]),
      IntervalStep.section(
          name: 'Levezetés', intensity: IntervalIntensity.easy, durationSeconds: 300),
    ];

void main() {
  late AppDatabase db;
  late CardioIntervalPlanRepository repo;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    repo = CardioIntervalPlanRepository(db, OutboxWriter(db, _NoopSyncEngine(db, Dio())));
  });

  tearDown(() => db.close());

  Future<Map<String, dynamic>> lastPayload(String operation) async {
    final ops = await (db.select(db.pendingOperations)
          ..where((t) => t.operation.equals(operation)))
        .get();
    return jsonDecode(ops.last.payloadJson) as Map<String, dynamic>;
  }

  group('create', () {
    test('stores the tree flat and reads it back as a tree', () async {
      final clientId = await repo.create(name: 'Kedd esti 4x4', steps: fourByFour());

      final rows = await db.select(db.cardioIntervalSteps).get();
      expect(rows, hasLength(5));
      // Per-sibling indexes, not 0..4: three top-level items and the block's
      // two children, same shape the backend stores.
      expect(rows.where((r) => r.parentStepClientId == null).map((r) => r.stepIndex), [0, 1, 2]);
      expect(rows.where((r) => r.parentStepClientId != null).map((r) => r.stepIndex), [0, 1]);

      final plan = await repo.findByClientId(clientId);
      expect(plan!.name, 'Kedd esti 4x4');
      expect(plan.steps.map((s) => s.type),
          [IntervalStepType.step, IntervalStepType.repeat, IntervalStepType.step]);
      expect(plan.steps[1].repeatCount, 4);
      expect(plan.steps[1].children.map((c) => c.durationSeconds), [240, 180]);
      expect(plan.steps[1].children.map((c) => c.intensity),
          [IntervalIntensity.hard, IntervalIntensity.easy]);
    });

    test('queues the whole plan as one create payload', () async {
      await repo.create(name: 'Kedd esti 4x4', steps: fourByFour());

      final payload = await lastPayload('create');
      expect(payload['name'], 'Kedd esti 4x4');
      final steps = (payload['steps'] as List).cast<Map<String, dynamic>>();
      expect(steps, hasLength(3));
      // A section carries no repeatCount and no children; a block carries no
      // duration or intensity — the shape the backend's validation demands.
      expect(steps[0]['type'], 'STEP');
      expect(steps[0]['intensity'], 'EASY');
      expect(steps[0]['repeatCount'], isNull);
      expect(steps[0]['children'], isNull);
      expect(steps[1]['type'], 'REPEAT');
      expect(steps[1]['repeatCount'], 4);
      expect(steps[1]['durationSeconds'], isNull);
      expect(steps[1]['intensity'], isNull);
      expect((steps[1]['children'] as List), hasLength(2));
      expect((steps[1]['children'] as List)[0]['durationSeconds'], 240);
    });

    test('queues it under its own entity type, so nothing else is touched', () async {
      await repo.create(name: 'Kedd esti 4x4', steps: fourByFour());

      final ops = await db.select(db.pendingOperations).get();
      expect(ops, hasLength(1));
      expect(ops.single.entityType, 'cardio_interval_plan');
      expect(ops.single.operation, 'create');
    });
  });

  group('update', () {
    test('replaces every step, including the ones inside a block', () async {
      final clientId = await repo.create(name: 'Kedd esti 4x4', steps: fourByFour());

      await repo.update(clientId, name: 'Rövid sprintek', steps: const [
        IntervalStep.block(repeatCount: 6, children: [
          IntervalStep.section(
              name: 'Sprint', intensity: IntervalIntensity.hard, durationSeconds: 30),
          IntervalStep.section(
              name: 'Pihenő', intensity: IntervalIntensity.easy, durationSeconds: 90),
        ]),
      ]);

      // Three rows total: nothing from the old plan survived.
      expect(await db.select(db.cardioIntervalSteps).get(), hasLength(3));
      final plan = await repo.findByClientId(clientId);
      expect(plan!.name, 'Rövid sprintek');
      expect(plan.steps.single.repeatCount, 6);
      expect(plan.steps.single.children.map((c) => c.durationSeconds), [30, 90]);
    });

    test('an unsynced plan queues the update behind its own create', () async {
      final clientId = await repo.create(name: 'Kedd esti 4x4', steps: fourByFour());

      await repo.update(clientId, name: 'Átnevezve', steps: fourByFour());

      final ops = await (db.select(db.pendingOperations)
            ..where((t) => t.operation.equals('update')))
          .get();
      // Nothing exists server-side yet, so the PUT must wait for the POST.
      expect(ops.single.dependsOnClientId, clientId);
    });
  });

  group('delete', () {
    test('a never-synced plan is dropped locally with nothing queued', () async {
      final clientId = await repo.create(name: 'Kedd esti 4x4', steps: fourByFour());

      await repo.delete(clientId);

      expect(await db.select(db.cardioIntervalPlans).get(), isEmpty);
      expect(await db.select(db.cardioIntervalSteps).get(), isEmpty);
      expect(await db.select(db.pendingOperations).get(), isEmpty);
    });

    test('a synced plan keeps its rows until the server confirms the delete', () async {
      final clientId = await repo.create(name: 'Kedd esti 4x4', steps: fourByFour());
      // Pretend the create synced: serverId filled in, queue drained.
      await (db.update(db.cardioIntervalPlans)..where((t) => t.clientId.equals(clientId)))
          .write(const CardioIntervalPlansCompanion(serverId: Value(7)));
      await db.delete(db.pendingOperations).go();

      await repo.delete(clientId);

      final ops = await db.select(db.pendingOperations).get();
      expect(ops.single.operation, 'delete');
      expect(jsonDecode(ops.single.payloadJson)['serverId'], 7);
      // The rows stay so a server rejection can bring the plan back intact —
      // only SyncEngine removes them, once the delete is confirmed.
      expect(await db.select(db.cardioIntervalPlans).get(), hasLength(1));
      expect(await db.select(db.cardioIntervalSteps).get(), hasLength(5));
      // ...and it's hidden from the list in the meantime.
      expect(await repo.watchAll().first, isEmpty);
    });
  });

  group('watchAll', () {
    test('emits plans with their trees, ordered by name', () async {
      await repo.create(name: 'Zárás', steps: const [
        IntervalStep.section(intensity: IntervalIntensity.easy, durationSeconds: 600),
      ]);
      await repo.create(name: 'Alap', steps: fourByFour());

      final plans = await repo.watchAll().first;
      expect(plans.map((p) => p.name), ['Alap', 'Zárás']);
      expect(plans.first.steps[1].children, hasLength(2));
    });
  });

  group('derived numbers (the editor header, docs/cardio/61 §3 M37)', () {
    test('total, hard time and section count fold over the tree', () async {
      final clientId = await repo.create(name: 'Kedd esti 4x4', steps: fourByFour());
      final plan = (await repo.findByClientId(clientId))!;

      // 300 + 4×(240+180) + 300 = 2280 s = 38:00
      expect(plan.totalSeconds, 2280);
      // Only the hard sections: 4×240 = 960 s = 16:00
      expect(plan.hardSeconds, 960);
      // What the player counts down: warm-up + 4×2 + cool-down
      expect(plan.sectionCount, 10);
    });
  });
}
