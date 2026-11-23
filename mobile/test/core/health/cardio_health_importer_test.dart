import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:drift/native.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifey/core/health/cardio_health_importer.dart';
import 'package:lifey/core/health/health_cardio_workout.dart';
import 'package:lifey/core/health/health_preferences.dart';
import 'package:lifey/core/health/health_service.dart';
import 'package:lifey/core/local_db/app_database.dart';
import 'package:lifey/core/sync/outbox_writer.dart';
import 'package:lifey/core/sync/sync_engine.dart';
import 'package:lifey/features/workouts/data/workout_session_repository.dart';
import 'package:lifey/features/workouts/domain/workout_session.dart';

/// docs/integrations/89 G1.5: the cardio importer's opt-in, cursor, dedupe,
/// and the session it creates. Uses a real in-memory DB and repository, so
/// the outbox payload is the real one.
void main() {
  final now = DateTime.utc(2026, 11, 23, 12);
  late AppDatabase db;
  late WorkoutSessionRepository repo;
  late _Prefs prefs;
  late _Service service;
  late CardioHealthImporter importer;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    repo = WorkoutSessionRepository(db, OutboxWriter(db, _NoopSyncEngine(db, Dio())));
    prefs = _Prefs();
    service = _Service();
    importer = CardioHealthImporter(prefs: prefs, service: service, sessions: repo, now: () => now);
  });

  tearDown(() => db.close());

  Future<List<Map<String, dynamic>>> createPayloads() async {
    final ops = await (db.select(db.pendingOperations)..where((t) => t.operation.equals('create'))).get();
    return [for (final op in ops) jsonDecode(op.payloadJson) as Map<String, dynamic>];
  }

  test('does nothing unless both the Health and the cardio-import toggles are on', () async {
    service.workouts = [_run('hc-1', DateTime.utc(2026, 11, 22, 7))];

    prefs.healthEnabled = false;
    expect(await importer.import(), 0);
    prefs
      ..healthEnabled = true
      ..cardioEnabled = false;
    expect(await importer.import(), 0);

    expect(service.queries, isEmpty);
    expect(await db.select(db.workoutSessions).get(), isEmpty);
  });

  test('the first run looks back 14 days, imports the workout as a CARDIO session and moves the cursor', () async {
    final end = DateTime.utc(2026, 11, 22, 7, 42);
    service.workouts = [_run('hc-1', end)];

    expect(await importer.import(), 1);

    expect(service.queries.single, now.subtract(const Duration(days: 14)));
    final session = await _onlySession(repo, db);
    expect(session.isImported, isTrue);
    expect(session.importSource, 'HEALTH');
    expect(session.importAppName, 'Garmin Connect');
    expect(session.healthWorkoutId, 'hc-1');
    expect(session.sessionKind, 'CARDIO');
    expect(session.activityType, 'RUNNING');
    expect(session.movingSeconds, 42 * 60);
    expect(session.activeCalories, 512);
    expect(session.averageHeartRate, 148);
    expect(session.cardio!.distanceMeters, 8120);
    expect(prefs.cursor, end);

    final payload = (await createPayloads()).single;
    expect(payload['importSource'], 'HEALTH');
    expect(payload['healthWorkoutId'], 'hc-1');
  });

  test('a later run reads from the cursor and never imports the same record twice', () async {
    service.workouts = [_run('hc-1', DateTime.utc(2026, 11, 22, 7, 42))];
    await importer.import();

    // The store still returns hc-1 (it ends exactly at the cursor) plus a newer one.
    service.workouts = [
      _run('hc-1', DateTime.utc(2026, 11, 22, 7, 42)),
      _run('hc-2', DateTime.utc(2026, 11, 23, 8)),
    ];
    expect(await importer.import(), 1);

    expect(service.queries.last, DateTime.utc(2026, 11, 22, 7, 42));
    expect(await db.select(db.workoutSessions).get(), hasLength(2));
    expect(prefs.cursor, DateTime.utc(2026, 11, 23, 8));
  });

  test('a record already on a watch-paired Lifey session is skipped', () async {
    await repo.create(
      startedAt: DateTime.utc(2026, 11, 22, 7),
      exercises: const [],
      sets: const [],
      healthWorkoutId: 'hc-paired',
    );
    service.workouts = [_run('hc-paired', DateTime.utc(2026, 11, 22, 7, 42))];

    expect(await importer.import(), 0);
    expect(await db.select(db.workoutSessions).get(), hasLength(1));
    // The cursor still moves past it.
    expect(prefs.cursor, DateTime.utc(2026, 11, 22, 7, 42));
  });

  test('a workout without distance or steps gets no cardio details row', () async {
    service.workouts = [_run('hc-1', DateTime.utc(2026, 11, 22, 7, 42), distance: null, steps: null)];

    await importer.import();

    expect(await db.select(db.cardioDetails).get(), isEmpty);
  });

  test('two overlapping runs (app start and resume) create each session once', () async {
    service.workouts = [_run('hc-1', DateTime.utc(2026, 11, 22, 7, 42))];

    final results = await Future.wait([importer.import(), importer.import()]);

    expect(results, [1, 1]); // the second call joined the first run
    expect(service.queries, hasLength(1));
    expect(await db.select(db.workoutSessions).get(), hasLength(1));
  });

  test('a store failure imports nothing and keeps the cursor', () async {
    prefs.cursor = DateTime.utc(2026, 11, 20);
    service.fail = true;

    expect(await importer.import(), 0);
    expect(prefs.cursor, DateTime.utc(2026, 11, 20));
  });
}

Future<WorkoutSession> _onlySession(WorkoutSessionRepository repo, AppDatabase db) async {
  final row = await db.select(db.workoutSessions).getSingle();
  return (await repo.findByClientId(row.clientId))!;
}

HealthCardioWorkout _run(String uuid, DateTime end, {double? distance = 8120, int? steps = 7400}) =>
    HealthCardioWorkout(
      uuid: uuid,
      startDate: end.subtract(const Duration(minutes: 42)),
      endDate: end,
      activityType: 'RUNNING',
      sourceId: 'com.garmin.android.apps.connectmobile',
      sourceName: 'Garmin Connect',
      activeCalories: 512,
      distanceMeters: distance,
      steps: steps,
      averageHeartRate: 148,
    );

/// In-memory stand-in for the secure-storage-backed preferences.
class _Prefs extends HealthPreferences {
  _Prefs() : super(const FlutterSecureStorage());

  bool healthEnabled = true;
  bool cardioEnabled = true;
  DateTime? cursor;

  @override
  Future<bool> isEnabled() async => healthEnabled;

  @override
  Future<bool> isCardioImportEnabled() async => cardioEnabled;

  @override
  Future<DateTime?> cardioImportCursor() async => cursor;

  @override
  Future<void> setCardioImportCursor(DateTime endOfLastImported) async => cursor = endOfLastImported;
}

/// Returns [workouts] ending at or after `since`, as the real service does, and records every `since` it was asked for.
class _Service extends HealthService {
  List<HealthCardioWorkout> workouts = [];
  final queries = <DateTime>[];
  bool fail = false;

  @override
  Future<List<HealthCardioWorkout>> recentCardioWorkouts({required DateTime since}) async {
    queries.add(since);
    if (fail) throw StateError('store gone');
    return [
      for (final w in workouts)
        if (!w.endDate.isBefore(since)) w,
    ];
  }
}

class _NoopSyncEngine extends SyncEngine {
  _NoopSyncEngine(super.db, super.dio);

  @override
  Future<void> sync() async {}
}
