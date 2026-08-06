/// Delivery state of one of *our own* messages. Anything received is always
/// [sent] — the states only describe the outbound path.
///
/// [delivered] and [read] cannot occur yet: the backend tracks a read cursor
/// per participant but does not report the *peer's* cursor until the SSE
/// stream lands (plan I4). They exist here so the bubble already renders all
/// four and I4 only has to supply the data.
enum ChatMessageState { pending, sent, delivered, read, failed }

class ChatMessage {
  const ChatMessage({
    required this.clientId,
    this.serverId,
    required this.conversationId,
    required this.senderId,
    this.body,
    required this.createdAt,
    this.deletedAt,
    required this.state,
  });

  /// The `clientMessageId`: our idempotency key on every send/retry, and the
  /// reason a retry can never produce a duplicate.
  final String clientId;
  final int? serverId;
  final int conversationId;
  final int senderId;

  /// Null exactly when [deletedAt] is set.
  final String? body;
  final DateTime createdAt;
  final DateTime? deletedAt;
  final ChatMessageState state;

  bool get isDeleted => deletedAt != null;

  /// A message that never reached the server has no id to delete server-side;
  /// the UI offers "discard" for these instead of "delete".
  bool get isUnsent => serverId == null;

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    return ChatMessage(
      clientId: json['clientMessageId'] as String,
      serverId: json['id'] as int,
      conversationId: json['conversationId'] as int,
      senderId: json['senderId'] as int,
      body: json['body'] as String?,
      createdAt: DateTime.parse(json['createdAt'] as String).toLocal(),
      deletedAt: json['deletedAt'] == null
          ? null
          : DateTime.parse(json['deletedAt'] as String).toLocal(),
      state: ChatMessageState.sent,
    );
  }
}
