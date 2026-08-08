import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/chat_repository.dart';
import '../domain/chat_conversation.dart';

/// The conversation list, served from the local cache so it renders offline
/// and instantly, with a network refresh kicked off alongside.
///
/// Role-agnostic on purpose: the endpoint returns *the caller's* threads
/// whoever they are, so a trainer sees their clients and a client sees their
/// trainer through this same controller (docs/chat/40-trainer-chat-plan.md
/// §6.1). Only the screen's header, empty state and "new conversation" button
/// look at the role.
class ConversationListController extends StreamNotifier<List<ChatConversation>> {
  ChatRepository get _repo => ref.read(chatRepositoryProvider);

  @override
  Stream<List<ChatConversation>> build() {
    // Fire-and-forget: a refresh failure must not empty a list we can already
    // serve from cache. The screen surfaces staleness through the offline
    // banner instead.
    unawaited(_refreshQuietly());
    return _repo.watchConversations();
  }

  Future<void> refresh() => _repo.refreshConversations();

  Future<void> _refreshQuietly() async {
    try {
      await _repo.refreshConversations();
    } catch (_) {
      // Cached list stays on screen; see the class doc.
    }
  }
}

final conversationListControllerProvider =
    StreamNotifierProvider<ConversationListController, List<ChatConversation>>(
  ConversationListController.new,
);

/// Total unread across every thread — the dashboard app-bar badge.
/// Local-only, so it survives a cold start with no connectivity.
final unreadBadgeProvider = StreamProvider<int>((ref) {
  return ref.watch(chatRepositoryProvider).watchTotalUnread();
});
