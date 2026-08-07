import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/constants/api_endpoints.dart';
import '../../../core/local_db/app_database.dart';
import '../../../core/local_db/database_provider.dart';
import '../../../core/network/dio_client.dart';
import '../../../core/sync/client_id.dart';
import '../../auth/application/auth_controller.dart';
import '../domain/chat_conversation.dart';
import '../domain/chat_message.dart';
import '../domain/chat_peer.dart';

/// Local-first chat access, owned end to end by this class.
///
/// Unlike every other repository here it does **not** go through
/// `OutboxWriter`/`SyncEngine` (docs/chat/40-trainer-chat-plan.md §6.1): the
/// outbox drains on a timer and pulls everything, which is wrong for an
/// immutable, keyset-paged, externally-appended stream. So it reads and writes
/// Drift *and* calls `dio` directly, and keeps its own tiny outbox — the
/// `pending` rows in `chat_messages`, replayed by [flushPending].
///
/// The one rule that makes all of this safe is the server's idempotency on
/// `clientMessageId`: a resend of a message that actually landed comes back
/// as the stored message (200) rather than creating a second one, so retrying
/// blindly is always correct.
class ChatRepository {
  ChatRepository(this._db, this._dio, this._currentUserId);

  final AppDatabase _db;
  final Dio _dio;

  /// Who "me" is, for the sender id of an optimistically written bubble.
  /// Injected rather than read from the token here so the repository stays
  /// testable without a signed-in session.
  final int Function() _currentUserId;

  static const _pageSize = 30;

  // --- conversations -----------------------------------------------------

  Stream<List<ChatConversation>> watchConversations() {
    final query = _db.select(_db.chatConversations)
      ..orderBy([
        // Newest activity first; a thread with no messages yet sorts last.
        (t) => OrderingTerm(expression: t.lastMessageAt, mode: OrderingMode.desc),
        (t) => OrderingTerm(expression: t.serverId, mode: OrderingMode.desc),
      ]);
    return query.watch().map((rows) => rows.map(_toConversation).toList());
  }

  Future<void> refreshConversations() async {
    final response = await _dio.get<Map<String, dynamic>>(ApiEndpoints.chatConversations);
    final items = (response.data?['items'] as List<dynamic>? ?? [])
        .map((json) => ChatConversation.fromJson(json as Map<String, dynamic>))
        .toList();

    await _db.transaction(() async {
      // Threads the server no longer returns can't exist — a conversation is
      // never deleted, only archived, so anything missing here means it
      // belongs to a different account than the one that filled this cache.
      final keep = items.map((c) => c.id).toSet();
      await (_db.delete(_db.chatConversations)..where((t) => t.serverId.isNotIn(keep))).go();
      for (final conversation in items) {
        await _upsertConversation(conversation);
      }
    });
  }

  /// Lazy-create by peer user id — the entry point mobile has, since the
  /// relationship id only exists on the trainer's web client detail page.
  /// Returns the thread id, ready to navigate to.
  Future<int> openConversationWith(int peerUserId) async {
    final response = await _dio.post<Map<String, dynamic>>(
      ApiEndpoints.chatConversationWithUser(peerUserId),
    );
    final conversation = ChatConversation.fromJson(response.data!);
    await _upsertConversation(conversation);
    return conversation.id;
  }

  Future<ChatConversation?> findConversation(int conversationId) async {
    final row = await (_db.select(_db.chatConversations)
          ..where((t) => t.serverId.equals(conversationId)))
        .getSingleOrNull();
    return row == null ? null : _toConversation(row);
  }

  Stream<ChatConversation?> watchConversation(int conversationId) {
    return (_db.select(_db.chatConversations)..where((t) => t.serverId.equals(conversationId)))
        .watchSingleOrNull()
        .map((row) => row == null ? null : _toConversation(row));
  }

  /// Total unread across every thread — the dashboard badge.
  Stream<int> watchTotalUnread() {
    final unread = _db.chatConversations.unreadCount.sum();
    final query = _db.selectOnly(_db.chatConversations)..addColumns([unread]);
    return query.watchSingle().map((row) => row.read(unread) ?? 0);
  }

