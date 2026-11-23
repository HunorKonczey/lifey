import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifey/core/local_db/app_database.dart';
import 'package:lifey/core/sync/pull_engine.dart';

/// docs/integrations/89 G1.3: the pull side of a session's provenance.
/// Routes GET /workout-sessions to a fixture and gives every other
/// pullAll() entity an empty response, the same pattern as
/// pull_engine_workout_session_trainer_comment_test.dart.
class _WorkoutSessionsAdapter implements HttpClientAdapter {
  List<Map<String, dynamic>> sessions = [];

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final body = options.path == '/workout-sessions' ? jsonEncode(sessions) : '[]';
    return ResponseBody.fromString(
      body,
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }
}

Map<String, dynamic> _session(int id, {Map<String, dynamic> extra = const {}}) => {
      'id': id,
      'startedAt': '2026-11-20T06:00:00.000Z',
      'finishedAt': '2026-11-20T06:42:00.000Z',
      'exercises': const [],
      'sets': const [],
      'activeCalories': 512.0,
      'averageHeartRate': 148.0,
      'healthWorkoutId': 'hc-run-$id',
      'templateId': null,
      'templateName': null,
      'scheduledFor': null,
      'scheduledTime': null,
      'scheduleId': null,
      'rpe': null,
      'feedbackNote': null,
      'trainerComment': null,
      'trainerCommentAt': null,
      'updatedAt': '2026-11-20T06:42:00.000Z',
      'deletedAt': null,
      'sessionKind': 'CARDIO',
      'activityType': 'RUNNING',
      'movingSeconds': 2520,
      'cardio': null,
      'splits': const [],
      'waypoints': const [],
      ...extra,
    };

void main() {
  late AppDatabase db;
  late _WorkoutSessionsAdapter adapter;
  late PullEngine pullEngine;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    final dio = Dio(BaseOptions(baseUrl: 'http://test'));
    adapter = _WorkoutSessionsAdapter();
    dio.httpClientAdapter = adapter;
    pullEngine = PullEngine(db, dio);
  });

  tearDown(() => db.close());

  test('maps importSource / importAppName from the pull JSON onto the local row', () async {
    adapter.sessions = [
      _session(1, extra: {'importSource': 'HEALTH', 'importAppName': 'Garmin Connect'}),
    ];

    await pullEngine.pullAll();

    final row = await db.select(db.workoutSessions).getSingle();
    expect(row.importSource, 'HEALTH');
    expect(row.importAppName, 'Garmin Connect');
    expect(row.healthWorkoutId, 'hc-run-1');
  });

  test('a session from a server that predates imports stays Lifey-recorded', () async {
    // No importSource / importAppName keys at all, as every response before V97 looked.
    adapter.sessions = [_session(2)];

    await pullEngine.pullAll();

    final row = await db.select(db.workoutSessions).getSingle();
    expect(row.importSource, isNull);
    expect(row.importAppName, isNull);
  });
}
