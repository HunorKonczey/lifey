import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifey/core/local_db/app_database.dart';
import 'package:lifey/core/sync/pull_engine.dart';

/// Routes GET /exercises + GET /workout-sessions to configurable fixtures;
/// every other pullAll() entity gets an empty, harmless response — same
/// pattern as pull_engine_workout_session_trainer_comment_test.dart.
class _SessionsAdapter implements HttpClientAdapter {
  List<Map<String, dynamic>> sessions = [];
  List<Map<String, dynamic>> exercises = [];

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final body = switch (options.path) {
      '/workout-sessions' => jsonEncode(sessions),
      '/exercises' => jsonEncode(exercises),
      _ => '[]',
    };
    return ResponseBody.fromString(
      body,
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }
}

Map<String, dynamic> _exercise(int id, String name) => {
      'id': id,
      'name': name,
      'category': null,
      'equipment': null,
      'description': null,
      'originTrainerId': null,
      'defaultRestSeconds': null,
      'updatedAt': '2026-07-10T17:00:00.000Z',
      'deletedAt': null,
    };

/// A still-running session (no finishedAt) planning [exerciseIds]. Planned
/// exercises carry no targetSets — the shape a backend older than
/// V63__workout_session_exercise_target_sets returns, and the reason the local
/// value has to be preserved rather than overwritten with null.
Map<String, dynamic> _session(int id, List<int> exerciseIds) => {
      'id': id,
      'startedAt': '2026-07-10T17:00:00.000Z',
      'finishedAt': null,
      'exercises': [
        for (final exerciseId in exerciseIds)
          {'exerciseId': exerciseId, 'exerciseName': 'Bench press'},
      ],
      'sets': const [],
      'activeCalories': null,
      'averageHeartRate': null,
      'healthWorkoutId': null,
      'templateId': null,
      'templateName': null,
      'scheduledFor': null,
      'scheduledTime': null,
      'scheduleId': null,
      'rpe': null,
      'feedbackNote': null,
      'trainerComment': null,
      'trainerCommentAt': null,
      'updatedAt': '2026-07-10T18:00:00.000Z',
      'deletedAt': null,
    };