  // --- messages ----------------------------------------------------------

  Stream<List<ChatMessage>> watchMessages(int conversationId) {
    final query = _db.select(_db.chatMessages)
      ..where((t) => t.conversationId.equals(conversationId))
      ..orderBy([
        (t) => OrderingTerm(expression: t.createdAt),
        // Stable tiebreaker so two messages in the same millisecond don't
        // swap places between rebuilds.
        (t) => OrderingTerm(expression: t.clientId),
      ]);
    return query.watch().map((rows) => rows.map(_toMessage).toList());
  }

  /// Fetches everything newer than what we already hold. Used on open and on
  /// app resume; with no local messages it just loads the newest page.
  Future<void> loadNewer(int conversationId) async {
    final newest = await _newestServerId(conversationId);
    final items = await _fetchMessages(
      conversationId,
      query: newest == null ? null : {'after': newest},
    );
    await _storeMessages(items);
  }

  /// One page further into history. Returns whether more remain, so the
  /// thread controller knows when to stop asking.
  Future<bool> loadOlder(int conversationId) async {
    final oldest = await _oldestServerId(conversationId);
    final response = await _dio.get<Map<String, dynamic>>(
      ApiEndpoints.chatMessages(conversationId),
      queryParameters: {'limit': _pageSize, if (oldest != null) 'before': oldest},
    );
    final items = (response.data?['items'] as List<dynamic>? ?? [])
        .map((json) => ChatMessage.fromJson(json as Map<String, dynamic>))
        .toList();
    await _storeMessages(items);
    return response.data?['hasMore'] as bool? ?? false;
  }

  /// Writes the bubble immediately, then tries the network. Offline (or on
  /// any failure) the row simply stays `pending` and [flushPending] picks it
  /// up later — the composer is never blocked on connectivity.
  Future<void> send(int conversationId, String body, {File? image}) async {
    final trimmed = body.trim();
    // A picture on its own is a complete message; text alone must not be blank.
    if (trimmed.isEmpty && image == null) return;

    final clientId = newClientId();
    final now = DateTime.now();
    // Copied out of the picker's cache before anything else: that cache is the
    // OS's to clear, and an image queued offline may wait there for days.
    final localPath = image == null ? null : await _stageAttachment(clientId, image);

    await _db.into(_db.chatMessages).insert(ChatMessagesCompanion.insert(
          clientId: clientId,
          conversationId: conversationId,
          senderId: _currentUserId(),
          body: Value(trimmed.isEmpty ? null : trimmed),
          createdAt: now,
          syncState: const Value('pending'),
          attachmentLocalPath: Value(localPath),
        ));
    await _touchConversationPreview(
      conversationId,
      trimmed.isEmpty ? null : trimmed,
      now,
      hasAttachment: localPath != null,
    );
    await _deliver(conversationId, clientId, trimmed, localPath);
  }

  /// Manual "Resend" from the failed-bubble menu. Safe because the send is
  /// idempotent on the same [clientId] we stored the first time.
  Future<void> retry(int conversationId, String clientId) async {
    final row = await _findMessage(conversationId, clientId);
    if (row == null || (row.body == null && row.attachmentLocalPath == null)) return;
    await _setState(conversationId, clientId, 'pending');
    await _deliver(conversationId, clientId, row.body ?? '', row.attachmentLocalPath);
  }

  /// Replays every unsent message, oldest first, so a thread that was written
  /// offline arrives in the order it was typed. Called on connectivity
  /// restore and on app resume.
  Future<void> flushPending() async {
    final rows = await (_db.select(_db.chatMessages)
          ..where((t) => t.serverId.isNull())
          ..orderBy([(t) => OrderingTerm(expression: t.createdAt)]))
        .get();
    for (final row in rows) {
      if (row.body == null && row.attachmentLocalPath == null) continue;
      await _deliver(
        row.conversationId,
        row.clientId,
        row.body ?? '',
        row.attachmentLocalPath,
      );
    }
  }

