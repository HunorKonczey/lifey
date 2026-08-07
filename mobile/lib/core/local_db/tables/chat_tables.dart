import 'package:drift/drift.dart';

/// Local cache of the trainer ↔ client chat
/// (docs/chat/40-trainer-chat-plan.md §6.1).
///
/// These two tables deliberately sit **outside** the generic sync machinery —
/// they are not in `entity_sync_config.dart` and `PullEngine` never touches
/// them. The engine's model (full pull + `updated_at` delta, one local
/// `clientId` per row) is the wrong shape here: messages are immutable and
/// keyset-paged, they arrive from outside (push today, SSE from I4), and
/// "scroll back to the beginning of the thread" cannot be expressed as
/// "pull everything". `ChatRepository` owns these tables end to end instead.

/// One thread, mirrored from the server. Unlike every other table here there
/// is no local `clientId`: a conversation is only ever created by the backend
/// (lazy-create on open), never offline, so the server id *is* the identity.
@DataClassName('ChatConversationRow')
class ChatConversations extends Table {
  @override
  String get tableName => 'chat_conversations';

  IntColumn get serverId => integer()();
  IntColumn get peerUserId => integer()();
  TextColumn get peerDisplayName => text()();
  TextColumn get peerEmail => text()();

  /// `TRAINER` / `CLIENT` — what the peer is *to this user*, which is what
  /// lets one mixed list carry both kinds for a dual-role account.
  TextColumn get peerRole => text()();

  IntColumn get unreadCount => integer().withDefault(const Constant(0))();

  /// Denormalized preview, same as the server's. Kept locally too so the list
  /// renders offline, and so an optimistically sent message shows up in it
  /// immediately rather than after the next refresh.
  DateTimeColumn get lastMessageAt => dateTime().nullable()();
  TextColumn get lastMessagePreview => text().nullable()();
  IntColumn get lastMessageSenderId => integer().nullable()();

  /// Set once the trainer-client relationship ends: readable, not writable.
  DateTimeColumn get archivedAt => dateTime().nullable()();

  /// How far the *peer* has got in this thread — the two numbers our own tick
  /// marks are drawn from (I4). Per participant rather than per message, which
  /// is why they live on the thread and not on `chat_messages`: "has message N
  /// been read" is the question "is N at or below the read cursor".
  IntColumn get peerLastDeliveredMessageId => integer().nullable()();
  IntColumn get peerLastReadMessageId => integer().nullable()();

  /// Our own per-thread mute (§I5); null or in the past means not muted.
  DateTimeColumn get mutedUntil => dateTime().nullable()();

  /// Whether the previewed message is a picture (I6). The preview text alone
  /// cannot say so: a caption-less image has no body, and a null preview
  /// already means "deleted" on this row.
  BoolColumn get lastMessageHasAttachment =>
      boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {serverId};
}

/// One message. [clientId] is the `clientMessageId` the server treats as the
/// idempotency key, so a locally created row and its eventual server echo are
/// the same row — which is what makes the optimistic bubble turn into the
/// real one instead of duplicating.
@DataClassName('ChatMessageRow')
class ChatMessages extends Table {
  @override
  String get tableName => 'chat_messages';

  TextColumn get clientId => text()();

  /// Null until the send is confirmed; also the keyset cursor for paging.
  IntColumn get serverId => integer().nullable()();

  IntColumn get conversationId => integer()();
  IntColumn get senderId => integer()();

  /// Null exactly when [deletedAt] is set — a tombstone keeps the row but
  /// not the text (the placeholder is rendered client-side, so it localizes).
  TextColumn get body => text().nullable()();

  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get deletedAt => dateTime().nullable()();

  /// `pending` | `sent` | `failed` — drives the bubble's status icon. Only
  /// our own messages are ever anything but `sent`.
  TextColumn get syncState => text().withDefault(const Constant('sent'))();

  /// Image metadata as the server reports it (I6), all set together or all
  /// null. The bubble reserves its box from these, so a thread of pictures
  /// doesn't reflow as they load.
  IntColumn get attachmentWidth => integer().nullable()();
  IntColumn get attachmentHeight => integer().nullable()();
  IntColumn get attachmentByteSize => integer().nullable()();

  /// Where the picked file waits while the send is `pending` or `failed`.
  ///
  /// This is what makes an image survive being written offline: the outbox
  /// replays a text message from [body], and without a copy of the file on
  /// disk there would be nothing to replay for a picture. Cleared — and the
  /// file deleted — once the server has it.
  TextColumn get attachmentLocalPath => text().nullable()();

  /// Composite: `clientMessageId` is only unique *within* a conversation on
  /// the server, so it alone would be the wrong key here.
  @override
  Set<Column> get primaryKey => {conversationId, clientId};
}
