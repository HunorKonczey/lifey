import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/weight_repository.dart';
import '../domain/weight_entry.dart';

/// Loads and mutates the list of weight entries.
///
/// Mutations ([addEntry]/[deleteEntry]) rethrow on failure so the UI can show
/// feedback without the list being replaced by an error state; they reload the
/// authoritative list from the server on success.
class WeightController extends AsyncNotifier<List<WeightEntry>> {
  WeightRepository get _repo => ref.read(weightRepositoryProvider);

  @override
  Future<List<WeightEntry>> build() => _repo.fetchAll();

  Future<void> addEntry({required DateTime date, required double weight}) async {
    await _repo.create(date: date, weight: weight);
    state = await AsyncValue.guard(_repo.fetchAll);
  }

  Future<void> deleteEntry(int id) async {
    await _repo.delete(id);
    state = await AsyncValue.guard(_repo.fetchAll);
  }

  Future<void> refresh() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(_repo.fetchAll);
  }
}

final weightControllerProvider =
    AsyncNotifierProvider<WeightController, List<WeightEntry>>(WeightController.new);
