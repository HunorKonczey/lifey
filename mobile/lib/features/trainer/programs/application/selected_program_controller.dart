import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Which program the detail pane is showing on a two-pane layout
/// (docs/chat/41-trainer-mobile-v2-plan.md §8.2). Null means nothing picked
/// yet. Phone-sized layouts push a route instead and leave this alone.
class SelectedProgramController extends Notifier<int?> {
  @override
  int? build() => null;

  void select(int programId) => state = programId;

  void keepOnlyIfPresent(Iterable<int> programIds) {
    final selected = state;
    if (selected != null && !programIds.contains(selected)) state = null;
  }
}

final selectedProgramControllerProvider =
    NotifierProvider<SelectedProgramController, int?>(SelectedProgramController.new);
