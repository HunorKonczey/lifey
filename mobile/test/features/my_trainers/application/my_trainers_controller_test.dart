import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifey/core/local_db/app_database.dart';
import 'package:lifey/core/local_db/database_provider.dart';
import 'package:lifey/core/network/dio_client.dart';
import 'package:lifey/features/my_trainers/application/my_trainers_controller.dart';

class _FakeAdapter implements HttpClientAdapter {
  Object body = [];
  final List<String> methods = [];
  final List<String> paths = [];

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
    if (options.method == 'DELETE') {
      return ResponseBody.fromString('', 204);
    }
    if (options.path == '/me/entitlements') {
      final now = DateTime.now().toUtc();
      return ResponseBody.fromString(
        jsonEncode({
          'tier': 'FREE',
          'source': 'NONE',
          'adsEnabled': true,
          'historyDays': 30,
          'aiCreditsRemaining': 3,
          'trainer': null,
          'expiresAt': null,
          'checkedAt': now.toIso8601String(),
          'graceUntil': now.add(const Duration(days: 7)).toIso8601String(),
          'degraded': false,
        }),
        200,
        headers: {
          Headers.contentTypeHeader: [Headers.jsonContentType],
        },
      );
    }
    return ResponseBody.fromString(
      jsonEncode(body),
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }
}

Map<String, dynamic> _trainer(int id, {String email = 'trainer@example.com'}) => {
      'trainerId': id,
      'trainerEmail': email,
      'activeSince': '2026-06-01T10:00:00Z',
    };

void main() {
  // EntitlementRefresher (built when leave() reads entitlementRefresherProvider)
  // registers a WidgetsBindingObserver, which needs a bound WidgetsBinding.
  TestWidgetsFlutterBinding.ensureInitialized();

  late _FakeAdapter adapter;
  late ProviderContainer container;

  setUp(() {
    adapter = _FakeAdapter();
    final dio = Dio(BaseOptions(baseUrl: 'http://test'))..httpClientAdapter = adapter;
    final db = AppDatabase(NativeDatabase.memory());
    container = ProviderContainer(
      overrides: [
        dioClientProvider.overrideWithValue(dio),
        // leave() fires a fire-and-forget entitlement refresh (D-P3) — see
        // the same override in trainer_invite_controller_test.dart.
        appDatabaseProvider.overrideWithValue(db),
      ],
    );
    addTearDown(container.dispose);
    addTearDown(db.close);
  });

  test('build() fetches the active trainers on first read', () async {
    adapter.body = [_trainer(1)];

    final trainers = await container.read(myTrainersControllerProvider.future);

    expect(trainers, hasLength(1));
    expect(trainers.single.trainerId, 1);
    expect(adapter.paths, ['/my-trainers']);
  });

  test('leave() DELETEs the relationship and removes it from local state', () async {
    adapter.body = [_trainer(1), _trainer(2)];
    await container.read(myTrainersControllerProvider.future);

    await container.read(myTrainersControllerProvider.notifier).leave(1);

    expect(adapter.paths.last, '/my-trainers/1');
    expect(adapter.methods.last, 'DELETE');
    final trainers = container.read(myTrainersControllerProvider).value!;
    expect(trainers.map((t) => t.trainerId), [2]);
  });

  test('leave() triggers an entitlement refresh (D-P3, D-M4)', () async {
    adapter.body = [_trainer(1)];
    await container.read(myTrainersControllerProvider.future);

    await container.read(myTrainersControllerProvider.notifier).leave(1);
    // The refresh is fire-and-forget (unawaited) — wait for it to settle.
    await Future.delayed(const Duration(milliseconds: 50));

    expect(adapter.paths, contains('/me/entitlements'));
  });
}
