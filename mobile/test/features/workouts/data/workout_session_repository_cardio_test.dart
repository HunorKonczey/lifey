import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifey/core/local_db/app_database.dart';
import 'package:lifey/core/sync/outbox_writer.dart';
import 'package:lifey/core/sync/sync_engine.dart';
import 'package:lifey/features/workouts/data/workout_session_repository.dart';
import 'package:lifey/features/workouts/domain/activity_type.dart';
import 'package:lifey/features/workouts/domain/workout_session.dart';

/// docs/cardio/59-cardio-implementation-plan.md C1.5's two regression
/// requirements: (1) a STRENGTH session's payload stays byte-identical to
/// the pre-cardio shape, and (2) cardio create/update/read actually round-trips.
void main() {
  late AppDatabase db;
  late WorkoutSessionRepository repo;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    // The outbox's fire-and-forget sync kick must not hit the network — these
    // tests only inspect the queued payloads and the local DB state.
    repo = WorkoutSessionRepository(db, OutboxWriter(db, _NoopSyncEngine(db, Dio())));
  });

  tearDown(() => db.close());

  Future<Map<String, dynamic>> lastPayload(String operation) async {
    final ops = await (db.select(db.pendingOperations)
          ..where((t) => t.operation.equals(operation)))
        .get();
    return jsonDecode(ops.last.payloadJson) as Map<String, dynamic>;
  }

  group('a STRENGTH session (the default) keeps the pre-cardio payload shape', () {
    test('create omits every cardio key entirely', () async {
      await repo.create(
        startedAt: DateTime.utc(2026, 7, 10, 17),
        finishedAt: DateTime.utc(2026, 7, 10, 18),
        exercises: const [],
        sets: const [],
        activeCalories: 320,
      );

      final payload = await lastPayload('create');
      expect(payload.containsKey('sessionKind'), isFalse);
      expect(payload.containsKey('activityType'), isFalse);
      expect(payload.containsKey('movingSeconds'), isFalse);
      expect(payload.containsKey('cardio'), isFalse);
      expect(payload.containsKey('splits'), isFalse);
      // The exact pre-cardio key set — nothing new leaked in.
      expect(
        payload.keys.toSet(),
        {'startedAt', 'finishedAt', 'exerciseIds', 'plannedExercises', 'sets', 'activeCalories'},
      );
    });

    test('update of a plain session also omits every cardio key', () async {
      final startedAt = DateTime.utc(2026, 7, 10, 17);
      final clientId = await repo.create(
        startedAt: startedAt,
        exercises: const [],
        sets: const [],
      );

      await repo.update(
        clientId,
        startedAt: startedAt,
        finishedAt: startedAt.add(const Duration(hours: 1)),
        exercises: const [],
        sets: const [],
      );

      final payload = await lastPayload('update');
      expect(payload.containsKey('sessionKind'), isFalse);
      expect(payload.containsKey('cardio'), isFalse);
      expect(payload.containsKey('splits'), isFalse);
    });

    test('the local row defaults to STRENGTH with no activityType', () async {
      final clientId = await repo.create(
        startedAt: DateTime.utc(2026, 7, 10, 17),
        exercises: const [],
        sets: const [],
      );

      final row = await (db.select(db.workoutSessions)..where((t) => t.clientId.equals(clientId)))
          .getSingle();
      expect(row.sessionKind, 'STRENGTH');
      expect(row.activityType, isNull);
      expect(row.movingSeconds, isNull);
    });
  });

  group('a CARDIO session', () {
    const metrics = CardioMetrics(
      distanceMeters: 5230.5,
      elevationGainMeters: 42.0,
      avgCadence: 172.0,
      maxHeartRate: 178.0,
      intensity: 4,
      venue: 'OUTDOOR',
      distanceSource: 'MEASURED',
      routePolyline: 'encoded-stub',
      routePointCount: 812,
    );
    const splits = [
      CardioSplit(splitIndex: 0, distanceMeters: 1000, durationSeconds: 342, avgHeartRate: 151),
      CardioSplit(splitIndex: 1, distanceMeters: 1000, durationSeconds: 358, avgHeartRate: 158),
    ];

    test('create persists activityType/movingSeconds/cardio/splits locally', () async {
      final clientId = await repo.create(
        startedAt: DateTime.utc(2026, 7, 10, 17),
        finishedAt: DateTime.utc(2026, 7, 10, 17, 32),
        exercises: const [],
        sets: const [],
        sessionKind: 'CARDIO',
        activityType: 'RUNNING',
        movingSeconds: 1860,
        cardio: metrics,
        splits: splits,
      );

      final row = await (db.select(db.workoutSessions)..where((t) => t.clientId.equals(clientId)))
          .getSingle();
      expect(row.sessionKind, 'CARDIO');
      expect(row.activityType, 'RUNNING');
      expect(row.movingSeconds, 1860);

      final cardioRow = await (db.select(db.cardioDetails)
            ..where((t) => t.sessionClientId.equals(clientId)))
          .getSingle();
      expect(cardioRow.distanceMeters, 5230.5);
      expect(cardioRow.intensity, 4);
      expect(cardioRow.venue, 'OUTDOOR');

      final splitRows = await (db.select(db.cardioSplits)
            ..where((t) => t.sessionClientId.equals(clientId)))
          .get();
      expect(splitRows, hasLength(2));
    });

    test('create sends the cardio block and splits in the payload', () async {
      await repo.create(
        startedAt: DateTime.utc(2026, 7, 10, 17),
        exercises: const [],
        sets: const [],
        sessionKind: 'CARDIO',
        activityType: 'RUNNING',
        movingSeconds: 1860,
        cardio: metrics,
        splits: splits,
      );

      final payload = await lastPayload('create');
      expect(payload['sessionKind'], 'CARDIO');
      expect(payload['activityType'], 'RUNNING');
      expect(payload['movingSeconds'], 1860);
      final cardioJson = payload['cardio'] as Map<String, dynamic>;
      expect(cardioJson['distanceMeters'], 5230.5);
      expect(cardioJson['intensity'], 4);
      expect(cardioJson['venue'], 'OUTDOOR');
      // Every backend field is present, even when null — not omitted.
      expect(cardioJson.containsKey('avgWatts'), isTrue);
      expect(cardioJson['avgWatts'], isNull);

      final splitsJson = (payload['splits'] as List).cast<Map<String, dynamic>>();
      expect(splitsJson, hasLength(2));
      expect(splitsJson[0]['splitIndex'], 0);
      expect(splitsJson[0]['durationSeconds'], 342);
      expect(splitsJson[1]['avgHeartRate'], 158);
    });

    test('watchAll reads a cardio session back with its metrics and splits', () async {
      await repo.create(
        startedAt: DateTime.utc(2026, 7, 10, 17),
        exercises: const [],
        sets: const [],
        sessionKind: 'CARDIO',
        activityType: 'RUNNING',
        movingSeconds: 1860,
        cardio: metrics,
        splits: splits,
      );

      final sessions = await repo.watchAll().first;
      expect(sessions, hasLength(1));
      final session = sessions.single;
      expect(session.isCardio, isTrue);
      expect(session.family, ActivityFamily.distance);
      expect(session.effectiveDuration, const Duration(seconds: 1860));
      expect(session.cardio, isNotNull);
      expect(session.cardio!.distanceMeters, 5230.5);
      expect(session.splits, hasLength(2));
      expect(session.splits[0].splitIndex, 0);
      expect(session.splits[1].splitIndex, 1);
      // A cardio session has no exercises/sets — empty, not a crash.
      expect(session.exercises, isEmpty);
      expect(session.sets, isEmpty);
    });

    test('a repeat save (update) replaces cardio metrics and splits, not appends', () async {
      final startedAt = DateTime.utc(2026, 7, 10, 17);
      final clientId = await repo.create(
        startedAt: startedAt,
        exercises: const [],
        sets: const [],
        sessionKind: 'CARDIO',
        activityType: 'RUNNING',
        movingSeconds: 900,
        cardio: const CardioMetrics(distanceMeters: 2000),
        splits: const [
          CardioSplit(splitIndex: 0, distanceMeters: 1000, durationSeconds: 300),
        ],
      );

      await repo.update(
        clientId,
        startedAt: startedAt,
        exercises: const [],
        sets: const [],
        sessionKind: const Value('CARDIO'),
        activityType: const Value('RUNNING'),
        movingSeconds: const Value(1860),
        cardio: const Value(metrics),
        splits: const Value(splits),
      );

      final cardioRows = await (db.select(db.cardioDetails)
            ..where((t) => t.sessionClientId.equals(clientId)))
          .get();
      expect(cardioRows, hasLength(1));
      expect(cardioRows.single.distanceMeters, 5230.5);

      final splitRows = await (db.select(db.cardioSplits)
            ..where((t) => t.sessionClientId.equals(clientId)))
          .get();
      expect(splitRows, hasLength(2));
    });

    test('rate() preserves an existing cardio session unchanged', () async {
      // rate() calls update() without knowing anything about cardio — this
      // is the exact mutual-wipe regression the Value-absent merge design
      // guards against (docs/cardio/59 C1.5).
      final clientId = await repo.create(
        startedAt: DateTime.utc(2026, 7, 10, 17),
        finishedAt: DateTime.utc(2026, 7, 10, 17, 32),
        exercises: const [],
        sets: const [],
        sessionKind: 'CARDIO',
        activityType: 'RUNNING',
        movingSeconds: 1860,
        cardio: metrics,
        splits: splits,
      );

      await repo.rate(clientId, rpe: 7, feedbackNote: 'felt good');

      final row = await (db.select(db.workoutSessions)..where((t) => t.clientId.equals(clientId)))
          .getSingle();
      expect(row.sessionKind, 'CARDIO');
      expect(row.activityType, 'RUNNING');
      expect(row.rpe, 7);

      final cardioRows = await (db.select(db.cardioDetails)
            ..where((t) => t.sessionClientId.equals(clientId)))
          .get();
      expect(cardioRows, hasLength(1));
      expect(cardioRows.single.distanceMeters, 5230.5);
      final splitRows = await (db.select(db.cardioSplits)
            ..where((t) => t.sessionClientId.equals(clientId)))
          .get();
      expect(splitRows, hasLength(2));

      final payload = await lastPayload('update');
      // rate()'s own update must still carry the cardio block through — it
      // was preserved, not dropped, so it belongs in the full-replace payload.
      expect(payload['sessionKind'], 'CARDIO');
      expect(payload['cardio'], isNotNull);
    });

    test('enrichHealthMetrics() preserves an existing cardio session unchanged', () async {
      final clientId = await repo.create(
        startedAt: DateTime.utc(2026, 7, 10, 17),
        exercises: const [],
        sets: const [],
        sessionKind: 'CARDIO',
        activityType: 'RUNNING',
        cardio: metrics,
      );

      await repo.enrichHealthMetrics(
        clientId,
        activeCalories: const Value(410),
        averageHeartRate: const Value(150),
        healthWorkoutId: const Value('hk-uuid-9'),
      );

      final row = await (db.select(db.workoutSessions)..where((t) => t.clientId.equals(clientId)))
          .getSingle();
      expect(row.sessionKind, 'CARDIO');
      expect(row.activityType, 'RUNNING');
      final cardioRows = await (db.select(db.cardioDetails)
            ..where((t) => t.sessionClientId.equals(clientId)))
          .get();
      expect(cardioRows, hasLength(1));
    });

    test('an explicit null cardio block clears the row (full-replace, not "no change")', () async {
      final startedAt = DateTime.utc(2026, 7, 10, 17);
      final clientId = await repo.create(
        startedAt: startedAt,
        exercises: const [],
        sets: const [],
        sessionKind: 'CARDIO',
        activityType: 'RUNNING',
        cardio: metrics,
        splits: splits,
      );

      await repo.update(
        clientId,
        startedAt: startedAt,
        exercises: const [],
        sets: const [],
        sessionKind: const Value('CARDIO'),
        activityType: const Value('RUNNING'),
        cardio: const Value(null),
        splits: const Value([]),
      );

      final cardioRows = await (db.select(db.cardioDetails)
            ..where((t) => t.sessionClientId.equals(clientId)))
          .get();
      expect(cardioRows, isEmpty);
      final splitRows = await (db.select(db.cardioSplits)
            ..where((t) => t.sessionClientId.equals(clientId)))
          .get();
      expect(splitRows, isEmpty);

      final payload = await lastPayload('update');
      expect(payload.containsKey('cardio'), isFalse);
      expect(payload.containsKey('splits'), isFalse);
    });

    test('watchByKind narrows to one session kind', () async {
      await repo.create(
        startedAt: DateTime.utc(2026, 7, 10, 17),
        exercises: const [],
        sets: const [],
      );
      await repo.create(
        startedAt: DateTime.utc(2026, 7, 10, 18),
        exercises: const [],
        sets: const [],
        sessionKind: 'CARDIO',
        activityType: 'WALKING',
      );

      final all = await repo.watchByKind(null).first;
      final cardioOnly = await repo.watchByKind('CARDIO').first;
      final strengthOnly = await repo.watchByKind('STRENGTH').first;

      expect(all, hasLength(2));
      expect(cardioOnly, hasLength(1));
      expect(cardioOnly.single.activityType, 'WALKING');
      expect(strengthOnly, hasLength(1));
      expect(strengthOnly.single.sessionKind, 'STRENGTH');
    });

    test('delete removes the cardio child rows too', () async {
      final clientId = await repo.create(
        startedAt: DateTime.utc(2026, 7, 10, 17),
        exercises: const [],
        sets: const [],
        sessionKind: 'CARDIO',
        activityType: 'RUNNING',
        cardio: metrics,
        splits: splits,
      );

      await repo.delete(clientId);

      final cardioRows = await (db.select(db.cardioDetails)
            ..where((t) => t.sessionClientId.equals(clientId)))
          .get();
      expect(cardioRows, isEmpty);
      final splitRows = await (db.select(db.cardioSplits)
            ..where((t) => t.sessionClientId.equals(clientId)))
          .get();
      expect(splitRows, isEmpty);
    });
  });
}

/// Swallows the outbox's `_kick()` so no HTTP is attempted.
class _NoopSyncEngine extends SyncEngine {
  _NoopSyncEngine(super.db, super.dio);

  @override
  Future<void> sync() async {}
}
