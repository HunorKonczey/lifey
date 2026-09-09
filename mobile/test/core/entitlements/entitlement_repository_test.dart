import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifey/core/entitlements/entitlement.dart';
import 'package:lifey/core/entitlements/entitlement_repository.dart';
import 'package:lifey/core/local_db/app_database.dart';

/// Records every request and replies with canned JSON — the same fake
/// adapter shape used across this codebase's Dio tests (no mocking package).
class _FakeAdapter implements HttpClientAdapter {
  final List<String> methods = [];
  final List<String> paths = [];
  Object? body;
  int statusCode = 200;
  bool throwOnFetch = false;

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
    if (throwOnFetch) {
      throw DioException(requestOptions: options, type: DioExceptionType.connectionError);
    }
    if (statusCode >= 400) {
      throw DioException(
        requestOptions: options,
        response: Response(requestOptions: options, statusCode: statusCode),
      );
    }
    return ResponseBody.fromString(
      jsonEncode(body),
      statusCode,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }
}

Map<String, dynamic> _proResponse({
  String source = 'STRIPE',
  DateTime? checkedAt,
  DateTime? graceUntil,
}) {
  final now = checkedAt ?? DateTime.now().toUtc();
  return {
    'tier': 'PRO',
    'source': source,
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

Map<String, dynamic> _freeResponse() {
  final now = DateTime.now().toUtc();
  return {
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
  };
}

void main() {
  late AppDatabase db;
  late Dio dio;
  late _FakeAdapter adapter;
  late EntitlementRepository repo;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    dio = Dio(BaseOptions(baseUrl: 'http://test'));
    adapter = _FakeAdapter();
    dio.httpClientAdapter = adapter;
    repo = EntitlementRepository(db, dio);
  });

  tearDown(() => db.close());

  group('no cache at all', () {
    test('current() resolves to the unresolved-open default', () async {
      final entitlement = await repo.current();

      expect(entitlement.resolved, isFalse);
      expect(entitlement.tier, EntitlementTier.pro);
      expect(entitlement.adsEnabled, isFalse);
      expect(entitlement.historyDays, isNull);
      expect(entitlement.aiCreditsRemaining, isNull);
    });

    test('watch() emits the unresolved-open default before any fetch', () async {
      final first = await repo.watch().first;

      expect(first.resolved, isFalse);
      expect(first.adsEnabled, isFalse);
    });
  });

  group('fetch succeeded', () {
    test('refresh() writes the cache and returns true', () async {
      adapter.body = _freeResponse();

      final ok = await repo.refresh();

      expect(ok, isTrue);
      expect(adapter.methods, ['GET']);
      expect(adapter.paths, ['/me/entitlements']);
    });

    test('current() resolves the freshly fetched entitlement', () async {
      adapter.body = _freeResponse();
      await repo.refresh();

      final entitlement = await repo.current();

      expect(entitlement.resolved, isTrue);
      expect(entitlement.tier, EntitlementTier.free);
      expect(entitlement.adsEnabled, isTrue);
      expect(entitlement.historyDays, 30);
      expect(entitlement.aiCreditsRemaining, 3);
    });

    test('a pro response with a trainer block round-trips', () async {
      final now = DateTime.now().toUtc();
      adapter.body = {
        'tier': 'PRO',
        'source': 'TRAINER_SPONSORED',
        'adsEnabled': false,
        'historyDays': null,
        'aiCreditsRemaining': null,
        'trainer': {
          'plan': 'PRO',
          'status': 'ACTIVE',
          'maxClients': 25,
          'activeClients': 11,
          'trialEndsAt': null,
        },
        'expiresAt': '2026-09-24T00:00:00Z',
        'checkedAt': now.toIso8601String(),
        'graceUntil': now.add(const Duration(days: 7)).toIso8601String(),
        'degraded': false,
      };

      await repo.refresh();
      final entitlement = await repo.current();

      expect(entitlement.source, EntitlementSource.trainerSponsored);
      expect(entitlement.trainer, isNotNull);
      expect(entitlement.trainer!.plan, 'PRO');
      expect(entitlement.trainer!.maxClients, 25);
      expect(entitlement.trainer!.activeClients, 11);
    });

    test('a second successful refresh overwrites the single row, not appends', () async {
      adapter.body = _freeResponse();
      await repo.refresh();
      adapter.body = _proResponse();
      await repo.refresh();

      final rows = await db.select(db.entitlementCacheTable).get();
      expect(rows, hasLength(1));
      expect((await repo.current()).tier, EntitlementTier.pro);
    });
  });

  group('fetch failed, within grace', () {
    test('current() keeps resolving from the last good cache', () async {
      adapter.body = _proResponse(
        checkedAt: DateTime.now().toUtc().subtract(const Duration(days: 1)),
        graceUntil: DateTime.now().toUtc().add(const Duration(days: 6)),
      );
      await repo.refresh();

      adapter.throwOnFetch = true;
      final ok = await repo.refresh();

      expect(ok, isFalse);
      final entitlement = await repo.current();
      expect(entitlement.resolved, isTrue);
      expect(entitlement.tier, EntitlementTier.pro);
      expect(entitlement.adsEnabled, isFalse);
    });
  });

  group('fetch failed, server unreachable, no prior cache', () {
    test('refresh() returns false and leaves the entitlement unresolved-open', () async {
      adapter.throwOnFetch = true;

      final ok = await repo.refresh();

      expect(ok, isFalse);
      final entitlement = await repo.current();
      expect(entitlement.resolved, isFalse);
      expect(entitlement.adsEnabled, isFalse);
    });

    test('a non-2xx status also leaves the cache untouched', () async {
      adapter.statusCode = 500;

      final ok = await repo.refresh();

      expect(ok, isFalse);
      expect((await repo.current()).resolved, isFalse);
    });
  });

  group('expired grace', () {
    test('a cached snapshot past graceUntil decays to free, not to the stale tier', () async {
      final checkedAt = DateTime.now().toUtc().subtract(const Duration(days: 10));
      final graceUntil = checkedAt.add(const Duration(days: 7)); // already in the past
      adapter.body = _proResponse(checkedAt: checkedAt, graceUntil: graceUntil);
      await repo.refresh();

      final entitlement = await repo.current();

      expect(entitlement.resolved, isTrue);
      expect(entitlement.tier, EntitlementTier.free);
      expect(entitlement.adsEnabled, isTrue);
      expect(entitlement.historyDays, isNotNull);
      expect(entitlement.aiCreditsRemaining, 0);
    });

    test('watch() reflects the same decay as current()', () async {
      final checkedAt = DateTime.now().toUtc().subtract(const Duration(days: 10));
      final graceUntil = checkedAt.add(const Duration(days: 7));
      adapter.body = _proResponse(checkedAt: checkedAt, graceUntil: graceUntil);
      await repo.refresh();

      final entitlement = await repo.watch().first;

      expect(entitlement.tier, EntitlementTier.free);
    });

    test('a snapshot exactly at graceUntil (not yet past) still resolves as cached', () async {
      final checkedAt = DateTime.now().toUtc();
      // Comfortably in the future — the "within grace" companion case to the
      // expired one above, guarding against an off-by-one in the comparison.
      final graceUntil = checkedAt.add(const Duration(seconds: 30));
      adapter.body = _proResponse(checkedAt: checkedAt, graceUntil: graceUntil);
      await repo.refresh();

      final entitlement = await repo.current();

      expect(entitlement.tier, EntitlementTier.pro);
    });
  });
}
