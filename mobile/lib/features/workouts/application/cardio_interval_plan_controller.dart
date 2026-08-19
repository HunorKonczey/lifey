import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/sync/pull_engine.dart';
import '../../../core/sync/sync_engine_provider.dart';
import '../data/cardio_interval_plan_repository.dart';
import '../domain/cardio_interval_plan.dart';

/// Streams the user's interval plans from the local cache and exposes the
/// mutations (docs/cardio/60 C7.4). Mirrors `WorkoutTemplateController` — a
/// plan is the same kind of reusable blueprint.
class CardioIntervalPlanController extends StreamNotifier<List<CardioIntervalPlan>> {
  CardioIntervalPlanRepository get _repo => ref.read(cardioIntervalPlanRepositoryProvider);

  @override
  Stream<List<CardioIntervalPlan>> build() => _repo.watchAll();

  Future<String> createPlan({required String name, required List<IntervalStep> steps}) {
    return _repo.create(name: name, steps: steps);
  }

  Future<void> updatePlan({
    required String clientId,
    required String name,
    required List<IntervalStep> steps,
  }) {
    return _repo.update(clientId, name: name, steps: steps);
  }

  Future<void> deletePlan(String clientId) => _repo.delete(clientId);

  /// Drains the outbox, then re-pulls from the server — same best-effort
  /// refresh as the template list's pull-to-refresh.
  Future<void> refresh() async {
    try {
      await ref.read(syncEngineProvider).sync();
      await ref.read(pullEngineProvider).pullAll();
    } catch (_) {
      // No connectivity or a backend hiccup leaves the cache as-is.
    }
  }
}

final cardioIntervalPlanControllerProvider =
    StreamNotifierProvider<CardioIntervalPlanController, List<CardioIntervalPlan>>(
        CardioIntervalPlanController.new);