  /// Drops a message that never reached the server. Nothing to tell the
  /// backend about — it never knew.
  Future<void> discardUnsent(int conversationId, String clientId) async {
    final row = await _findMessage(conversationId, clientId);
    await _discardStagedAttachment(row?.attachmentLocalPath);
    await (_db.delete(_db.chatMessages)
          ..where((t) => t.conversationId.equals(conversationId) & t.clientId.equals(clientId)))
        .go();
  }

  /// Tombstones one of our own sent messages: the row survives on both sides
  /// so the other person keeps the context of their replies.
  Future<void> deleteMessage(int conversationId, String clientId) async {
    final row = await _findMessage(conversationId, clientId);
    if (row == null) return;
    if (row.serverId == null) {
      await discardUnsent(conversationId, clientId);
      return;
    }
    await _dio.delete<void>(ApiEndpoints.chatMessage(row.serverId!));
    await _tombstone(conversationId, row.serverId!, DateTime.now());
  }

  /// Acknowledges everything currently in the thread. Clears the local unread
  /// count straight away so the badge reacts even if the request is slow;
  /// the next refresh reconciles it with the server's own count.
  Future<void> markRead(int conversationId) async {
    final newest = await _newestServerId(conversationId);
    if (newest == null) return;
    await (_db.update(_db.chatConversations)
          ..where((t) => t.serverId.equals(conversationId)))
        .write(const ChatConversationsCompanion(unreadCount: Value(0)));
    await _dio.post<void>(
      ApiEndpoints.chatConversationRead(conversationId),
      data: {'lastReadMessageId': newest},
    );
  }

  // --- realtime (I4) -----------------------------------------------------

  /// The newest server id we hold across *every* thread — the `Last-Event-ID`
  /// a reconnecting stream replays from. Thread-scoped cursors would be wrong
  /// here: one stream carries all conversations.
  Future<int?> newestServerIdAcrossThreads() async {
    final maxId = _db.chatMessages.serverId.max();
    final query = _db.selectOnly(_db.chatMessages)..addColumns([maxId]);
    return (await query.getSingle()).read(maxId);
  }

  /// Applies an `event: message` frame.
  ///
  /// The unread count is bumped locally rather than refetched: the frame is
  /// enough to keep the badge honest, and the next conversation refresh
  /// reconciles it with the server's own count anyway. A message we sent
  /// ourselves — echoed back because our other devices need it — never counts.
  Future<void> applyIncomingMessage(int conversationId, ChatMessage message) async {
    await _storeMessages([message]);

    final isOwn = message.senderId == _currentUserId();
    final row = await (_db.select(_db.chatConversations)
          ..where((t) => t.serverId.equals(conversationId)))
        .getSingleOrNull();
    if (row == null) {
      // A thread this device has never loaded (a brand-new conversation, or a
      // cache that was cleared). The row arrives with the next refresh.
      return;
    }

    await (_db.update(_db.chatConversations)..where((t) => t.serverId.equals(conversationId)))
        .write(ChatConversationsCompanion(
      lastMessageAt: Value(message.createdAt),
      lastMessagePreview: Value(message.body),
      lastMessageSenderId: Value(message.senderId),
      lastMessageHasAttachment: Value(message.attachment != null),
      unreadCount: Value(isOwn ? row.unreadCount : row.unreadCount + 1),
    ));
  }

  /// Applies an `event: read` frame: how far the peer has got, which is what
  /// our own sent bubbles' tick marks are drawn from.
  Future<void> applyReadReceipt(
    int conversationId, {
    required int? lastDeliveredMessageId,
    required int? lastReadMessageId,
  }) async {
    await (_db.update(_db.chatConversations)..where((t) => t.serverId.equals(conversationId)))
        .write(ChatConversationsCompanion(
      peerLastDeliveredMessageId: Value(lastDeliveredMessageId),
      peerLastReadMessageId: Value(lastReadMessageId),
    ));
  }

