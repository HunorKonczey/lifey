import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/local_db/app_database.dart';
import '../../../core/local_db/database_provider.dart';
import '../../../core/sync/client_id.dart';
import '../../../core/sync/outbox_writer.dart';
import '../../../core/sync/pending_delete_filter.dart';
import '../../../core/utils/combine_latest.dart';
import '../domain/cardio_interval_plan.dart';

/// Local-first access to reusable interval plans (docs/cardio/60 C7.3).
///
/// A plan is built and edited offline like any other entity: the local write
/// lands first, the outbox carries it to `/cardio-interval-plans` when there
/// is a connection. Steps are never synced on their own — the whole tree
/// travels inside the plan's payload, mirroring how the backend replaces a
/// plan's steps in full on every write.
class CardioIntervalPlanRepository {
  CardioIntervalPlanRepository(this._db, this._outbox);

  static const entityType = 'cardio_interval_plan';

  final AppDatabase _db;
  final OutboxWriter _outbox;

  /// Joins plans with their steps — Drift watches both tables, so this
  /// re-emits on a change to either side. Combined with `pending_operations`
  /// so a plan with a delete in flight (see [delete]) is filtered out without
  /// waiting on a second, separately timed provider rebuild.
  Stream<List<CardioIntervalPlan>> watchAll() {
    final query = _db.select(_db.cardioIntervalPlans).join([
      leftOuterJoin(
        _db.cardioIntervalSteps,
        _db.cardioIntervalSteps.planClientId.equalsExp(_db.cardioIntervalPlans.clientId),
      ),
    ])
      ..orderBy([
        OrderingTerm.asc(_db.cardioIntervalPlans.name),
        OrderingTerm.asc(_db.cardioIntervalSteps.stepIndex),
      ]);

    final pendingOps$ = _db.select(_db.pendingOperations).watch();
    return combineLatest2(query.watch(), pendingOps$, (rows, ops) {
      final blocked = blockedByActiveDelete(ops);
      final plans = <String, CardioIntervalPlanRow>{};
      final steps = <String, List<CardioIntervalStepRow>>{};
      for (final row in rows) {
        final plan = row.readTable(_db.cardioIntervalPlans);
        if (blocked.contains(plan.clientId)) continue;
        plans[plan.clientId] = plan;
        final step = row.readTableOrNull(_db.cardioIntervalSteps);
        if (step != null) {
          steps.putIfAbsent(plan.clientId, () => []).add(step);
        }
      }
      return plans.values.map((p) => _toDomain(p, steps[p.clientId] ?? const [])).toList();
    });
  }

  /// Single-plan lookup — what the live MACHINE screen loads the plan it is
  /// about to play back with (docs/cardio/60 C7.5).
  Future<CardioIntervalPlan?> findByClientId(String clientId) async {
    final plan = await (_db.select(_db.cardioIntervalPlans)
          ..where((t) => t.clientId.equals(clientId)))
        .getSingleOrNull();
    if (plan == null) return null;
    final steps = await (_db.select(_db.cardioIntervalSteps)
          ..where((t) => t.planClientId.equals(clientId))
          ..orderBy([(t) => OrderingTerm.asc(t.stepIndex)]))
        .get();
    return _toDomain(plan, steps);
  }

  Future<String> create({required String name, required List<IntervalStep> steps}) async {
    final clientId = newClientId();
    await _db.transaction(() async {
      await _db.into(_db.cardioIntervalPlans).insert(
            CardioIntervalPlansCompanion.insert(clientId: clientId, name: name),
          );
      await _insertSteps(clientId, steps);
    });
    await _outbox.enqueueCreate(
      clientId: clientId,
      entityType: entityType,
      payload: _payload(name: name, steps: steps),
    );
    return clientId;
  }

  Future<void> update(
    String clientId, {
    required String name,
    required List<IntervalStep> steps,
  }) async {
    await _db.transaction(() async {
      await (_db.update(_db.cardioIntervalPlans)..where((t) => t.clientId.equals(clientId)))
          .write(CardioIntervalPlansCompanion(name: Value(name)));
      await _deleteSteps(clientId);
      await _insertSteps(clientId, steps);
    });
    await _outbox.enqueueUpdate(
      clientId: clientId,
      entityType: entityType,
      payload: _payload(name: name, steps: steps),
    );
  }

