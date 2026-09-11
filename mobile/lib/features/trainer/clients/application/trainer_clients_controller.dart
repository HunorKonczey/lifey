import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/trainer_clients_repository.dart';
import '../domain/compliance.dart';
import '../domain/trainer_client.dart';

/// The trainer's client list — the daily entry point of the trainer view.
///
/// Online-first (docs/chat/41-trainer-mobile-v2-plan.md §2.2): the list is
/// fetched on entry and on pull-to-refresh, with no local cache behind it, so
/// an error state here is a real "you are looking at nothing", not a stale
/// fallback.
class TrainerClientsController extends AsyncNotifier<List<TrainerClient>> {
  @override
  Future<List<TrainerClient>> build() {
    return ref.read(trainerClientsRepositoryProvider).fetchActiveClients();
  }

  /// Pull-to-refresh and the retry button. Deliberately does *not* move the
  /// state to loading first: the list stays on screen while the new one is
  /// fetched, and the RefreshIndicator is already saying that work is in
  /// flight — a spinner in its place would blank a screen the trainer is
  /// reading.
  Future<void> refresh() async {
    state = await AsyncValue.guard(
      () => ref.read(trainerClientsRepositoryProvider).fetchActiveClients(),
    );
  }
}

final trainerClientsControllerProvider =
    AsyncNotifierProvider<TrainerClientsController, List<TrainerClient>>(
  TrainerClientsController.new,
);

/// The chip row's current selection. In-memory only — it resets to
/// [ClientSortOption.recent] on app restart, matching the web, where the sort
/// is page state rather than a saved preference.
class ClientSortController extends Notifier<ClientSortOption> {
  @override
  ClientSortOption build() => ClientSortOption.recent;

  void select(ClientSortOption option) => state = option;
}

final clientSortControllerProvider =
    NotifierProvider<ClientSortController, ClientSortOption>(ClientSortController.new);