  /// Applies an `event: deleted` frame — the peer (or another of our own
  /// devices) tombstoned a message.
  ///
  /// This is the only frame that changes a row we already hold. Without it the
  /// text would stay on screen indefinitely, because the catch-up query only
  /// ever asks for ids *above* the newest one cached.
  Future<void> applyDeletedMessage(
    int conversationId,
    int messageId,
    DateTime deletedAt,
  ) async {
    await _tombstone(conversationId, messageId, deletedAt);
  }

  /// Silences this thread's pushes until [mutedUntil]; null unmutes (§I5).
  /// Written locally first so the row's bell icon reacts immediately.
  Future<void> setMuted(int conversationId, DateTime? mutedUntil) async {
    await (_db.update(_db.chatConversations)..where((t) => t.serverId.equals(conversationId)))
        .write(ChatConversationsCompanion(mutedUntil: Value(mutedUntil)));
    await _dio.put<void>(
      ApiEndpoints.chatConversationMute(conversationId),
      data: {'mutedUntil': mutedUntil?.toUtc().toIso8601String()},
    );
  }

  /// Tells the server which thread is on screen, so it can skip a push the
  /// reader does not need (§5.1). Never throws: presence is an optimisation,
  /// and losing it costs an unnecessary notification, never a message.
  Future<void> setPresence(int? conversationId) async {
    try {
      await _dio.post<void>(
        ApiEndpoints.chatPresence,
        data: {'activeConversationId': conversationId},
      );
    } catch (_) {
      // See above.
    }
  }

  // --- internals ---------------------------------------------------------

  /// One send attempt. Never throws: a failure is a state on the row, not an
  /// error the composer has to handle — that is the whole point of the
  /// optimistic bubble.
  Future<void> _deliver(
    int conversationId,
    String clientId,
    String body,
    String? attachmentPath,
  ) async {
    try {
      final hasImage = attachmentPath != null && File(attachmentPath).existsSync();
      final response = await _dio.post<Map<String, dynamic>>(
        ApiEndpoints.chatMessages(conversationId),
        data: hasImage
            ? FormData.fromMap({
                'file': await MultipartFile.fromFile(attachmentPath),
                if (body.isNotEmpty) 'body': body,
                'clientMessageId': clientId,
              })
            : {'body': body, 'clientMessageId': clientId},
        onSendProgress: hasImage
            ? (sent, total) => _publishProgress(clientId, total <= 0 ? null : sent / total)
            : null,
      );
      // 200 here means "you already sent this" — same handling as 201, which
      // is exactly why a blind retry is safe.
      await _storeMessages([ChatMessage.fromJson(response.data!)]);
      // The server has the bytes now; the staged copy is dead weight, and the
      // server echo has already cleared the path column.
      await _discardStagedAttachment(attachmentPath);
    } catch (_) {
      await _setState(conversationId, clientId, 'failed');
    } finally {
      _publishProgress(clientId, null);
    }
  }

  // --- attachments (I6) ---------------------------------------------------

  /// Upload progress per `clientMessageId`, 0..1, absent when nothing is in
  /// flight. In memory rather than in Drift on purpose: a row write per
  /// progress tick would be a database transaction per network chunk.
  final _uploadProgress = <String, double>{};
  final _progressController = StreamController<Map<String, double>>.broadcast();

  Stream<Map<String, double>> watchUploadProgress() =>
      _progressController.stream.map((snapshot) => Map.unmodifiable(snapshot));

  void _publishProgress(String clientId, double? value) {
    if (value == null) {
      _uploadProgress.remove(clientId);
    } else {
      _uploadProgress[clientId] = value;
    }
    if (!_progressController.isClosed) _progressController.add(_uploadProgress);
  }

  /// Copies the picked file somewhere we control, keyed by the message's own
  /// id. `image_picker` hands back a path in a cache directory the OS may
  /// reclaim at any time — fine for an upload that starts now, not for one
  /// that waits for the plane to land.
  Future<String> _stageAttachment(String clientId, File source) async {
    final dir = Directory(p.join((await getApplicationDocumentsDirectory()).path, 'chat_outbox'));
    if (!await dir.exists()) await dir.create(recursive: true);
    final staged = File(p.join(dir.path, '$clientId.jpg'));
    await source.copy(staged.path);
    return staged.path;
  }

