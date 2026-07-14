import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/push/weigh_in_reminder_controller.dart';
import '../../../core/sync/pull_engine.dart';
import '../../../core/sync/sync_engine_provider.dart';
import '../data/weight_repository.dart';
import '../domain/weight_entry.dart';

/// Streams weight entries from the local cache (always live — no manual
/// reload needed after a mutation) and exposes the mutations themselves.
class WeightController extends StreamNotifier<List<WeightEntry>> {
  WeightRepository get _repo => ref.read(weightRepositoryProvider);

  @override
  Stream<List<WeightEntry>> build() => _repo.watchAll();

  Future<void> addEntry({required DateTime date, required double weight}) async {
    await _repo.create(date: date, weight: weight);
    // In case today's weight was just logged — skip today's weigh-in
    // reminder if it's still pending (see WeighInReminderController).
    await ref.read(weighInReminderControllerProvider).refreshForToday();
  }

  Future<void> deleteEntry(String clientId) {
    return _repo.delete(clientId);
  }

  /// The list is already live; this drains the outbox and re-pulls from the
  /// server, e.g. for a manual pull-to-refresh gesture. Both halves matter —
  /// pushing alone never reconciles a stale/corrupted local row with the
  /// server's truth.
  Future<void> refresh() async {
    try {
      await ref.read(syncEngineProvider).sync();
      await ref.read(pullEngineProvider).pullAll();
    } catch (_) {
      // Best-effort: no connectivity or a backend hiccup leaves the cache as-is.
    }
  }
}

final weightControllerProvider =
    StreamNotifierProvider<WeightController, List<WeightEntry>>(WeightController.new);
