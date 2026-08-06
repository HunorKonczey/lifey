import 'chat_message.dart';
import 'chat_peer.dart';

/// One thread as the current user sees it. Role-agnostic by design: the same
/// screen renders a client's trainer thread and a trainer's client thread,
/// and only [ChatPeer.role] tells them apart
/// (docs/chat/40-trainer-chat-plan.md §6.1).
class ChatConversation {
  const ChatConversation({
    required this.id,
    required this.peer,
    required this.unreadCount,
    this.lastMessageAt,
    this.lastMessagePreview,
    this.lastMessageSenderId,
    this.archivedAt,
    this.peerLastDeliveredMessageId,
    this.peerLastReadMessageId,
    this.mutedUntil,
  });

  final int id;
  final ChatPeer peer;
  final int unreadCount;
  final DateTime? lastMessageAt;

  /// Null both for a brand-new thread and for one whose last message was
  /// deleted — the row shows the tombstone text in the second case.
  final String? lastMessagePreview;
  final int? lastMessageSenderId;

  /// Set once the relationship ended: readable forever, not writable.
  final DateTime? archivedAt;

  /// How far the *peer* has got in this thread. Per participant rather than
  /// per message (§3.1), so "was message N read" is the question "is N at or
  /// below this cursor" — see [receiptStateFor]. Null means unknown, which
  /// renders as a plain "sent" tick rather than a guess.
  final int? peerLastDeliveredMessageId;
  final int? peerLastReadMessageId;

  /// Our *own* mute for this thread (§I5). An instant rather than a flag, so
  /// it lapses on its own — which is why [isMuted] compares instead of reading
  /// a stored boolean that could go stale.
  final DateTime? mutedUntil;

  bool get isArchived => archivedAt != null;

  bool get isMuted => mutedUntil != null && mutedUntil!.isAfter(DateTime.now());
  bool get hasUnread => unreadCount > 0;

  factory ChatConversation.fromJson(Map<String, dynamic> json) {
    final lastMessage = json['lastMessage'] as Map<String, dynamic>?;
    return ChatConversation(
      id: json['id'] as int,
      peer: ChatPeer.fromJson(json['peer'] as Map<String, dynamic>),
      unreadCount: (json['unreadCount'] as num?)?.toInt() ?? 0,
      lastMessageAt: lastMessage == null
          ? null
          : DateTime.parse(lastMessage['createdAt'] as String).toLocal(),
      lastMessagePreview: lastMessage?['body'] as String?,
      lastMessageSenderId: lastMessage?['senderId'] as int?,
      archivedAt: json['archivedAt'] == null
          ? null
          : DateTime.parse(json['archivedAt'] as String).toLocal(),
      peerLastDeliveredMessageId: (json['peerLastDeliveredMessageId'] as num?)?.toInt(),
      peerLastReadMessageId: (json['peerLastReadMessageId'] as num?)?.toInt(),
      mutedUntil: json['mutedUntil'] == null
          ? null
          : DateTime.parse(json['mutedUntil'] as String).toLocal(),
    );
  }
}

/// The tick mark for one of *our own* messages, derived from the peer's two
/// cursors rather than stored on the message — that is the shape the server
/// keeps them in (§3.1).
///
/// Anything that never reached the server keeps its local state: a `pending`
/// bubble has no id to compare, and a `failed` one must not be dressed up as
/// delivered by a cursor that moved for some other message.
ChatMessageState receiptStateFor(ChatMessage message, ChatConversation? conversation) {
  final serverId = message.serverId;
  if (message.state != ChatMessageState.sent || serverId == null || conversation == null) {
    return message.state;
  }
  final read = conversation.peerLastReadMessageId;
  if (read != null && serverId <= read) return ChatMessageState.read;
  final delivered = conversation.peerLastDeliveredMessageId;
  if (delivered != null && serverId <= delivered) return ChatMessageState.delivered;
  return ChatMessageState.sent;
}