  Future<void> _discardStagedAttachment(String? path) async {
    if (path == null) return;
    final file = File(path);
    if (await file.exists()) await file.delete();
  }

  /// Bytes of a message's picture: the bubble-sized thumbnail, or the full
  /// image when someone opens it. Cached on disk under the message id and
  /// revalidated with an ETag — the stored image never changes, so after the
  /// first fetch this is a 304 at worst.
  Future<Uint8List?> fetchAttachment(int messageId, {bool thumbnail = true}) async {
    final prefs = await SharedPreferences.getInstance();
    final suffix = thumbnail ? 'thumb' : 'full';
    final etagKey = 'chat_attachment_etag_${messageId}_$suffix';
    final dir = Directory(p.join((await getApplicationDocumentsDirectory()).path, 'chat_images'));
    if (!await dir.exists()) await dir.create(recursive: true);
    final file = File(p.join(dir.path, '$messageId-$suffix.jpg'));
    final etag = prefs.getString(etagKey);

    try {
      final response = await _dio.get<List<int>>(
        thumbnail
            ? ApiEndpoints.chatAttachmentThumbnail(messageId)
            : ApiEndpoints.chatAttachment(messageId),
        options: Options(
          responseType: ResponseType.bytes,
          headers: etag != null ? {'If-None-Match': etag} : null,
          validateStatus: (code) => code == 200 || code == 304 || code == 404,
        ),
      );

      if (response.statusCode == 304) {
        return file.existsSync() ? file.readAsBytes() : null;
      }
      if (response.statusCode == 404) {
        // The sender deleted the message — the picture is genuinely gone, so
        // the cached copy has to go with it.
        await prefs.remove(etagKey);
        if (file.existsSync()) await file.delete();
        return null;
      }

      final bytes = Uint8List.fromList(response.data!);
      await file.writeAsBytes(bytes, flush: true);
      final newEtag = response.headers.value('etag');
      if (newEtag != null) await prefs.setString(etagKey, newEtag);
      return bytes;
    } on DioException {
      // Offline with a cached copy is not a failure — that is the whole point
      // of keeping one.
      return file.existsSync() ? file.readAsBytes() : null;
    }
  }

  /// Drops every cached chat picture without touching the server — called on
  /// logout, so the next account on this device inherits nothing.
  Future<void> clearAttachmentCache() async {
    final root = await getApplicationDocumentsDirectory();
    for (final name in ['chat_images', 'chat_outbox']) {
      final dir = Directory(p.join(root.path, name));
      if (await dir.exists()) await dir.delete(recursive: true);
    }
  }

  Future<List<ChatMessage>> _fetchMessages(
    int conversationId, {
    Map<String, dynamic>? query,
  }) async {
    final response = await _dio.get<Map<String, dynamic>>(
      ApiEndpoints.chatMessages(conversationId),
      queryParameters: {'limit': _pageSize, ...?query},
    );
    return (response.data?['items'] as List<dynamic>? ?? [])
        .map((json) => ChatMessage.fromJson(json as Map<String, dynamic>))
        .toList();
  }

  Future<void> _storeMessages(List<ChatMessage> messages) async {
    if (messages.isEmpty) return;
    await _db.batch((batch) {
      for (final message in messages) {
        batch.insert(
          _db.chatMessages,
          ChatMessagesCompanion.insert(
            clientId: message.clientId,
            serverId: Value(message.serverId),
            conversationId: message.conversationId,
            senderId: message.senderId,
            body: Value(message.body),
            createdAt: message.createdAt,
            deletedAt: Value(message.deletedAt),
            syncState: const Value('sent'),
            attachmentWidth: Value(message.attachment?.width),
            attachmentHeight: Value(message.attachment?.height),
            attachmentByteSize: Value(message.attachment?.byteSize),
            // Deliberately left null: the server has the picture, so the
            // staged copy is no longer the source of truth for this row.
            attachmentLocalPath: const Value(null),
          ),
          // The server's copy always wins over the optimistic one — this is
          // where a `pending` bubble becomes a real message rather than a
          // duplicate of it.
          mode: InsertMode.insertOrReplace,
        );
      }
    });
  }

