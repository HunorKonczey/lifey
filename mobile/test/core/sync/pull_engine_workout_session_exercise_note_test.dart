import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifey/core/local_db/app_database.dart';
import 'package:lifey/core/sync/pull_engine.dart';

/// LIF-224: the server stores each planned exercise's comment, so a pulled
/// session's notes replace the local ones — null included.
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
    return ResponseBody.fromString(body, 200, headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType],
    });
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
      'updatedAt': '2026-11-20T17:00:00.000Z',
      'deletedAt': null,
    };

Map<String, dynamic> _session(int id, Map<int, String?> notesByExerciseId) => {
      'id': id,
      'startedAt': '2026-11-20T17:00:00.000Z',
      'finishedAt': '2026-11-20T18:00:00.000Z',
      'exercises': [
        for (final entry in notesByExerciseId.entries)
          {'exerciseId': entry.key, 'exerciseName': 'x', 'targetSets': 3, 'note': entry.value},
      ],
      'sets': const [],
      'updatedAt': '2026-11-20T18:00:00.000Z',
      'deletedAt': null,
    };

void main() {
  late AppDatabase db;
  late _SessionsAdapter adapter;
  late PullEngine pullEngine;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    final dio = Dio(BaseOptions(baseUrl: 'http://test'));
    adapter = _SessionsAdapter();
    dio.httpClientAdapter = adapter;
    pullEngine = PullEngine(db, dio);
  });

  tearDown(() => db.close());

  Future<Map<String, String?>> notesOf(String sessionClientId) async {
    final links = await (db.select(db.workoutSessionExercises)
          ..where((t) => t.sessionClientId.equals(sessionClientId)))
        .get();
    return {for (final link in links) link.exerciseClientId: link.note};
  }

  test('a pulled session stores each planned exercise\'s note', () async {
    adapter.exercises = [_exercise(10, 'Bench press'), _exercise(11, 'Squat')];
    adapter.sessions = [
      _session(1, {10: 'seat on 4', 11: null}),
    ];

    await pullEngine.pullAll();

    final session = await (db.select(db.workoutSessions)..where((t) => t.serverId.equals(1))).getSingle();
    final exercises = {
      for (final e in await db.select(db.exercises).get()) e.serverId: e.clientId,
    };
    expect(await notesOf(session.clientId), {exercises[10]: 'seat on 4', exercises[11]: null});
  });

  test('the server\'s answer replaces the local note, a cleared one included', () async {
    await db.into(db.exercises).insert(
          ExercisesCompanion.insert(clientId: 'ex-bench', serverId: const Value(10), name: 'Bench press'),
        );
    await db.into(db.workoutSessions).insert(WorkoutSessionsCompanion.insert(
          clientId: 'sess-1',
          serverId: const Value(1),
          startedAt: Value(DateTime.parse('2026-11-20T17:00:00.000Z')),
        ));
    await db.into(db.workoutSessionExercises).insert(WorkoutSessionExercisesCompanion.insert(
          clientId: 'link-1',
          sessionClientId: 'sess-1',
          exerciseClientId: 'ex-bench',
          note: const Value('seat on 3'),
        ));
    adapter.exercises = [_exercise(10, 'Bench press')];
    adapter.sessions = [
      _session(1, {10: null}),
    ];

    await pullEngine.pullAll();

    expect(await notesOf('sess-1'), {'ex-bench': null});
  });
}
