import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/my_trainers_repository.dart';
import '../domain/my_trainer.dart';

/// The current user's active trainers, for the Settings "Edzőim" section
/// (docs/personal_trainer/05-mobil-terv.md §3). Fetched once per screen
/// visit — no polling, since leaving is the only thing that can change it
/// from the client's side, and that's driven by this same controller.
class MyTrainersController extends AsyncNotifier<List<MyTrainer>> {
  MyTrainersRepository get _repo => ref.read(myTrainersRepositoryProvider);

  @override
  Future<List<MyTrainer>> build() => _repo.fetchActiveTrainers();

  Future<void> leave(int trainerId) async {
    await _repo.leave(trainerId);
    final current = state.value ?? [];
    state = AsyncData(current.where((t) => t.trainerId != trainerId).toList());
  }
}

final myTrainersControllerProvider =
    AsyncNotifierProvider<MyTrainersController, List<MyTrainer>>(
  MyTrainersController.new,
);
