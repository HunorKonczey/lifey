import 'package:flutter_riverpod/flutter_riverpod.dart';

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

  Future<void> refresh() => ref.read(syncEngineProvider).sync();
}

final waterSourceControllerProvider =
    StreamNotifierProvider<WaterSourceController, List<WaterSource>>(WaterSourceController.new);
