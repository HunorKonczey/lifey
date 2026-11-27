import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:drift/native.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifey/core/health/health_preferences.dart';
import 'package:lifey/core/health/health_service.dart';
import 'package:lifey/core/health/health_sleep.dart';
import 'package:lifey/core/health/sleep_health_importer.dart';
import 'package:lifey/core/local_db/app_database.dart';
import 'package:lifey/core/sync/outbox_writer.dart';
import 'package:lifey/core/sync/sync_engine.dart';
import 'package:lifey/features/sleep/data/sleep_session_repository.dart';

/// docs/integrations/89 G2.3: the sleep importer's opt-in, cursor, dedupe and
/// the row it creates, with the cardio importer's rules (G1.5). Uses a real
/// in-memory DB and repository, so the outbox payload is the real one.
void main() {
  final now = DateTime.utc(2026, 11, 23, 12);
  late AppDatabase db;
  late SleepSessionRepository repo;
  late _Prefs prefs;
  late _Service service;
  late SleepHealthImporter importer;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    repo = SleepSessionRepository(db, OutboxWriter(db, _NoopSyncEngine(db, Dio())));
    prefs = _Prefs();
    service = _Service();
    importer = SleepHealthImporter(prefs: prefs, service: service, sessions: repo, now: () => now);
  });

  tearDown(() => db.close());

  test('does nothing unless both the Health and the sleep-import toggles are on', () async {
    service.nights = [_night('hc-1', DateTime.utc(2026, 11, 22, 6))];

    prefs.healthEnabled = false;
    expect(await importer.import(), 0);
    prefs
      ..healthEnabled = true
      ..sleepEnabled = false;
    expect(await importer.import(), 0);

    expect(service.queries, isEmpty);
    expect(await db.select(db.sleepSessions).get(), isEmpty);
  });

  test('the first run looks back 14 days, stores the night through the outbox and moves the cursor', () async {
    final end = DateTime.utc(2026, 11, 22, 6, 10);
    service.nights = [_night('hc-1', end)];

    expect(await importer.import(), 1);

    expect(service.queries.single, now.subtract(const Duration(days: 14)));
    final session = (await repo.watchAll().first).single;
    expect(session.healthRecordId, 'hc-1');
    expect(session.endedAt.toUtc(), end);
    expect(session.deepMinutes, 80);
    expect(session.sourceAppName, 'Garmin Connect');
    expect(prefs.cursor, end);

    final op = await db.select(db.pendingOperations).getSingle();
    expect(op.entityType, 'sleep_session');
    final payload = jsonDecode(op.payloadJson) as Map<String, dynamic>;
    expect(payload['healthRecordId'], 'hc-1');
    expect(payload['remMinutes'], 110);
  });

  test('a later run reads from the cursor and never imports the same night twice', () async {
    service.nights = [_night('hc-1', DateTime.utc(2026, 11, 22, 6, 10))];
    await importer.import();

    // The store still returns hc-1 (it ends exactly at the cursor) plus a newer one.
    service.nights = [
      _night('hc-1', DateTime.utc(2026, 11, 22, 6, 10)),
      _night('hc-2', DateTime.utc(2026, 11, 23, 6, 30)),
    ];
    expect(await importer.import(), 1);

    expect(service.queries.last, DateTime.utc(2026, 11, 22, 6, 10));
    expect(await db.select(db.sleepSessions).get(), hasLength(2));
    expect(prefs.cursor, DateTime.utc(2026, 11, 23, 6, 30));
  });

  test('a night without stages imports with null stage minutes', () async {
    service.nights = [_night('hc-1', DateTime.utc(2026, 11, 22, 6), staged: false)];

    await importer.import();

    final row = await db.select(db.sleepSessions).getSingle();
    expect(row.deepMinutes, isNull);
    expect(row.asleepMinutes, isNull);
  });

  test('a store failure imports nothing and leaves the cursor alone', () async {
    prefs.cursor = DateTime.utc(2026, 11, 20);
    service.fail = true;

    expect(await importer.import(), 0);
    expect(prefs.cursor, DateTime.utc(2026, 11, 20));
  });

  test('overlapping calls share one run, so a night is never created twice', () async {
    service.nights = [_night('hc-1', DateTime.utc(2026, 11, 22, 6))];

    final results = await Future.wait([importer.import(), importer.import()]);

    expect(results, [1, 1]);
    expect(service.queries, hasLength(1));
    expect(await db.select(db.sleepSessions).get(), hasLength(1));
  });
}

HealthSleepSession _night(String id, DateTime end, {bool staged = true}) => HealthSleepSession(
      healthRecordId: id,
      start: end.subtract(const Duration(hours: 7, minutes: 30)),
      end: end,
      sourceName: 'Garmin Connect',
      asleepMinutes: staged ? 420 : null,
      deepMinutes: staged ? 80 : null,
      lightMinutes: staged ? 230 : null,
      remMinutes: staged ? 110 : null,
      awakeMinutes: staged ? 30 : null,
    );

class _Prefs extends HealthPreferences {
  _Prefs() : super(const FlutterSecureStorage());

  bool healthEnabled = true;
  bool sleepEnabled = true;
  DateTime? cursor;

  @override
  Future<bool> isEnabled() async => healthEnabled;

  @override
  Future<bool> isSleepImportEnabled() async => sleepEnabled;

  @override
  Future<DateTime?> sleepImportCursor() async => cursor;

  @override
  Future<void> setSleepImportCursor(DateTime endOfLastImported) async => cursor = endOfLastImported;
}

/// Returns [nights] ending at or after `since`, as the real service does, and records every `since` it was asked for.
class _Service extends HealthService {
  List<HealthSleepSession> nights = [];
  final queries = <DateTime>[];
  bool fail = false;

  @override
  Future<List<HealthSleepSession>> recentSleepSessions({required DateTime since}) async {
    queries.add(since);
    if (fail) throw StateError('store gone');
    return [
      for (final n in nights)
        if (!n.end.isBefore(since)) n,
    ];
  }
}

class _NoopSyncEngine extends SyncEngine {
  _NoopSyncEngine(super.db, super.dio);

  @override
  Future<void> sync() async {}
}