  Future<void> delete(String clientId) async {
    // Must enqueue before the local row is gone — enqueueDelete needs to read
    // its serverId while the row still exists. If it queued a server delete,
    // the plan and its steps stay (hidden by [watchAll]'s filter) until that
    // delete is confirmed — see EntitySyncConfig.cleanupChildren's doc.
    final queued = await _outbox.enqueueDelete(clientId: clientId, entityType: entityType);
    if (!queued) {
      await _db.transaction(() async {
        await _deleteSteps(clientId);
        await (_db.delete(_db.cardioIntervalPlans)..where((t) => t.clientId.equals(clientId)))
            .go();
      });
    }
  }

  Future<void> _deleteSteps(String planClientId) =>
      (_db.delete(_db.cardioIntervalSteps)..where((t) => t.planClientId.equals(planClientId)))
          .go();

  /// Flattens the tree into rows: a block goes in before the steps that hang
  /// off it, and [CardioIntervalSteps.stepIndex] counts per sibling group, not
  /// across the plan — same shape the backend stores.
  Future<void> _insertSteps(
    String planClientId,
    List<IntervalStep> steps, {
    String? parentStepClientId,
  }) async {
    for (var i = 0; i < steps.length; i++) {
      final step = steps[i];
      final clientId = newClientId();
      await _db.into(_db.cardioIntervalSteps).insert(
            CardioIntervalStepsCompanion.insert(
              clientId: clientId,
              planClientId: planClientId,
              parentStepClientId: Value(parentStepClientId),
              stepIndex: i,
              stepType: step.type.wire,
              name: Value(step.name),
              intensity: Value(step.intensity?.wire),
              durationSeconds: Value(step.durationSeconds),
              repeatCount: Value(step.repeatCount),
            ),
          );
      if (step.children.isNotEmpty) {
        await _insertSteps(planClientId, step.children, parentStepClientId: clientId);
      }
    }
  }

  /// Field order mirrors the backend's `IntervalStepEntry` exactly
  /// (docs/cardio/60 C7.2). Nulls are sent explicitly rather than omitted —
  /// Jackson binds a JSON `null` to a nullable record component the same way
  /// it binds an absent key, and the shape stays obvious in the outbox.
  Map<String, dynamic> _payload({required String name, required List<IntervalStep> steps}) {
    return {
      'name': name,
      'steps': steps.map(_stepPayload).toList(),
    };
  }

  Map<String, dynamic> _stepPayload(IntervalStep step) {
    return {
      'type': step.type.wire,
      'name': step.name,
      'intensity': step.intensity?.wire,
      'durationSeconds': step.durationSeconds,
      'repeatCount': step.repeatCount,
      'children': step.children.isEmpty ? null : step.children.map(_stepPayload).toList(),
    };
  }

  /// Rebuilds the tree from the flat rows. Rows arrive ordered by
  /// [CardioIntervalSteps.stepIndex], which is per-sibling, so grouping by
  /// parent is enough — no re-sorting.
  CardioIntervalPlan _toDomain(CardioIntervalPlanRow row, List<CardioIntervalStepRow> steps) {
    final childrenByParent = <String, List<CardioIntervalStepRow>>{};
    for (final step in steps) {
      final parent = step.parentStepClientId;
      if (parent != null) {
        childrenByParent.putIfAbsent(parent, () => []).add(step);
      }
    }

    IntervalStep toStep(CardioIntervalStepRow step) {
      if (IntervalStepType.fromWire(step.stepType) == IntervalStepType.repeat) {
        return IntervalStep.block(
          name: step.name,
          repeatCount: step.repeatCount ?? 0,
          children: (childrenByParent[step.clientId] ?? const []).map(toStep).toList(),
        );
      }
      return IntervalStep.section(
        name: step.name,
        intensity: IntervalIntensity.fromWire(step.intensity ?? IntervalIntensity.easy.wire),
        durationSeconds: step.durationSeconds ?? 0,
      );
    }

    return CardioIntervalPlan(
      clientId: row.clientId,
      id: row.serverId,
      name: row.name,
      steps: steps.where((s) => s.parentStepClientId == null).map(toStep).toList(),
    );
  }
}

final cardioIntervalPlanRepositoryProvider = Provider<CardioIntervalPlanRepository>((ref) {
  return CardioIntervalPlanRepository(
    ref.watch(appDatabaseProvider),
    ref.watch(outboxWriterProvider),
  );
});
