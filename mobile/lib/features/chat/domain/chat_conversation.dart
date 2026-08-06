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

  bool get isArchived => archivedAt != null;
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
    );
  }
}
