import 'package:flutter_test/flutter_test.dart';
import 'package:lifey/features/chat/domain/chat_conversation.dart';
import 'package:lifey/features/chat/domain/chat_message.dart';
import 'package:lifey/features/chat/domain/chat_peer.dart';

ChatConversation _conversation({int? delivered, int? read}) {
  return ChatConversation(
    id: 12,
    peer: const ChatPeer(
      userId: 88,
      displayName: 'Kiss Anna',
      email: 'anna@example.com',
      role: ChatPeerRole.client,
    ),
    unreadCount: 0,
    peerLastDeliveredMessageId: delivered,
    peerLastReadMessageId: read,
  );
}

ChatMessage _message({
  int? serverId,
  ChatMessageState state = ChatMessageState.sent,
}) {
  return ChatMessage(
    clientId: 'uuid-1',
    serverId: serverId,
    conversationId: 12,
    senderId: 7,
    body: 'hello',
    createdAt: DateTime.utc(2026, 8, 6, 9),
    state: state,
  );
}

void main() {
  group('receiptStateFor', () {
    test('is read at or below the peer read cursor', () {
      final conversation = _conversation(delivered: 120, read: 100);
      expect(receiptStateFor(_message(serverId: 100), conversation), ChatMessageState.read);
      expect(receiptStateFor(_message(serverId: 99), conversation), ChatMessageState.read);
    });

    test('is delivered above the read cursor but at or below the delivered one', () {
      final conversation = _conversation(delivered: 120, read: 100);
      expect(receiptStateFor(_message(serverId: 110), conversation), ChatMessageState.delivered);
      expect(receiptStateFor(_message(serverId: 120), conversation), ChatMessageState.delivered);
    });

    test('is only sent above both cursors, and with no cursors at all', () {
      expect(
        receiptStateFor(_message(serverId: 130), _conversation(delivered: 120, read: 100)),
        ChatMessageState.sent,
      );
      expect(receiptStateFor(_message(serverId: 130), _conversation()), ChatMessageState.sent);
    });

    test('falls back to sent while the thread row is not loaded yet', () {
      expect(receiptStateFor(_message(serverId: 130), null), ChatMessageState.sent);
    });

    test('leaves local states alone, so a cursor can never dress up an unsent message', () {
      final conversation = _conversation(delivered: 999, read: 999);
      expect(
        receiptStateFor(_message(state: ChatMessageState.pending), conversation),
        ChatMessageState.pending,
      );
      expect(
        receiptStateFor(_message(state: ChatMessageState.failed), conversation),
        ChatMessageState.failed,
      );
    });
  });
}
