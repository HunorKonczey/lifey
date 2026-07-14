import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifey/core/local_db/app_database.dart';
import 'package:lifey/core/sync/pull_engine.dart';

/// Routes GET /workout-sessions to a configurable fixture; every other
/// pullAll() entity gets an empty, harmless response — mirrors
/// pull_engine_delta_sync_test.dart's `_FoodsAdapter` pattern.
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
    if (options.path == '/workout-sessions') {
      return ResponseBody.fromString(
        jsonEncode(sessions),
        200,
        headers: {
          Headers.contentTypeHeader: [Headers.jsonContentType],
        },
      );
    }
    return ResponseBody.fromString(
      '[]',
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }
}

Map<String, dynamic> _session(
  int id, {
  String? trainerComment,
  String? trainerCommentAt,
}) =>
    {
      'id': id,
      'startedAt': '2026-07-10T17:00:00.000Z',
      'finishedAt': '2026-07-10T18:00:00.000Z',
      'exercises': const [],
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
      'trainerComment': trainerComment,
      'trainerCommentAt': trainerCommentAt,
      'updatedAt': '2026-07-10T18:00:00.000Z',
      'deletedAt': null,
    };

void main() {
  late AppDatabase db;
  late Dio dio;
  late _WorkoutSessionsAdapter adapter;
  late PullEngine pullEngine;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    dio = Dio(BaseOptions(baseUrl: 'http://test'));
    adapter = _WorkoutSessionsAdapter();
    dio.httpClientAdapter = adapter;
    pullEngine = PullEngine(db, dio);
  });

  tearDown(() => db.close());

  test('maps trainerComment/trainerCommentAt from the pull JSON onto the local row',
      () async {
    adapter.sessions = [
      _session(1, trainerComment: 'Nice pace, add weight next time', trainerCommentAt: '2026-06-18T07:00:00.000Z'),
    ];

    await pullEngine.pullAll();

    final row = await db.select(db.workoutSessions).getSingle();
    expect(row.trainerComment, 'Nice pace, add weight next time');
    // Drift round-trips DateTime as local-time (same instant, isUtc: false),
    // so compare in UTC — see pull_engine_delta_sync_test.dart's cursor check.
    expect(row.trainerCommentAt!.toUtc(), DateTime.parse('2026-06-18T07:00:00.000Z'));
  });

  test('leaves trainerComment/trainerCommentAt null when uncommented', () async {
    adapter.sessions = [_session(2)];

    await pullEngine.pullAll();

    final row = await db.select(db.workoutSessions).getSingle();
    expect(row.trainerComment, isNull);
    expect(row.trainerCommentAt, isNull);
  });
}
