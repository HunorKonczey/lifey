import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifey/core/local_db/app_database.dart';
import 'package:lifey/features/chat/data/chat_repository.dart';
import 'package:lifey/features/chat/domain/chat_message.dart';

/// Canned responses keyed by "METHOD path", with every request recorded —
/// same fake-adapter shape as the other Dio tests here, no mocking package.
class _FakeAdapter implements HttpClientAdapter {
  final Map<String, Object> responses = {};

  /// For the send endpoint, whose response must echo the request's own
  /// `clientMessageId` — that echo is exactly what turns the optimistic
  /// bubble into the confirmed message instead of a second one.
  final Map<String, Object Function(RequestOptions)> builders = {};

  final List<RequestOptions> requests = [];

  /// Paths listed here throw instead of replying — how "offline" is
  /// simulated, since the repository must treat any failure the same way.
  final Set<String> failing = {};

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    final key = '${options.method} ${options.path}';
    if (failing.contains(options.path)) {
      throw DioException.connectionError(
        requestOptions: options,
        reason: 'offline',
      );
    }
    final body = builders[key]?.call(options) ?? responses[key] ?? const <String, dynamic>{};
    return ResponseBody.fromString(
      jsonEncode(body),
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }
}

const _meId = 7;
const _peerId = 88;
const _conversationId = 12;

Map<String, dynamic> _conversationJson({
  int unreadCount = 0,
  Map<String, dynamic>? lastMessage,
  String? archivedAt,
}) {
  return {
    'id': _conversationId,
    'peer': {
      'userId': _peerId,
      'displayName': 'Kiss Anna',
      'email': 'anna@example.com',
      'role': 'CLIENT',
    },
    'lastMessage': lastMessage,
    'unreadCount': unreadCount,
    'archivedAt': archivedAt,
  };
}

Map<String, dynamic> _messageJson({
  required int id,
  required String clientMessageId,
  int senderId = _peerId,
  String? body = 'hello',
  String createdAt = '2026-08-06T09:00:00Z',
  String? deletedAt,
}) {
  return {
    'id': id,
    'conversationId': _conversationId,
    'senderId': senderId,
    'body': body,
    'clientMessageId': clientMessageId,
    'createdAt': createdAt,
    'deletedAt': deletedAt,
  };
}

