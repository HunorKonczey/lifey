import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/workout_template_repository.dart';
import '../domain/workout_template.dart';

/// Loads, creates, updates and deletes workout templates.
class WorkoutTemplateController extends AsyncNotifier<List<WorkoutTemplate>> {
  WorkoutTemplateRepository get _repo => ref.read(workoutTemplateRepositoryProvider);

  @override
  Future<List<WorkoutTemplate>> build() => _repo.fetchAll();

  Future<void> createTemplate({
    required String name,
    required List<int> exerciseIds,
  }) async {
    await _repo.create(name: name, exerciseIds: exerciseIds);
    state = await AsyncValue.guard(_repo.fetchAll);
  }

  Future<void> updateTemplate({
    required int id,
    required String name,
    required List<int> exerciseIds,
  }) async {
    await _repo.update(id: id, name: name, exerciseIds: exerciseIds);
    state = await AsyncValue.guard(_repo.fetchAll);
  }

  Future<void> deleteTemplate(int id) async {
    await _repo.delete(id);
    state = await AsyncValue.guard(_repo.fetchAll);
  }

  Future<void> refresh() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(_repo.fetchAll);
  }
}

final workoutTemplateControllerProvider =
    AsyncNotifierProvider<WorkoutTemplateController, List<WorkoutTemplate>>(
        WorkoutTemplateController.new);
