import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:drift/native.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifey/core/health/health_preferences.dart';
import 'package:lifey/core/health/health_service.dart';
import 'package:lifey/core/health/health_vitals.dart';
import 'package:lifey/core/health/vitals_health_importer.dart';
import 'package:lifey/core/local_db/app_database.dart';
import 'package:lifey/core/sync/outbox_writer.dart';
import 'package:lifey/core/sync/sync_engine.dart';
import 'package:lifey/features/vitals/data/daily_vitals_repository.dart';
import 'package:lifey/features/vitals/domain/daily_vitals.dart';

/// docs/integrations/89 G3.3: the vitals importer's opt-in, whole-day read
/// window, cursor, and the days it writes, with a real in-memory DB and
/// repository so the outbox payload is the real one.
void main() {
  final now = DateTime(2026, 11, 23, 12);
  late AppDatabase db;
  late DailyVitalsRepository repo;
  late _Prefs prefs;
  late _Service service;
  late VitalsHealthImporter importer;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    repo = DailyVitalsRepository(db, OutboxWriter(db, _NoopSyncEngine(db, Dio())));
    prefs = _Prefs();
    service = _Service();
    importer = VitalsHealthImporter(prefs: prefs, service: service, vitals: repo, now: () => now);
  });

  tearDown(() => db.close());

  test('does nothing unless both the Health and the vitals-import toggles are on', () async {
    service.days = [_day(21, restingHr: 52)];

    prefs.healthEnabled = false;
    expect(await importer.import(), 0);
    prefs
      ..healthEnabled = true
      ..vitalsEnabled = false;
    expect(await importer.import(), 0);

    expect(service.queries, isEmpty);
    expect(await db.select(db.dailyVitalsTable).get(), isEmpty);
  });

  test('the first run reads 14 whole days, stores each day with its method and moves the cursor', () async {
    service.days = [
      _day(21, restingHr: 52, hrvMs: 48.5, method: HrvMethod.rmssd),
      _day(22, restingHr: 50),
    ];

    expect(await importer.import(), 2);

    expect(service.queries.single, DateTime(2026, 11, 9));
    final days = await repo.watchAll().first;
    expect(days.map((d) => d.date), [DateTime(2026, 11, 22), DateTime(2026, 11, 21)]);
    expect(days.last.hrvMs, 48.5);
    expect(days.last.hrvMethod, HrvMethod.rmssd);
    expect(prefs.cursor, DateTime(2026, 11, 22, 9));

    final payloads = [
      for (final op in await db.select(db.pendingOperations).get()) jsonDecode(op.payloadJson) as Map<String, dynamic>
    ];
    expect(payloads.first, {'date': '2026-11-21', 'restingHr': 52, 'hrvMs': 48.5, 'hrvMethod': 'RMSSD'});
  });

  test('a later run re-reads from the day before the cursor, and an unchanged day queues nothing', () async {
    service.days = [_day(22, restingHr: 50)];
    await importer.import();
    final opsAfterFirst = (await db.select(db.pendingOperations).get()).length;

    // Today's HRV arrives later; yesterday is unchanged.
    service.days = [
      _day(22, restingHr: 50),
      _day(23, hrvMs: 41, method: HrvMethod.sdnn, hour: 6),
    ];
    expect(await importer.import(), 2);

    expect(service.queries.last, DateTime(2026, 11, 21));
    expect((await db.select(db.pendingOperations).get()).length, opsAfterFirst + 1);
    expect(prefs.cursor, DateTime(2026, 11, 23, 6));
  });

  test('a later value of a day replaces its HRV together with its method', () async {
    service.days = [_day(22, hrvMs: 40, method: HrvMethod.rmssd)];
    await importer.import();

    service.days = [_day(22, hrvMs: 33, method: HrvMethod.sdnn)];
    await importer.import();

    final row = await db.select(db.dailyVitalsTable).getSingle();
    expect(row.hrvMs, 33);
    expect(row.hrvMethod, 'SDNN');
  });

  test('a store failure imports nothing and leaves the cursor alone', () async {
    prefs.cursor = DateTime(2026, 11, 20, 8);
    service.fail = true;

    expect(await importer.import(), 0);
    expect(prefs.cursor, DateTime(2026, 11, 20, 8));
  });

  test('overlapping calls share one run', () async {
    service.days = [_day(22, restingHr: 50)];

    final results = await Future.wait([importer.import(), importer.import()]);

    expect(results, [1, 1]);
    expect(service.queries, hasLength(1));
  });
}

HealthDailyVitals _day(int day, {int? restingHr, double? hrvMs, HrvMethod? method, int hour = 9}) =>
    HealthDailyVitals(
      date: DateTime(2026, 11, day),
      lastSampleAt: DateTime(2026, 11, day, hour),
      restingHr: restingHr,
      hrvMs: hrvMs,
      hrvMethod: method,
    );

class _Prefs extends HealthPreferences {
  _Prefs() : super(const FlutterSecureStorage());

  bool healthEnabled = true;
  bool vitalsEnabled = true;
  DateTime? cursor;

  @override
  Future<bool> isEnabled() async => healthEnabled;

  @override
  Future<bool> isVitalsImportEnabled() async => vitalsEnabled;

  @override
  Future<DateTime?> vitalsImportCursor() async => cursor;

  @override
  Future<void> setVitalsImportCursor(DateTime lastSampleAt) async => cursor = lastSampleAt;
}

/// Returns [days] and records every `since` it was asked for.
class _Service extends HealthService {
  List<HealthDailyVitals> days = [];
  final queries = <DateTime>[];
  bool fail = false;

  @override
  Future<List<HealthDailyVitals>> recentDailyVitals({required DateTime since}) async {
    queries.add(since);
    if (fail) throw StateError('store gone');
    return days;
  }
}

class _NoopSyncEngine extends SyncEngine {
  _NoopSyncEngine(super.db, super.dio);

  @override
  Future<void> sync() async {}
}
