import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:drift/native.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifey/core/local_db/app_database.dart';
import 'package:lifey/features/chat/application/chat_thread_controller.dart';
import 'package:lifey/features/chat/data/chat_repository.dart';
import 'package:lifey/features/chat/domain/chat_message.dart';

/// Canned JSON for every request, and a record of what was asked — the same
/// fake-adapter shape as the repository's own tests.
class _FakeAdapter implements HttpClientAdapter {
  final Map<String, Object> responses = {};
  final List<RequestOptions> requests = [];

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    final body = responses['${options.method} ${options.path}'] ?? const <String, dynamic>{};
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

/// A thread renders a window of its newest messages, however much of the
/// conversation this device has cached — and walking back widens that window
/// from the local rows first, going to the network only once they run out.
void main() {
  late AppDatabase db;
  late _FakeAdapter adapter;
  late ChatRepository repo;
  late ProviderContainer container;

  /// One page and a bit, so the initial window has to leave some out.
  const total = ChatRepository.pageSize + 5;

  final provider = chatThreadControllerProvider(_conversationId);

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    adapter = _FakeAdapter();
    final dio = Dio(BaseOptions(baseUrl: 'https://chat.test/api/v1'))
      ..httpClientAdapter = adapter;
    repo = ChatRepository(db, dio, () => _meId);

    adapter.responses['GET /chat/conversations/$_conversationId/messages'] = {
      'items': [
        for (var i = 1; i <= total; i++)
          {
            'id': i,
            'conversationId': _conversationId,
            'senderId': _peerId,
            'body': 'msg $i',
            'clientMessageId': 'm$i',
            // Ordered in time so "newest" is unambiguous.
            'createdAt':
                DateTime.utc(2026, 8, 6, 9, 0).add(Duration(minutes: i)).toIso8601String(),
            'deletedAt': null,
            'attachment': null,
          },
      ],
      'hasMore': true,
    };

    container = ProviderContainer(overrides: [
      chatRepositoryProvider.overrideWithValue(repo),
    ]);
  });

  tearDown(() async {
    container.dispose();
    await db.close();
  });

  /// Opens the thread the way a screen does — with a listener on it — and
  /// waits for the window to settle at [length] rows.
  Future<List<ChatMessage>> open({required int length}) async {
    container.listen(provider, (_, __) {});
    final deadline = DateTime.now().add(const Duration(seconds: 5));
    while (DateTime.now().isBefore(deadline)) {
      final value = container.read(provider).value;
      if (value != null && value.length == length) return value;
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }
    fail('the window never settled at $length messages '
        '(last: ${container.read(provider).value?.length})');
  }

  ChatThreadController notifier() => container.read(provider.notifier);

  test('the thread opens on one page, not on everything the device holds', () async {
    // Everything is cached locally first, exactly as an earlier session would
    // have left it.
    await repo.loadNewer(_conversationId);
    expect(await repo.countMessages(_conversationId), total);

    final opened = await open(length: ChatRepository.pageSize);

    // The newest page, and the newest message is the one at the bottom.
    expect(opened.last.body, 'msg $total');
  });

  test('walking back widens the window from the cache, without a request', () async {
    await repo.loadNewer(_conversationId);
    await open(length: ChatRepository.pageSize);
    // Whatever the open itself asked for; the widen must add nothing to it.
    final requestsAfterOpen = adapter.requests.length;

    await notifier().loadOlder();

    expect(adapter.requests, hasLength(requestsAfterOpen));
    expect(await open(length: total), hasLength(total));
  });

  test('once the cached rows run out, the next page comes from the server', () async {
    await repo.loadNewer(_conversationId);
    await open(length: ChatRepository.pageSize);

    await notifier().loadOlder();
    final requestsBefore = adapter.requests.length;
    // The window now covers everything on the device, so this one has to ask.
    await notifier().loadOlder();

    expect(adapter.requests.length, greaterThan(requestsBefore));
    // Keyset, from the oldest row on the device — not `requests.last`, since
    // the open's own catch-up is still finishing in the background.
    expect(adapter.requests.map((r) => r.queryParameters['before']), contains(1));
  });
}
