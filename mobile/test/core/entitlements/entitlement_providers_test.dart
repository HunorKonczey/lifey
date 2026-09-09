import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifey/core/entitlements/entitlement_providers.dart';
import 'package:lifey/core/entitlements/entitlement_repository.dart';
import 'package:lifey/core/local_db/app_database.dart';
import 'package:lifey/core/local_db/database_provider.dart';
import 'package:lifey/core/network/dio_client.dart';

/// Replies with whatever [body] currently holds — set it before triggering a
/// refresh, same shape as the other fake Dio adapters in this codebase.
class _FakeAdapter implements HttpClientAdapter {
  Object? body;

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    return ResponseBody.fromString(
      jsonEncode(body),
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }
}

Map<String, dynamic> _response({
  required String tier,
  required bool adsEnabled,
  int? historyDays,
  int? aiCreditsRemaining,
}) {
  final now = DateTime.now().toUtc();
  return {
    'tier': tier,
    'source': tier == 'PRO' ? 'STRIPE' : 'NONE',
    'adsEnabled': adsEnabled,
    'historyDays': historyDays,
    'aiCreditsRemaining': aiCreditsRemaining,
    'trainer': null,
    'expiresAt': null,
    'checkedAt': now.toIso8601String(),
    'graceUntil': now.add(const Duration(days: 7)).toIso8601String(),
    'degraded': false,
  };
}

void main() {
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

  group('before any fetch (no cache)', () {
    test('adsEnabledProvider defaults to false', () async {
      // Subscribe so the stream is actually listened to and the container
      // has something to resolve — a Provider that's merely read once
      // without a listener wouldn't reflect the stream's first emission.
      container.listen(entitlementProvider, (_, __) {});
      await pumpEventQueue();

      expect(container.read(adsEnabledProvider), isFalse);
    });

    test('historyCutoffProvider and aiCreditsProvider are null (unlimited)', () async {
      container.listen(entitlementProvider, (_, __) {});
      await pumpEventQueue();

      expect(container.read(historyCutoffProvider), isNull);
      expect(container.read(aiCreditsProvider), isNull);
    });

    test('isProProvider is true, matching the fail-open default (D-P4)', () async {
      container.listen(entitlementProvider, (_, __) {});
      await pumpEventQueue();

      expect(container.read(isProProvider), isTrue);
    });
  });

  group('after a free fetch', () {
    setUp(() async {
      adapter.body = _response(tier: 'FREE', adsEnabled: true, historyDays: 30, aiCreditsRemaining: 3);
      container.listen(entitlementProvider, (_, __) {});
      await container.read(entitlementRepositoryProvider).refresh();
      await pumpEventQueue();
    });

    test('adsEnabledProvider is true', () {
      expect(container.read(adsEnabledProvider), isTrue);
    });

    test('aiCreditsProvider mirrors aiCreditsRemaining', () {
      expect(container.read(aiCreditsProvider), 3);
    });

    test('historyCutoffProvider is 30 days before today, at midnight', () {
      final cutoff = container.read(historyCutoffProvider);
      final now = DateTime.now();
      final expected = DateTime(now.year, now.month, now.day).subtract(const Duration(days: 30));

      expect(cutoff, expected);
    });

    test('isProProvider is false', () {
      expect(container.read(isProProvider), isFalse);
    });
  });

  group('after a pro fetch', () {
    setUp(() async {
      adapter.body = _response(tier: 'PRO', adsEnabled: false, historyDays: null, aiCreditsRemaining: null);
      container.listen(entitlementProvider, (_, __) {});
      await container.read(entitlementRepositoryProvider).refresh();
      await pumpEventQueue();
    });

    test('adsEnabledProvider is false', () {
      expect(container.read(adsEnabledProvider), isFalse);
    });

    test('historyCutoffProvider and aiCreditsProvider are null (unlimited)', () {
      expect(container.read(historyCutoffProvider), isNull);
      expect(container.read(aiCreditsProvider), isNull);
    });

    test('isProProvider is true', () {
      expect(container.read(isProProvider), isTrue);
    });
  });
}
