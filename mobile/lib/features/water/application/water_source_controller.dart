import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/sync/pull_engine.dart';
import '../../../core/sync/sync_engine_provider.dart';
import '../data/water_source_repository.dart';
import '../domain/water_source.dart';

/// Streams the user's water sources from the local cache and exposes the
/// mutations themselves.
class WaterSourceController extends StreamNotifier<List<WaterSource>> {
  WaterSourceRepository get _repo => ref.read(waterSourceRepositoryProvider);

  @override
  Stream<List<WaterSource>> build() => _repo.watchAll();

  Future<void> addSource({required String name, required double volumeLiters}) {
    return _repo.create(name: name, volumeLiters: volumeLiters);
  }

  Future<void> updateSource(String clientId, {required String name, required double volumeLiters}) {
    return _repo.update(clientId, name: name, volumeLiters: volumeLiters);
  }

  Future<void> deleteSource(String clientId) {
    return _repo.delete(clientId);
  }

  /// Drains the outbox, then re-pulls from the server — matching what the
  /// dashboard's pull-to-refresh does. Without the pull half, swiping to
  /// refresh only pushes local edits and never reconciles a stale/corrupted
  /// local row with the server's truth.
  Future<void> refresh() async {
    try {
      await ref.read(syncEngineProvider).sync();
      await ref.read(pullEngineProvider).pullAll();
    } catch (_) {
      // Best-effort: no connectivity or a backend hiccup leaves the cache as-is.
    }
  }
}

final waterSourceControllerProvider =
    StreamNotifierProvider<WaterSourceController, List<WaterSource>>(WaterSourceController.new);