  Future<void> _upsertConversation(ChatConversation conversation) {
    return _db.into(_db.chatConversations).insertOnConflictUpdate(
          ChatConversationsCompanion.insert(
            serverId: Value(conversation.id),
            peerUserId: conversation.peer.userId,
            peerDisplayName: conversation.peer.displayName,
            peerEmail: conversation.peer.email,
            peerRole: conversation.peer.role.name.toUpperCase(),
            unreadCount: Value(conversation.unreadCount),
            lastMessageAt: Value(conversation.lastMessageAt),
            lastMessagePreview: Value(conversation.lastMessagePreview),
            lastMessageSenderId: Value(conversation.lastMessageSenderId),
            lastMessageHasAttachment: Value(conversation.lastMessageHasAttachment),
            archivedAt: Value(conversation.archivedAt),
            peerLastDeliveredMessageId: Value(conversation.peerLastDeliveredMessageId),
            peerLastReadMessageId: Value(conversation.peerLastReadMessageId),
            mutedUntil: Value(conversation.mutedUntil),
          ),
        );
  }

  /// Keeps the conversation list in step with an optimistic send, so the row
  /// jumps to the top the moment the bubble appears rather than after a
  /// refresh that may be minutes away (or offline, never).
  Future<void> _touchConversationPreview(
    int conversationId,
    String? body,
    DateTime at, {
    bool hasAttachment = false,
  }) async {
    await (_db.update(_db.chatConversations)..where((t) => t.serverId.equals(conversationId)))
        .write(ChatConversationsCompanion(
      lastMessageAt: Value(at),
      lastMessagePreview: Value(body),
      lastMessageSenderId: Value(_currentUserId()),
      lastMessageHasAttachment: Value(hasAttachment),
    ));
  }

  /// Clears one message's text and stamps it deleted, wherever the deletion
  /// came from — our own menu or a `deleted` frame. Idempotent, because the
  /// device that performed the deletion also receives the frame for it.
  ///
  /// The conversation preview follows only when the tombstoned message *is* the
  /// newest one: a null preview is what the row renders as "message deleted",
  /// and blanking it for an older message would misreport the thread.
  Future<void> _tombstone(int conversationId, int messageId, DateTime deletedAt) async {
    final existing = await (_db.select(_db.chatMessages)
          ..where((t) =>
              t.conversationId.equals(conversationId) &
              t.serverId.equals(messageId) &
              t.deletedAt.isNull()))
        .getSingleOrNull();
    if (existing == null) return;

    await (_db.update(_db.chatMessages)
          ..where((t) =>
              t.conversationId.equals(conversationId) & t.serverId.equals(messageId)))
        .write(ChatMessagesCompanion(
      body: const Value(null),
      deletedAt: Value(deletedAt),
      // The server dropped the bytes, so the metadata that says "there is a
      // picture here" has to go with them.
      attachmentWidth: const Value(null),
      attachmentHeight: const Value(null),
      attachmentByteSize: const Value(null),
    ));
    if (existing.attachmentWidth != null) {
      await _evictCachedAttachment(messageId);
    }

    // The *last row of the thread*, not the highest server id: an unsent bubble
    // sitting after it owns the preview and has no server id at all.
    final last = await (_db.select(_db.chatMessages)
          ..where((t) => t.conversationId.equals(conversationId))
          ..orderBy([
            (t) => OrderingTerm(expression: t.createdAt, mode: OrderingMode.desc),
            (t) => OrderingTerm(expression: t.clientId, mode: OrderingMode.desc),
          ])
          ..limit(1))
        .getSingleOrNull();
    if (last?.serverId == messageId) {
      await (_db.update(_db.chatConversations)..where((t) => t.serverId.equals(conversationId)))
          .write(const ChatConversationsCompanion(
        lastMessagePreview: Value(null),
        lastMessageHasAttachment: Value(false),
      ));
    }
  }

