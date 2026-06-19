import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/water_source_repository.dart';
import '../domain/water_source.dart';

/// Loads and manages the user's reusable water-intake presets.
class WaterSourceController extends AsyncNotifier<List<WaterSource>> {
  WaterSourceRepository get _repo => ref.read(waterSourceRepositoryProvider);

  @override
  Future<List<WaterSource>> build() => _repo.fetchAll();

  Future<void> addSource({required String name, required double volumeLiters}) async {
    await _repo.create(name: name, volumeLiters: volumeLiters);
    state = await AsyncValue.guard(_repo.fetchAll);
  }

  Future<void> updateSource(int id, {required String name, required double volumeLiters}) async {
    await _repo.update(id, name: name, volumeLiters: volumeLiters);
    state = await AsyncValue.guard(_repo.fetchAll);
  }

  Future<void> deleteSource(int id) async {
    await _repo.delete(id);
    state = await AsyncValue.guard(_repo.fetchAll);
  }

  Future<void> refresh() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(_repo.fetchAll);
  }
}

final waterSourceControllerProvider =
    AsyncNotifierProvider<WaterSourceController, List<WaterSource>>(WaterSourceController.new);
