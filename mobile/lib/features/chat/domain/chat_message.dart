/// Delivery state of one of *our own* messages. Anything received is always
/// [sent] — the states only describe the outbound path.
///
/// Only [pending], [sent] and [failed] are ever *stored*: [delivered] and
/// [read] are derived per render from the thread's peer cursors, because the
/// server keeps them as two per-participant numbers rather than per message.
/// See `receiptStateFor` in `chat_conversation.dart`.
enum ChatMessageState { pending, sent, delivered, read, failed }

/// What a message's picture looks like before any of it is downloaded — the
/// numbers the bubble reserves its box from, so a thread of images doesn't
/// reflow as they arrive.
class ChatAttachment {
  const ChatAttachment({
    required this.width,
    required this.height,
    required this.byteSize,
  });

  final int width;
  final int height;
  final int byteSize;

  double get aspectRatio => height == 0 ? 1 : width / height;

  factory ChatAttachment.fromJson(Map<String, dynamic> json) {
    return ChatAttachment(
      width: (json['width'] as num).toInt(),
      height: (json['height'] as num).toInt(),
      byteSize: (json['byteSize'] as num).toInt(),
    );
  }
}

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
    this.attachment,
    this.attachmentLocalPath,
  });

  /// The `clientMessageId`: our idempotency key on every send/retry, and the
  /// reason a retry can never produce a duplicate.
  final String clientId;
  final int? serverId;
  final int conversationId;
  final int senderId;

  /// Null when [deletedAt] is set, and also when the message is a picture with
  /// no caption — an image on its own is a complete message.
  final String? body;
  final DateTime createdAt;
  final DateTime? deletedAt;
  final ChatMessageState state;

  /// Set once the server has the picture.
  final ChatAttachment? attachment;

  /// Path to the picked file while the send is still `pending` or `failed`.
  /// This is the copy the outbox replays from, so an image written offline
  /// goes out on reconnect just like a text message does.
  final String? attachmentLocalPath;

  bool get hasAttachment => attachment != null || attachmentLocalPath != null;

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
      attachment: json['attachment'] == null
          ? null
          : ChatAttachment.fromJson(json['attachment'] as Map<String, dynamic>),
    );
  }
}
