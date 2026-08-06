import 'package:dio/dio.dart';
import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
  Future<void> send(int conversationId, String body) async {
    final trimmed = body.trim();
    if (trimmed.isEmpty) return;

    final clientId = newClientId();
    final now = DateTime.now();
    await _db.into(_db.chatMessages).insert(ChatMessagesCompanion.insert(
          clientId: clientId,
          conversationId: conversationId,
          senderId: _currentUserId(),
          body: Value(trimmed),
          createdAt: now,
          syncState: const Value('pending'),
        ));
    await _touchConversationPreview(conversationId, trimmed, now);
    await _deliver(conversationId, clientId, trimmed);
  }

  /// Manual "Resend" from the failed-bubble menu. Safe because the send is
  /// idempotent on the same [clientId] we stored the first time.
  Future<void> retry(int conversationId, String clientId) async {
    final row = await _findMessage(conversationId, clientId);
    if (row == null || row.body == null) return;
    await _setState(conversationId, clientId, 'pending');
    await _deliver(conversationId, clientId, row.body!);
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
      if (row.body == null) continue;
      await _deliver(row.conversationId, row.clientId, row.body!);
    }
  }

  /// Drops a message that never reached the server. Nothing to tell the
  /// backend about — it never knew.
  Future<void> discardUnsent(int conversationId, String clientId) async {
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
    await (_db.update(_db.chatMessages)
          ..where((t) => t.conversationId.equals(conversationId) & t.clientId.equals(clientId)))
        .write(ChatMessagesCompanion(
      body: const Value(null),
      deletedAt: Value(DateTime.now()),
    ));
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
  Future<void> _deliver(int conversationId, String clientId, String body) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        ApiEndpoints.chatMessages(conversationId),
        data: {'body': body, 'clientMessageId': clientId},
      );
      // 200 here means "you already sent this" — same handling as 201, which
      // is exactly why a blind retry is safe.
      await _storeMessages([ChatMessage.fromJson(response.data!)]);
    } catch (_) {
      await _setState(conversationId, clientId, 'failed');
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
  Future<void> _touchConversationPreview(int conversationId, String body, DateTime at) async {
    await (_db.update(_db.chatConversations)..where((t) => t.serverId.equals(conversationId)))
        .write(ChatConversationsCompanion(
      lastMessageAt: Value(at),
      lastMessagePreview: Value(body),
      lastMessageSenderId: Value(_currentUserId()),
    ));
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
