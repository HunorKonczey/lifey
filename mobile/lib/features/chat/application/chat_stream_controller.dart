import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/api_endpoints.dart';
import '../../../core/network/dio_client.dart';
import '../data/chat_repository.dart';
import '../data/chat_stream_client.dart';
import '../domain/chat_message.dart';
import 'chat_typing_controller.dart';

/// Holds the chat stream open while the app is in the foreground, and folds
/// every frame into the local cache (docs/chat/40-trainer-chat-plan.md I4).
///
/// **Foreground only, on purpose.** The OS kills a socket held by a
/// backgrounded app anyway, and from that moment push is the delivery channel —
/// which is exactly the "did they see it" rule the server needs (§5.1). So
/// going to the background closes the stream *and* clears presence, and
/// resuming reconnects with a `Last-Event-ID` that replays whatever was missed.
class ChatStreamController with WidgetsBindingObserver {
  ChatStreamController(this._repository, this._client, {required this.onPeerTyping}) {
    WidgetsBinding.instance.addObserver(this);
    _connect();
  }

  final ChatRepository _repository;
  final ChatStreamClient _client;

  /// Where a `typing` frame goes. A callback rather than a repository call
  /// because typing touches no storage at all — it is the one frame with
  /// nothing to write down (§19.4/1).
  final void Function(int conversationId) onPeerTyping;

  /// Which thread is on screen, remembered so it can be re-reported after a
  /// reconnect — the server's presence entry is in memory and does not survive
  /// a restart on its side either.
  int? _activeConversationId;

  bool _connected = false;

  bool get isConnected => _connected;

  /// Called by the thread screen on open (with an id) and on close (null).
  Future<void> setActiveConversation(int? conversationId) async {
    _activeConversationId = conversationId;
    await _repository.setPresence(conversationId);
  }

  void _connect() {
    _client.connect(
      lastEventId: _repository.newestServerIdAcrossThreads,
      onFrame: _onFrame,
      onConnectionChange: (connected) {
        final reconnected = connected && !_connected;
        _connected = connected;
        if (reconnected && _activeConversationId != null) {
          unawaited(_repository.setPresence(_activeConversationId));
        }
      },
    );
  }

  void _onFrame(ChatStreamFrame frame) {
    switch (frame.name) {
      case 'message':
        final payload = frame.data['message'] as Map<String, dynamic>?;
        final conversationId = (frame.data['conversationId'] as num?)?.toInt();
        if (payload == null || conversationId == null) return;
        unawaited(_repository.applyIncomingMessage(
          conversationId,
          ChatMessage.fromJson(payload),
        ));
      case 'read':
        final conversationId = (frame.data['conversationId'] as num?)?.toInt();
        if (conversationId == null) return;
        unawaited(_repository.applyReadReceipt(
          conversationId,
          lastDeliveredMessageId: (frame.data['lastDeliveredMessageId'] as num?)?.toInt(),
          lastReadMessageId: (frame.data['lastReadMessageId'] as num?)?.toInt(),
        ));
      case 'typing':
        final conversationId = (frame.data['conversationId'] as num?)?.toInt();
        if (conversationId == null) return;
        onPeerTyping(conversationId);
      case 'deleted':
        final conversationId = (frame.data['conversationId'] as num?)?.toInt();
        final messageId = (frame.data['messageId'] as num?)?.toInt();
        final deletedAt = frame.data['deletedAt'] as String?;
        if (conversationId == null || messageId == null) return;
        unawaited(_repository.applyDeletedMessage(
          conversationId,
          messageId,
          deletedAt == null ? DateTime.now() : DateTime.parse(deletedAt).toLocal(),
        ));
      case 'resync':
        // The server could not bridge the gap. The stream is a fast path over
        // REST, never the truth, so fall back to a plain refresh.
        unawaited(_resync());
    }
  }

  Future<void> _resync() async {
    try {
      await _repository.refreshConversations();
      final active = _activeConversationId;
      if (active != null) await _repository.loadNewer(active);
    } catch (_) {
      // Best effort — the next resume or timer tick tries again.
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _connect();
      if (_activeConversationId != null) {
        unawaited(_repository.setPresence(_activeConversationId));
      }
      return;
    }
    if (state == AppLifecycleState.paused || state == AppLifecycleState.detached) {
      unawaited(_client.disconnect());
      _connected = false;
      // Backgrounded means not looking at anything, so pushes must resume at
      // once rather than waiting for the server's presence TTL to lapse.
      unawaited(_repository.setPresence(null));
    }
  }

  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    unawaited(_client.disconnect());
  }
}

/// Plain (non-autoDispose) provider: created once for the app's lifetime,
/// alongside `connectivitySyncControllerProvider`.
///
/// It does get rebuilt for one reason: [chatDioProvider] watches the runtime
/// chat base URL, so if the backend moves the chat to another host this
/// controller is disposed (which disconnects the stream) and recreated against
/// the new one — no app restart, no stale connection
/// (docs/chat/44-chat-service-extraction-plan.md §7.1).
final chatStreamControllerProvider = Provider<ChatStreamController>((ref) {
  final controller = ChatStreamController(
    ref.watch(chatRepositoryProvider),
    ChatStreamClient(ref.watch(chatDioProvider), ApiEndpoints.chatStream),
    onPeerTyping: (conversationId) =>
        ref.read(chatTypingControllerProvider.notifier).peerTyping(conversationId),
  );
  ref.onDispose(controller.dispose);
  return controller;
});
