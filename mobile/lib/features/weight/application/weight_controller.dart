import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/sync/sync_engine_provider.dart';
import '../data/weight_repository.dart';
import '../domain/weight_entry.dart';

/// Streams weight entries from the local cache (always live — no manual
/// reload needed after a mutation) and exposes the mutations themselves.
class WeightController extends StreamNotifier<List<WeightEntry>> {
  WeightRepository get _repo => ref.read(weightRepositoryProvider);

  @override
  Stream<List<WeightEntry>> build() => _repo.watchAll();

  Future<void> addEntry({required DateTime date, required double weight}) {
    return _repo.create(date: date, weight: weight);
  }

  Future<void> deleteEntry(String clientId) {
    return _repo.delete(clientId);
  }

  /// The list is already live; this just nudges the sync engine, e.g. for a
  /// manual pull-to-refresh gesture.
  Future<void> refresh() => ref.read(syncEngineProvider).sync();
}

final weightControllerProvider =
    StreamNotifierProvider<WeightController, List<WeightEntry>>(WeightController.new);