void main() {
  late AppDatabase db;
  late Dio dio;
  late _FakeAdapter adapter;
  late ChatRepository repo;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    dio = Dio(BaseOptions(baseUrl: 'http://test'));
    adapter = _FakeAdapter();
    dio.httpClientAdapter = adapter;
    repo = ChatRepository(db, dio, () => _meId);
  });

  tearDown(() => db.close());

  Future<void> seedConversation({
    int unreadCount = 0,
    String? archivedAt,
  }) async {
    adapter.responses['GET /chat/conversations'] = {
      'items': [_conversationJson(unreadCount: unreadCount, archivedAt: archivedAt)],
    };
    await repo.refreshConversations();
  }

  RequestOptions requestFor(String method, String path) =>
      adapter.requests.lastWhere((r) => r.method == method && r.path == path);

  // --- conversations -----------------------------------------------------

  group('conversations', () {
    test('refresh caches the list so it renders offline', () async {
      await seedConversation(unreadCount: 2);

      final conversations = await repo.watchConversations().first;
      expect(conversations, hasLength(1));
      expect(conversations.single.peer.displayName, 'Kiss Anna');
      expect(conversations.single.unreadCount, 2);
      expect(conversations.single.isArchived, isFalse);
    });

    test('refresh drops threads the server no longer returns', () async {
      await seedConversation();
      adapter.responses['GET /chat/conversations'] = {'items': <dynamic>[]};

      await repo.refreshConversations();

      expect(await repo.watchConversations().first, isEmpty);
    });

    test('an archived thread stays in the cache, flagged', () async {
      await seedConversation(archivedAt: '2026-08-01T10:00:00Z');

      expect((await repo.watchConversations().first).single.isArchived, isTrue);
    });

    test('total unread sums every thread, for the badge', () async {
      await seedConversation(unreadCount: 3);

      expect(await repo.watchTotalUnread().first, 3);
    });

    test('total unread is zero with no threads at all', () async {
      expect(await repo.watchTotalUnread().first, 0);
    });
  });

  // --- optimistic send ---------------------------------------------------

  group('send', () {
    test('writes the bubble before the network answers, then confirms it', () async {
      await seedConversation();
      adapter.builders['POST /chat/conversations/$_conversationId/messages'] = (options) =>
          _messageJson(
            id: 4310,
            clientMessageId: (options.data as Map<String, dynamic>)['clientMessageId'] as String,
            senderId: _meId,
            body: 'Persze!',
          );

      await repo.send(_conversationId, 'Persze!');

      final messages = await repo.watchMessages(_conversationId).first;
      expect(messages, hasLength(1));
      expect(messages.single.state, ChatMessageState.sent);
      expect(messages.single.serverId, 4310);
    });

    test('a failed send leaves the message visible and marked failed', () async {
      await seedConversation();
      adapter.failing.add('/chat/conversations/$_conversationId/messages');

      await repo.send(_conversationId, 'written offline');

      final messages = await repo.watchMessages(_conversationId).first;
      expect(messages.single.state, ChatMessageState.failed);
      expect(messages.single.body, 'written offline');
      expect(messages.single.isUnsent, isTrue);
    });

    test('an empty or whitespace-only body is not sent at all', () async {
      await seedConversation();

      await repo.send(_conversationId, '   ');

      expect(await repo.watchMessages(_conversationId).first, isEmpty);
    });

    test('the send carries a clientMessageId, which is what makes retry safe', () async {
      await seedConversation();
      adapter.responses['POST /chat/conversations/$_conversationId/messages'] =
          _messageJson(id: 1, clientMessageId: 'x', senderId: _meId);

      await repo.send(_conversationId, 'hi');

      final body = requestFor('POST', '/chat/conversations/$_conversationId/messages').data
          as Map<String, dynamic>;
      expect(body['clientMessageId'], isNotEmpty);
      expect(body['body'], 'hi');
    });

    test('an optimistic send moves its thread to the top of the list right away', () async {
      await seedConversation();
      adapter.failing.add('/chat/conversations/$_conversationId/messages');

      await repo.send(_conversationId, 'preview me');

      final conversation = (await repo.watchConversations().first).single;
      expect(conversation.lastMessagePreview, 'preview me');
      expect(conversation.lastMessageSenderId, _meId);
      expect(conversation.lastMessageAt, isNotNull);
    });
  });

  // --- retry -------------------------------------------------------------

  group('retry', () {
    test('reuses the original clientMessageId so the server can de-duplicate', () async {
      await seedConversation();
      adapter.failing.add('/chat/conversations/$_conversationId/messages');
      await repo.send(_conversationId, 'once');
      final firstAttempt = requestFor('POST', '/chat/conversations/$_conversationId/messages').data
          as Map<String, dynamic>;

      adapter.failing.clear();
      adapter.responses['POST /chat/conversations/$_conversationId/messages'] = _messageJson(
        id: 500,
        clientMessageId: firstAttempt['clientMessageId'] as String,
        senderId: _meId,
        body: 'once',
      );

      final failed = (await repo.watchMessages(_conversationId).first).single;
      await repo.retry(_conversationId, failed.clientId);

      final retryAttempt = requestFor('POST', '/chat/conversations/$_conversationId/messages').data
          as Map<String, dynamic>;
      expect(retryAttempt['clientMessageId'], firstAttempt['clientMessageId']);

      // One row, not two: the server echo replaced the optimistic bubble.
      final messages = await repo.watchMessages(_conversationId).first;
      expect(messages, hasLength(1));
      expect(messages.single.state, ChatMessageState.sent);
    });

    test('flushPending replays unsent messages oldest first', () async {
      await seedConversation();
      adapter.failing.add('/chat/conversations/$_conversationId/messages');
      await repo.send(_conversationId, 'first');
      await repo.send(_conversationId, 'second');

      adapter.failing.clear();
      var nextId = 900;
      adapter.builders['POST /chat/conversations/$_conversationId/messages'] = (options) =>
          _messageJson(
            id: nextId++,
            clientMessageId: (options.data as Map<String, dynamic>)['clientMessageId'] as String,
            senderId: _meId,
          );
      adapter.requests.clear();

      await repo.flushPending();

      final sentBodies = adapter.requests
          .where((r) => r.method == 'POST')
          .map((r) => (r.data as Map<String, dynamic>)['body'])
          .toList();
      expect(sentBodies, ['first', 'second']);
    });
  });

  // --- keyset paging -----------------------------------------------------

  group('paging', () {
    test('loadNewer asks for everything above the newest id it already holds', () async {
      await seedConversation();
      adapter.responses['GET /chat/conversations/$_conversationId/messages'] = {
        'items': [_messageJson(id: 100, clientMessageId: 'a')],
        'hasMore': false,
      };
      await repo.loadNewer(_conversationId);
      adapter.responses['GET /chat/conversations/$_conversationId/messages'] = {
        'items': <dynamic>[],
        'hasMore': false,
      };

      await repo.loadNewer(_conversationId);

      final query =
          requestFor('GET', '/chat/conversations/$_conversationId/messages').queryParameters;
      expect(query['after'], 100);
      expect(query.containsKey('before'), isFalse);
    });

    test('the first load has no cursor at all', () async {
      await seedConversation();
      adapter.responses['GET /chat/conversations/$_conversationId/messages'] = {
        'items': <dynamic>[],
        'hasMore': false,
      };

      await repo.loadNewer(_conversationId);

      final query =
          requestFor('GET', '/chat/conversations/$_conversationId/messages').queryParameters;
      expect(query.containsKey('after'), isFalse);
    });

    test('loadOlder pages back from the oldest id held, and reports hasMore', () async {
      await seedConversation();
      adapter.responses['GET /chat/conversations/$_conversationId/messages'] = {
        'items': [
          _messageJson(id: 200, clientMessageId: 'b'),
          _messageJson(id: 199, clientMessageId: 'a'),
        ],
        'hasMore': true,
      };

      final hasMore = await repo.loadOlder(_conversationId);

      expect(hasMore, isTrue);
      final query =
          requestFor('GET', '/chat/conversations/$_conversationId/messages').queryParameters;
      // First call: nothing cached yet, so no cursor.
      expect(query.containsKey('before'), isFalse);

      await repo.loadOlder(_conversationId);
      final second =
          requestFor('GET', '/chat/conversations/$_conversationId/messages').queryParameters;
      expect(second['before'], 199);
    });

    test('pages stitch together without duplicating the overlap', () async {
      await seedConversation();
      adapter.responses['GET /chat/conversations/$_conversationId/messages'] = {
        'items': [
          _messageJson(id: 3, clientMessageId: 'c', createdAt: '2026-08-06T09:03:00Z'),
          _messageJson(id: 2, clientMessageId: 'b', createdAt: '2026-08-06T09:02:00Z'),
        ],
        'hasMore': true,
      };
      await repo.loadOlder(_conversationId);

      // A page that repeats id 2 — the upsert must absorb it, not double it.
      adapter.responses['GET /chat/conversations/$_conversationId/messages'] = {
        'items': [
          _messageJson(id: 2, clientMessageId: 'b', createdAt: '2026-08-06T09:02:00Z'),
          _messageJson(id: 1, clientMessageId: 'a', createdAt: '2026-08-06T09:01:00Z'),
        ],
        'hasMore': false,
      };
      await repo.loadOlder(_conversationId);

      final messages = await repo.watchMessages(_conversationId).first;
      expect(messages.map((m) => m.serverId), [1, 2, 3]);
    });
  });

  // --- read receipts and deletion ----------------------------------------

  group('read receipts', () {
    test('acknowledges the newest message and clears the badge immediately', () async {
      await seedConversation(unreadCount: 4);
      adapter.responses['GET /chat/conversations/$_conversationId/messages'] = {
        'items': [_messageJson(id: 4310, clientMessageId: 'a')],
        'hasMore': false,
      };
      await repo.loadNewer(_conversationId);

      await repo.markRead(_conversationId);

      final body =
          requestFor('POST', '/chat/conversations/$_conversationId/read').data as Map<String, dynamic>;
      expect(body['lastReadMessageId'], 4310);
      expect(await repo.watchTotalUnread().first, 0);
    });

    test('an empty thread has nothing to acknowledge', () async {
      await seedConversation();

      await repo.markRead(_conversationId);

      expect(
        adapter.requests.any((r) => r.path.endsWith('/read')),
        isFalse,
      );
    });
  });

  group('deletion', () {
    test('a sent message is tombstoned on the server and locally', () async {
      await seedConversation();
      adapter.responses['GET /chat/conversations/$_conversationId/messages'] = {
        'items': [_messageJson(id: 4310, clientMessageId: 'mine', senderId: _meId)],
        'hasMore': false,
      };
      await repo.loadNewer(_conversationId);

      await repo.deleteMessage(_conversationId, 'mine');

      expect(adapter.requests.any((r) => r.method == 'DELETE' && r.path == '/chat/messages/4310'),
          isTrue);
      final message = (await repo.watchMessages(_conversationId).first).single;
      expect(message.isDeleted, isTrue);
      expect(message.body, isNull);
    });

    test('an unsent message is just dropped — the server never knew about it', () async {
      await seedConversation();
      adapter.failing.add('/chat/conversations/$_conversationId/messages');
      await repo.send(_conversationId, 'never made it');
      final unsent = (await repo.watchMessages(_conversationId).first).single;
      adapter.requests.clear();

      await repo.deleteMessage(_conversationId, unsent.clientId);

      expect(await repo.watchMessages(_conversationId).first, isEmpty);
      expect(adapter.requests.any((r) => r.method == 'DELETE'), isFalse);
    });
  });

  // --- opening -----------------------------------------------------------

  test('opening by peer user id caches the thread and returns its id', () async {
    adapter.responses['POST /chat/conversations/with-user/$_peerId'] = _conversationJson();

    final conversationId = await repo.openConversationWith(_peerId);

    expect(conversationId, _conversationId);
    expect(await repo.findConversation(_conversationId), isNotNull);
  });

  // --- realtime (I4) -----------------------------------------------------

  group('stream frames', () {
    test('an incoming message lands in the thread and bumps the unread count', () async {
      await seedConversation();

      await repo.applyIncomingMessage(
        _conversationId,
        ChatMessage.fromJson(_messageJson(id: 4310, clientMessageId: 'peer-1', body: 'szia')),
      );

      final messages = await repo.watchMessages(_conversationId).first;
      expect(messages.single.body, 'szia');
      final conversation = await repo.findConversation(_conversationId);
      expect(conversation!.unreadCount, 1);
      expect(conversation.lastMessagePreview, 'szia');
    });

    test('our own message echoed back to our other devices is never unread', () async {
      await seedConversation();

      await repo.applyIncomingMessage(
        _conversationId,
        ChatMessage.fromJson(
          _messageJson(id: 4311, clientMessageId: 'mine-1', senderId: _meId, body: 'én írtam'),
        ),
      );

      final conversation = await repo.findConversation(_conversationId);
      expect(conversation!.unreadCount, 0);
      expect(conversation.lastMessagePreview, 'én írtam');
    });

    test('the server echo replaces our optimistic bubble instead of duplicating it', () async {
      await seedConversation();
      adapter.builders['POST /chat/conversations/$_conversationId/messages'] = (options) {
        final body = options.data as Map<String, dynamic>;
        return _messageJson(
          id: 4312,
          clientMessageId: body['clientMessageId'] as String,
          senderId: _meId,
          body: body['body'] as String,
        );
      };
      await repo.send(_conversationId, 'hello');
      final sent = (await repo.watchMessages(_conversationId).first).single;

      // The same message arriving again over the stream — our own send is
      // broadcast back to every device we have, including this one.
      await repo.applyIncomingMessage(
        _conversationId,
        ChatMessage.fromJson(
          _messageJson(id: 4312, clientMessageId: sent.clientId, senderId: _meId, body: 'hello'),
        ),
      );

      expect(await repo.watchMessages(_conversationId).first, hasLength(1));
    });

    test('a read receipt stores the peer cursors the tick marks read from', () async {
      await seedConversation();

      await repo.applyReadReceipt(
        _conversationId,
        lastDeliveredMessageId: 4320,
        lastReadMessageId: 4310,
      );

      final conversation = await repo.findConversation(_conversationId);
      expect(conversation!.peerLastDeliveredMessageId, 4320);
      expect(conversation.peerLastReadMessageId, 4310);
    });

    test('the reconnect cursor is the newest id across every thread', () async {
      await seedConversation();
      expect(await repo.newestServerIdAcrossThreads(), isNull);

      await repo.applyIncomingMessage(
        _conversationId,
        ChatMessage.fromJson(_messageJson(id: 4310, clientMessageId: 'a')),
      );
      await repo.applyIncomingMessage(
        _conversationId,
        ChatMessage.fromJson(_messageJson(id: 4315, clientMessageId: 'b')),
      );

      expect(await repo.newestServerIdAcrossThreads(), 4315);
    });

    test('muting writes locally first, then tells the server', () async {
      await seedConversation();
      final until = DateTime.now().add(const Duration(hours: 1));

      await repo.setMuted(_conversationId, until);

      expect((await repo.findConversation(_conversationId))!.isMuted, isTrue);
      final request = requestFor('PUT', '/chat/conversations/$_conversationId/mute');
      expect((request.data as Map)['mutedUntil'], until.toUtc().toIso8601String());
    });

    test('unmuting clears the local flag and sends a null', () async {
      await seedConversation();
      await repo.setMuted(_conversationId, DateTime.now().add(const Duration(hours: 1)));

      await repo.setMuted(_conversationId, null);

      expect((await repo.findConversation(_conversationId))!.isMuted, isFalse);
      expect(
        (requestFor('PUT', '/chat/conversations/$_conversationId/mute').data as Map)['mutedUntil'],
        isNull,
      );
    });

    test('a mute in the past has already lapsed', () async {
      // The mute is an instant, not a flag, so nothing has to sweep it.
      await seedConversation();
      await repo.setMuted(_conversationId, DateTime.now().subtract(const Duration(minutes: 1)));

      expect((await repo.findConversation(_conversationId))!.isMuted, isFalse);
    });

    test('presence is reported, and a failure to report it is swallowed', () async {
      await repo.setPresence(_conversationId);
      expect(requestFor('POST', '/chat/presence').data, {'activeConversationId': _conversationId});

      adapter.failing.add('/chat/presence');
      // Presence is an optimisation: losing it costs a needless notification,
      // never a message, so it must never surface as an error.
      await expectLater(repo.setPresence(null), completes);
    });
  });
}
