import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/chat_repository.dart';
import '../data/trainer_clients_repository.dart';
import '../domain/trainer_client_option.dart';
import 'conversation_list_controller.dart';

/// Clients the trainer has no thread with yet — the only thing the "new
/// conversation" sheet can usefully offer, since an existing thread is
/// already one tap away in the list behind it.
///
/// Trainer-only by construction: `/trainer/clients` requires ROLE_TRAINER, so
/// this is never built for a plain client (the sheet that reads it is only
/// reachable from a button the role gate hides).
class NewConversationController extends AsyncNotifier<List<TrainerClientOption>> {
  @override
  Future<List<TrainerClientOption>> build() async {
    final clients = await ref.read(trainerClientsRepositoryProvider).fetchActiveClients();
    final existingPeers = (await ref.watch(conversationListControllerProvider.future))
        .map((conversation) => conversation.peer.userId)
        .toSet();
    return clients.where((client) => !existingPeers.contains(client.userId)).toList();
  }

  /// Opens (lazy-creates) the thread and returns its id so the sheet can
  /// navigate straight into it.
  Future<int> startWith(int clientUserId) async {
    final conversationId =
        await ref.read(chatRepositoryProvider).openConversationWith(clientUserId);
    // The new thread has to appear in the list behind the sheet, and drop out
    // of this picker.
    ref.invalidate(conversationListControllerProvider);
    return conversationId;
  }
}

final newConversationControllerProvider =
    AsyncNotifierProvider<NewConversationController, List<TrainerClientOption>>(
  NewConversationController.new,
);
