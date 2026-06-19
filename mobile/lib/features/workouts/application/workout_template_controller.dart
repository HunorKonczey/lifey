import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/sync/sync_engine_provider.dart';
import '../data/workout_template_repository.dart';
import '../domain/workout_template.dart';

/// Streams workout templates from the local cache and exposes the mutations.
class WorkoutTemplateController extends StreamNotifier<List<WorkoutTemplate>> {
  WorkoutTemplateRepository get _repo => ref.read(workoutTemplateRepositoryProvider);

  @override
  Stream<List<WorkoutTemplate>> build() => _repo.watchAll();

  Future<void> createTemplate({
    required String name,
    required List<String> exerciseClientIds,
  }) {
    return _repo.create(name: name, exerciseClientIds: exerciseClientIds);
  }

  Future<void> updateTemplate({
    required String clientId,
    required String name,
    required List<String> exerciseClientIds,
  }) {
    return _repo.update(clientId, name: name, exerciseClientIds: exerciseClientIds);
  }

  Future<void> deleteTemplate(String clientId) => _repo.delete(clientId);

  Future<void> refresh() => ref.read(syncEngineProvider).sync();
}

final workoutTemplateControllerProvider =
    StreamNotifierProvider<WorkoutTemplateController, List<WorkoutTemplate>>(
        WorkoutTemplateController.new);
