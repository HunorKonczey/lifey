import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Which client the detail pane is showing on a two-pane layout
/// (docs/chat/41-trainer-mobile-v2-plan.md §8.2). Null means "nothing picked
/// yet" — the pane then invites a choice rather than guessing one.
///
/// Only the wide layout reads this; on a phone the same tap pushes a route, so
/// this stays null there and nothing has to be kept in sync with the
/// navigator.
class SelectedClientController extends Notifier<int?> {
  @override
  int? build() => null;

  void select(int clientId) => state = clientId;

  /// Called when the client list arrives or changes: a selection that is no
  /// longer in the list (relationship ended, list refreshed) must not leave
  /// the pane showing a stranger.
  void keepOnlyIfPresent(Iterable<int> clientIds) {
    final selected = state;
    if (selected != null && !clientIds.contains(selected)) state = null;
  }
}

final selectedClientControllerProvider =
    NotifierProvider<SelectedClientController, int?>(SelectedClientController.new);
