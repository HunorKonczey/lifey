import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifey/core/network/dio_client.dart';
import 'package:lifey/features/trainer_invite/application/trainer_invite_controller.dart';

/// Replies with whatever `pendingBody`/`respondStatusCode` currently hold, so
/// a single test can change the "server" response between calls (e.g. to
/// simulate the invite disappearing after acceptance, or a network failure).
class _FakeAdapter implements HttpClientAdapter {
  Object pendingBody = [];
  bool failPending = false;
  int respondStatusCode = 204;

  final List<String> methods = [];
  final List<String> paths = [];
  final List<Object?> bodies = [];

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    methods.add(options.method);
    paths.add(options.path);
    bodies.add(options.data);

    if (options.path == '/trainer-invites/pending') {
      if (failPending) {
        throw DioException.connectionError(requestOptions: options, reason: 'offline');
      }
      return ResponseBody.fromString(
        jsonEncode(pendingBody),
        200,
        headers: {
          Headers.contentTypeHeader: [Headers.jsonContentType],
        },
      );
    }
    return ResponseBody.fromString('', respondStatusCode);
  }
}

Map<String, dynamic> _invite(int id, {String email = 'trainer@example.com'}) => {
      'id': id,
      'trainerEmail': email,
      'invitedAt': '2026-07-03T10:00:00Z',
      'expiresAt': '2026-07-04T10:00:00Z',
    };

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _FakeAdapter adapter;
  late ProviderContainer container;

  setUp(() {
    adapter = _FakeAdapter();
    final dio = Dio(BaseOptions(baseUrl: 'http://test'))..httpClientAdapter = adapter;
    container = ProviderContainer(
      overrides: [dioClientProvider.overrideWithValue(dio)],
    );
    addTearDown(container.dispose);
  });

  test('build() fetches pending invites on first read', () async {
    adapter.pendingBody = [_invite(1)];

    final invites = await container.read(trainerInviteControllerProvider.future);

    expect(invites, hasLength(1));
    expect(invites.single.id, 1);
    expect(adapter.paths, ['/trainer-invites/pending']);
  });

  test('didChangeAppLifecycleState(resumed) re-fetches pending invites', () async {
    adapter.pendingBody = [_invite(1)];
    await container.read(trainerInviteControllerProvider.future);

    adapter.pendingBody = [_invite(1), _invite(2)];
    container
        .read(trainerInviteControllerProvider.notifier)
        .didChangeAppLifecycleState(AppLifecycleState.resumed);
    // The refresh is fire-and-forget (unawaited) — wait for the state to settle.
    await Future.delayed(const Duration(milliseconds: 50));

    final invites = container.read(trainerInviteControllerProvider).value!;
    expect(invites, hasLength(2));
  });

  test('other lifecycle transitions (e.g. paused) do not trigger a refetch', () async {
    adapter.pendingBody = [_invite(1)];
    await container.read(trainerInviteControllerProvider.future);
    adapter.paths.clear();

    container
        .read(trainerInviteControllerProvider.notifier)
        .didChangeAppLifecycleState(AppLifecycleState.paused);
    await Future.delayed(Duration.zero);

    expect(adapter.paths, isEmpty);
  });

  test('refresh() failure keeps the previous state instead of surfacing an error', () async {
    adapter.pendingBody = [_invite(1)];
    await container.read(trainerInviteControllerProvider.future);

    adapter.failPending = true;
    await container.read(trainerInviteControllerProvider.notifier).refresh();

    final state = container.read(trainerInviteControllerProvider);
    expect(state.hasValue, isTrue);
    expect(state.value, hasLength(1));
  });

  test('respond() posts {accept} and removes the invite from local state', () async {
    adapter.pendingBody = [_invite(1), _invite(2)];
    await container.read(trainerInviteControllerProvider.future);

    await container
        .read(trainerInviteControllerProvider.notifier)
        .respond(1, accept: true);

    expect(adapter.paths.last, '/trainer-invites/1/respond');
    expect(adapter.bodies.last, {'accept': true});

    final invites = container.read(trainerInviteControllerProvider).value!;
    expect(invites.map((i) => i.id), [2]);
  });
}