void main() {
  late AppDatabase db;
  late Dio dio;
  late _SessionsAdapter adapter;
  late PullEngine pullEngine;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    dio = Dio(BaseOptions(baseUrl: 'http://test'));
    adapter = _SessionsAdapter();
    dio.httpClientAdapter = adapter;
    pullEngine = PullEngine(db, dio);
  });

  tearDown(() => db.close());

  /// Seeds an already-synced local session with planned exercises, the way a
  /// workout started on this device looks once its create has drained.
  Future<void> seedLocalSession({
    required String sessionClientId,
    required int serverId,
    required Map<String, int?> targetSetsByExerciseClientId,
  }) async {
    await db.into(db.workoutSessions).insert(
          WorkoutSessionsCompanion.insert(
            clientId: sessionClientId,
            serverId: Value(serverId),
            startedAt: Value(DateTime.parse('2026-07-10T17:00:00.000Z')),
          ),
        );
    var i = 0;
    for (final entry in targetSetsByExerciseClientId.entries) {
      await db.into(db.workoutSessionExercises).insert(
            WorkoutSessionExercisesCompanion.insert(
              clientId: 'link-${i++}',
              sessionClientId: sessionClientId,
              exerciseClientId: entry.key,
              targetSets: Value(entry.value),
            ),
          );
    }
  }

  Future<void> seedLocalExercise(String clientId, int serverId, String name) {
    return db.into(db.exercises).insert(
          ExercisesCompanion.insert(
            clientId: clientId,
            serverId: Value(serverId),
            name: name,
          ),
        );
  }

  test('keeps the local targetSets when re-inserting a pulled session\'s planned exercises',
      () async {
    await seedLocalExercise('ex-bench', 10, 'Bench press');
    await seedLocalExercise('ex-squat', 11, 'Squat');
    await seedLocalSession(
      sessionClientId: 'sess-1',
      serverId: 1,
      targetSetsByExerciseClientId: {'ex-bench': 3, 'ex-squat': 4},
    );
    adapter.exercises = [_exercise(10, 'Bench press'), _exercise(11, 'Squat')];
    adapter.sessions = [_session(1, [10, 11])];

    await pullEngine.pullAll();

    final links = await (db.select(db.workoutSessionExercises)
          ..where((t) => t.sessionClientId.equals('sess-1')))
        .get();
    expect(
      {for (final link in links) link.exerciseClientId: link.targetSets},
      {'ex-bench': 3, 'ex-squat': 4},
    );
  });

  test('preserves targetSets even when the server returns the exercises in a different order',
      () async {
    await seedLocalExercise('ex-bench', 10, 'Bench press');
    await seedLocalExercise('ex-squat', 11, 'Squat');
    await seedLocalSession(
      sessionClientId: 'sess-1',
      serverId: 1,
      targetSetsByExerciseClientId: {'ex-bench': 3, 'ex-squat': 4},
    );
    adapter.exercises = [_exercise(10, 'Bench press'), _exercise(11, 'Squat')];
    adapter.sessions = [
      _session(1, [11, 10])
    ];

    await pullEngine.pullAll();

    final links = await (db.select(db.workoutSessionExercises)
          ..where((t) => t.sessionClientId.equals('sess-1')))
        .get();
    expect(
      {for (final link in links) link.exerciseClientId: link.targetSets},
      {'ex-bench': 3, 'ex-squat': 4},
    );
  });

  test('leaves targetSets null for an exercise the local session did not plan yet', () async {
    await seedLocalExercise('ex-bench', 10, 'Bench press');
    await seedLocalExercise('ex-squat', 11, 'Squat');
    await seedLocalSession(
      sessionClientId: 'sess-1',
      serverId: 1,
      targetSetsByExerciseClientId: {'ex-bench': 3},
    );
    adapter.exercises = [_exercise(10, 'Bench press'), _exercise(11, 'Squat')];
    adapter.sessions = [_session(1, [10, 11])];

    await pullEngine.pullAll();

    final links = await (db.select(db.workoutSessionExercises)
          ..where((t) => t.sessionClientId.equals('sess-1')))
        .get();
    expect(
      {for (final link in links) link.exerciseClientId: link.targetSets},
      {'ex-bench': 3, 'ex-squat': null},
    );
  });

  /// The same session, but with the server answering with each planned
  /// exercise's targetSets (the V63 backend).
  Map<String, dynamic> sessionWithTargets(int id, Map<int, int?> targetsByExerciseId) {
    final json = _session(id, targetsByExerciseId.keys.toList());
    json['exercises'] = [
      for (final entry in targetsByExerciseId.entries)
        {
          'exerciseId': entry.key,
          'exerciseName': 'Bench press',
          'targetSets': entry.value,
        },
    ];
    return json;
  }

  group('once the server stores targetSets itself', () {
    test('the server value is applied, including onto a session seen for the first time',
        () async {
      await seedLocalExercise('ex-bench', 10, 'Bench press');
      adapter.exercises = [_exercise(10, 'Bench press')];
      adapter.sessions = [
        sessionWithTargets(1, {10: 4})
      ];

      await pullEngine.pullAll();

      final link = await (db.select(db.workoutSessionExercises)).getSingle();
      expect(link.targetSets, 4);
    });

    test('the server value wins over a stale local one', () async {
      // Another device grew the plan with "+ Add set"; this device's copy is
      // the one that's out of date.
      await seedLocalExercise('ex-bench', 10, 'Bench press');
      await seedLocalSession(
        sessionClientId: 'sess-1',
        serverId: 1,
        targetSetsByExerciseClientId: {'ex-bench': 3},
      );
      adapter.exercises = [_exercise(10, 'Bench press')];
      adapter.sessions = [
        sessionWithTargets(1, {10: 5})
      ];

      await pullEngine.pullAll();

      final link = await (db.select(db.workoutSessionExercises)).getSingle();
      expect(link.targetSets, 5);
    });

    test('a null from the server still falls back to the local value', () async {
      // A session written before the column existed: the server genuinely has
      // nothing, so the local count is the only copy left.
      await seedLocalExercise('ex-bench', 10, 'Bench press');
      await seedLocalSession(
        sessionClientId: 'sess-1',
        serverId: 1,
        targetSetsByExerciseClientId: {'ex-bench': 3},
      );
      adapter.exercises = [_exercise(10, 'Bench press')];
      adapter.sessions = [
        sessionWithTargets(1, {10: null})
      ];

      await pullEngine.pullAll();

      final link = await (db.select(db.workoutSessionExercises)).getSingle();
      expect(link.targetSets, 3);
    });
  });

  test('a session first seen from the server has no local targetSets to preserve', () async {
    await seedLocalExercise('ex-bench', 10, 'Bench press');
    adapter.exercises = [_exercise(10, 'Bench press')];
    adapter.sessions = [_session(1, [10])];

    await pullEngine.pullAll();

    final link = await (db.select(db.workoutSessionExercises)).getSingle();
    expect(link.targetSets, isNull);
  });
}
