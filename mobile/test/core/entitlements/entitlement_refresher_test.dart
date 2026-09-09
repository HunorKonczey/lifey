import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:drift/native.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifey/core/entitlements/entitlement_refresher.dart';
import 'package:lifey/core/entitlements/entitlement_repository.dart';
import 'package:lifey/core/local_db/app_database.dart';
import 'package:lifey/core/local_db/database_provider.dart';
import 'package:lifey/core/network/dio_client.dart';
import 'package:lifey/core/network/session_events.dart';

class _FakeAdapter implements HttpClientAdapter {
  int getCount = 0;
  Object? body;

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    getCount++;
    return ResponseBody.fromString(
      jsonEncode(body),
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }
}

Map<String, dynamic> _proResponse({DateTime? checkedAt, DateTime? graceUntil}) {
  final now = checkedAt ?? DateTime.now().toUtc();
  return {
    'tier': 'PRO',
    'source': 'STRIPE',
    'adsEnabled': false,
    'historyDays': null,
    'aiCreditsRemaining': null,
    'trainer': null,
    'expiresAt': null,
    'checkedAt': now.toIso8601String(),
    'graceUntil': (graceUntil ?? now.add(const Duration(days: 7))).toIso8601String(),
    'degraded': false,
  };
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late _FakeAdapter adapter;
  late ProviderContainer container;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    adapter = _FakeAdapter();
    final dio = Dio(BaseOptions(baseUrl: 'http://test'))..httpClientAdapter = adapter;
    container = ProviderContainer(overrides: [
      appDatabaseProvider.overrideWithValue(db),
      dioClientProvider.overrideWithValue(dio),
    ]);
    addTearDown(container.dispose);
    addTearDown(db.close);
  });

  test('refreshNow() fetches unconditionally', () async {
    adapter.body = _proResponse();

    await container.read(entitlementRefresherProvider).refreshNow();

    expect(adapter.getCount, 1);
  });

  group('app resume', () {
    test('refreshes when there is no cache yet (unresolved counts as stale)', () async {
      final refresher = container.read(entitlementRefresherProvider);
      adapter.body = _proResponse();

      refresher.didChangeAppLifecycleState(AppLifecycleState.resumed);
      await pumpEventQueue();

      expect(adapter.getCount, 1);
    });

    test('refreshes when the cache is older than 15 minutes', () async {
      adapter.body = _proResponse(checkedAt: DateTime.now().toUtc().subtract(const Duration(minutes: 20)));
      final repo = container.read(entitlementRepositoryProvider);
      await repo.refresh();
      adapter.getCount = 0;

      final refresher = container.read(entitlementRefresherProvider);
      refresher.didChangeAppLifecycleState(AppLifecycleState.resumed);
      await pumpEventQueue();

      expect(adapter.getCount, 1);
    });

    test('does NOT refresh when the cache is fresh (under 15 minutes old)', () async {
      adapter.body = _proResponse(checkedAt: DateTime.now().toUtc());
      final repo = container.read(entitlementRepositoryProvider);
      await repo.refresh();
      adapter.getCount = 0;

      final refresher = container.read(entitlementRefresherProvider);
      refresher.didChangeAppLifecycleState(AppLifecycleState.resumed);
      await pumpEventQueue();

      expect(adapter.getCount, 0);
    });

    test('other lifecycle transitions (e.g. paused) never refresh', () async {
      final refresher = container.read(entitlementRefresherProvider);
      adapter.body = _proResponse();

      refresher.didChangeAppLifecycleState(AppLifecycleState.paused);
      await pumpEventQueue();

      expect(adapter.getCount, 0);
    });
  });

  test('a gate rejection (402/403) triggers a refresh', () async {
    // Constructs the refresher so its gateRejectionProvider listener is
    // wired up — mirrors it being watched once at app root in production.
    container.read(entitlementRefresherProvider);
    adapter.body = _proResponse();

    container.read(gateRejectionProvider.notifier).notify();
    await pumpEventQueue();

    expect(adapter.getCount, 1);
  });
}
