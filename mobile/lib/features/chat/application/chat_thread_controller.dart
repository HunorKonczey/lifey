import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/chat_repository.dart';
import '../domain/chat_message.dart';

/// One thread's messages, oldest first (the order they render in).
///
/// The stream is the local cache, so the thread opens instantly and works
/// offline; the network only ever *adds* to it. Paging is keyset and walks
/// upwards on demand — see [loadOlder].
class ChatThreadController extends StreamNotifier<List<ChatMessage>> {
  ChatThreadController(this.conversationId);

  final int conversationId;

  ChatRepository get _repo => ref.read(chatRepositoryProvider);

  /// Goes false once the server says there is nothing older left, so the
  /// scroll listener stops asking.
  bool _hasMoreHistory = true;
  bool _loadingHistory = false;

  bool get hasMoreHistory => _hasMoreHistory;

  @override
  Stream<List<ChatMessage>> build() {
    unawaited(catchUp());
    return _repo.watchMessages(conversationId);
  }

  /// Opening, and every app resume: pull whatever arrived while we were away
  /// (gap fill above the newest id we hold), replay anything still unsent,
  /// and acknowledge the thread as read.
  Future<void> catchUp() async {
    try {
      await _repo.loadNewer(conversationId);
      await _repo.flushPending();
      await _repo.markRead(conversationId);
    } catch (_) {
      // Offline or a flaky network: the cached thread is still on screen and
      // the composer still works. Nothing to report.
    }
  }

  /// One page further back. Guarded against re-entry so a fast scroll can't
  /// fire several overlapping page loads.
  Future<void> loadOlder() async {
    if (_loadingHistory || !_hasMoreHistory) return;
    _loadingHistory = true;
    try {
      _hasMoreHistory = await _repo.loadOlder(conversationId);
    } catch (_) {
      // Leave _hasMoreHistory alone — a failed page is worth retrying on the
      // next scroll, unlike a page that genuinely came back empty.
    } finally {
      _loadingHistory = false;
    }
  }

  Future<void> send(String body) => _repo.send(conversationId, body);

  Future<void> retry(String clientId) => _repo.retry(conversationId, clientId);

  Future<void> discard(String clientId) => _repo.discardUnsent(conversationId, clientId);

  Future<void> delete(String clientId) => _repo.deleteMessage(conversationId, clientId);

  Future<void> markRead() => _repo.markRead(conversationId);
}

final chatThreadControllerProvider =
    StreamNotifierProvider.family<ChatThreadController, List<ChatMessage>, int>(
  ChatThreadController.new,
);

/// The thread's own conversation row (peer name, archived flag), watched
/// locally so the header renders before — and without — a network call.
final chatConversationProvider =
    StreamProvider.family((ref, int conversationId) {
  return ref.watch(chatRepositoryProvider).watchConversation(conversationId);
});
