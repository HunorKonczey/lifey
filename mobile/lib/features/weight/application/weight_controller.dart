import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/sync/pull_engine.dart';
import '../../../core/sync/sync_engine_provider.dart';
import '../../../core/sync/sync_status_provider.dart';
import '../data/weight_repository.dart';
import '../domain/weight_entry.dart';

/// Streams weight entries from the local cache (always live — no manual
/// reload needed after a mutation) and exposes the mutations themselves.
class WeightController extends StreamNotifier<List<WeightEntry>> {
  WeightRepository get _repo => ref.read(weightRepositoryProvider);

  @override
  Stream<List<WeightEntry>> build() {
    // An entry with a delete in flight stays in storage (so a server
    // rejection can bring it back with a failed marker), so it must be
    // filtered out here rather than relying on the row being gone.
    final activelyDeleting = ref.watch(activelyDeletingClientIdsProvider);
    return _repo
        .watchAll()
        .map((entries) => entries.where((e) => !activelyDeleting.contains(e.clientId)).toList());
  }

  Future<void> addEntry({required DateTime date, required double weight}) {
    return _repo.create(date: date, weight: weight);
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
