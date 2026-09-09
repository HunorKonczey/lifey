import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../clients/application/trainer_clients_controller.dart';
import '../../clients/domain/trainer_client.dart';
import '../domain/client_detail_tab.dart';
import 'client_detail_tab_preference.dart';

/// What the detail screen needs before it can draw anything: who the client
/// is, and which tab this trainer was last on for *them*.
class TrainerClientSummary {
  const TrainerClientSummary({required this.client, required this.initialTab});

  final TrainerClient client;
  final ClientDetailTab initialTab;
}

/// Resolves one client out of the trainer's list, plus their remembered tab.
///
/// The list is the source: it is already loaded when the trainer taps a card,
/// and it loads itself when the screen is reached by deep link instead. There
/// is deliberately no `GET /trainer/clients/{id}` call here — the list
/// endpoint already carries the header's fields, and a second endpoint would
/// be a second thing to keep in step.
///
/// A null result means "not (or no longer) your client": the relationship can
/// end between a notification being sent and its being tapped, and that is a
/// normal outcome, not an error.
final trainerClientProvider =
    FutureProvider.family<TrainerClientSummary?, int>((ref, clientId) async {
  final clients = await ref.watch(trainerClientsControllerProvider.future);

  TrainerClient? match;
  for (final client in clients) {
    if (client.userId == clientId) {
      match = client;
      break;
    }
  }
  if (match == null) return null;

  final initialTab = await ref.watch(lastClientDetailTabProvider(clientId).future);
  return TrainerClientSummary(client: match, initialTab: initialTab);
});
