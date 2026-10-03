import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../my_trainers/data/my_trainers_repository.dart';
import '../data/chat_repository.dart';
import '../domain/chat_card.dart';
import '../domain/chat_peer.dart';

/// Somebody a result card can be sent to
/// (docs/chat/83-chat-result-card-plan.md §4).
///
/// [conversationId] is null for a person the user is connected to but has no
/// thread with yet: the thread is lazy-created by the server on the first
/// message, exactly as the Settings "My trainers" row does.
class ChatShareTarget {
  const ChatShareTarget({required this.peer, this.conversationId});

  final ChatPeer peer;
  final int? conversationId;
}

/// Who the current user can share a result with: every open thread (newest
/// activity first — so the first entry is the natural default), then the
/// user's trainers they have not written to yet.
///
/// Role-agnostic like the rest of the chat: a client gets their trainers, a
/// trainer gets their clients' threads. An **archived** thread is readable but
/// not writable (the relationship ended), so it is never a target.
///
/// Empty means "nobody to share with", and the entry points hide their button
/// rather than disable it. The trainer lookup is best effort — offline, the
/// existing threads are still offered.
final chatShareTargetsProvider = FutureProvider.autoDispose<List<ChatShareTarget>>((ref) async {
  final chat = ref.watch(chatRepositoryProvider);

  var conversations = await chat.watchConversations().first;
  if (conversations.isEmpty) {
    // A user who never opened the chat has an empty cache; one quiet refresh
    // tells a first-time sharer from someone with no trainer at all.
    try {
      await chat.refreshConversations();
      conversations = await chat.watchConversations().first;
    } catch (_) {
      // Offline: nothing cached, nothing to offer yet.
    }
  }

  final open = [for (final c in conversations) if (!c.isArchived) c];
  final targets = <ChatShareTarget>[
    for (final c in open) ChatShareTarget(peer: c.peer, conversationId: c.id),
  ];

  try {
    final trainers = await ref.read(myTrainersRepositoryProvider).fetchActiveTrainers();
    final known = {for (final target in targets) target.peer.userId};
    for (final trainer in trainers) {
      if (known.contains(trainer.trainerId)) continue;
      targets.add(ChatShareTarget(
        peer: ChatPeer(
          userId: trainer.trainerId,
          displayName: trainer.displayName,
          email: trainer.trainerEmail,
          role: ChatPeerRole.trainer,
        ),
      ));
    }
  } catch (_) {
    // See above.
  }
  return targets;
});

/// Hands a result card to the chat for one person.
class ChatShareService {
  ChatShareService(this._chat);

  final ChatRepository _chat;

  /// Sends [card] with [caption] to [target] and returns the thread's id.
  ///
  /// [resolveSessionId] runs only when the card does not know its session yet
  /// (a workout that has not reached the server): it gets a bounded moment to
  /// find the id, and the card is sent *either way* — with the id the trainer
  /// can open the session, without it the card is complete but static
  /// (docs/chat/83 §2.6). The send itself is the chat's own: written locally
  /// first, retried by itself when offline.
  ///
  /// Throws only when a thread has to be created and the server cannot be
  /// reached; everything after that is a state on the message, not an error.
  Future<int> share({
    required ChatShareTarget target,
    required ChatCard card,
    String caption = '',
    Future<int?> Function()? resolveSessionId,
  }) async {
    var toSend = card;
    if (card.sessionId == null && resolveSessionId != null) {
      // `then<int?>` builds a genuinely nullable future: a resolver written as
      // `() async => 481` is a Future<int> at runtime (futures are covariant), and
      // `onTimeout: () => null` on that one throws a type error.
      final id = await resolveSessionId()
          .then<int?>((value) => value)
          .timeout(const Duration(seconds: 4), onTimeout: () => null);
      if (id != null) toSend = card.withSessionId(id);
    }
    final conversationId =
        target.conversationId ?? await _chat.openConversationWith(target.peer.userId);
    await _chat.send(conversationId, caption, card: toSend);
    return conversationId;
  }
}

final chatShareServiceProvider = Provider<ChatShareService>((ref) {
  return ChatShareService(ref.watch(chatRepositoryProvider));
});