  /// A tombstoned picture is gone on the server, so the cached copy would be
  /// the only place it still existed.
  ///
  /// Best effort: this is cache housekeeping, and a filesystem that refuses
  /// must not undo a tombstone the server has already accepted.
  Future<void> _evictCachedAttachment(int messageId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final dir = Directory(p.join((await getApplicationDocumentsDirectory()).path, 'chat_images'));
      for (final suffix in ['thumb', 'full']) {
        await prefs.remove('chat_attachment_etag_${messageId}_$suffix');
        final file = File(p.join(dir.path, '$messageId-$suffix.jpg'));
        if (await file.exists()) await file.delete();
      }
    } catch (_) {
      // See above.
    }
  }

  Future<void> _setState(int conversationId, String clientId, String state) {
    return (_db.update(_db.chatMessages)
          ..where((t) => t.conversationId.equals(conversationId) & t.clientId.equals(clientId)))
        .write(ChatMessagesCompanion(syncState: Value(state)));
  }

  Future<ChatMessageRow?> _findMessage(int conversationId, String clientId) {
    return (_db.select(_db.chatMessages)
          ..where((t) => t.conversationId.equals(conversationId) & t.clientId.equals(clientId)))
        .getSingleOrNull();
  }

  Future<int?> _newestServerId(int conversationId) async {
    final maxId = _db.chatMessages.serverId.max();
    final query = _db.selectOnly(_db.chatMessages)
      ..addColumns([maxId])
      ..where(_db.chatMessages.conversationId.equals(conversationId));
    return (await query.getSingle()).read(maxId);
  }

  Future<int?> _oldestServerId(int conversationId) async {
    final minId = _db.chatMessages.serverId.min();
    final query = _db.selectOnly(_db.chatMessages)
      ..addColumns([minId])
      ..where(_db.chatMessages.conversationId.equals(conversationId));
    return (await query.getSingle()).read(minId);
  }

  ChatConversation _toConversation(ChatConversationRow row) {
    return ChatConversation(
      id: row.serverId,
      peer: ChatPeer(
        userId: row.peerUserId,
        displayName: row.peerDisplayName,
        email: row.peerEmail,
        role: row.peerRole == 'TRAINER' ? ChatPeerRole.trainer : ChatPeerRole.client,
      ),
      unreadCount: row.unreadCount,
      lastMessageAt: row.lastMessageAt,
      lastMessagePreview: row.lastMessagePreview,
      lastMessageSenderId: row.lastMessageSenderId,
      archivedAt: row.archivedAt,
      peerLastDeliveredMessageId: row.peerLastDeliveredMessageId,
      peerLastReadMessageId: row.peerLastReadMessageId,
      mutedUntil: row.mutedUntil,
      lastMessageHasAttachment: row.lastMessageHasAttachment,
    );
  }

  ChatMessage _toMessage(ChatMessageRow row) {
    return ChatMessage(
      clientId: row.clientId,
      serverId: row.serverId,
      conversationId: row.conversationId,
      senderId: row.senderId,
      body: row.body,
      createdAt: row.createdAt,
      deletedAt: row.deletedAt,
      attachment: row.attachmentWidth == null
          ? null
          : ChatAttachment(
              width: row.attachmentWidth!,
              height: row.attachmentHeight ?? row.attachmentWidth!,
              byteSize: row.attachmentByteSize ?? 0,
            ),
      attachmentLocalPath: row.attachmentLocalPath,
      state: switch (row.syncState) {
        'pending' => ChatMessageState.pending,
        'failed' => ChatMessageState.failed,
        _ => ChatMessageState.sent,
      },
    );
  }
}

final chatRepositoryProvider = Provider<ChatRepository>((ref) {
  return ChatRepository(
    ref.watch(appDatabaseProvider),
    ref.watch(dioClientProvider),
    // No separate call: the id is already a claim on the access token the
    // session was built from.
    () => ref.read(authControllerProvider).value?.id ?? -1,
  );
});
