import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:drift/drift.dart' show OrderingTerm;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifey/core/local_db/app_database.dart';
import 'package:lifey/core/sync/pull_engine.dart';

/// Routes GET /workout-sessions to a configurable fixture; every other
/// pullAll() entity gets an empty, harmless response — mirrors
/// pull_engine_workout_session_trainer_comment_test.dart's adapter.
///
/// Unlike that adapter (used for single-pull tests only), this one also
/// handles a *second* pullAll() call correctly: PullEngine's full pull
/// (`_pullWorkoutSessionsFull`, no cursor yet) expects a plain JSON array
/// from `/workout-sessions`, but once a cursor exists the delta pull
/// (`_pullWorkoutSessionsDelta`) calls the same path with `?updatedSince=`
/// and expects a *paged* `{content, last}` envelope instead (mirrors
/// pull_engine_delta_sync_test.dart's `_FoodsAdapter`) — serving the wrong
/// shape on the second call silently breaks a from-scratch in-memory re-pull.
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
      final isDelta = options.uri.queryParameters.containsKey('updatedSince');
      final body = isDelta ? jsonEncode({'content': sessions, 'last': true}) : jsonEncode(sessions);
      return ResponseBody.fromString(
        body,
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

Map<String, dynamic> _baseSession(int id, {String? updatedAt}) => {
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
      'trainerComment': null,
      'trainerCommentAt': null,
      'updatedAt': updatedAt ?? '2026-07-10T18:00:00.000Z',
      'deletedAt': null,
      // Every existing response already carries this — never omitted by the
      // real backend (docs/cardio/52 §3.2) — but the pull must tolerate a
      // legacy/absent value too, tested separately below.
      'sessionKind': 'STRENGTH',
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

  test('a STRENGTH response maps sessionKind and leaves cardio/splits empty', () async {
    adapter.sessions = [_baseSession(1)];

    await pullEngine.pullAll();

    final row = await db.select(db.workoutSessions).getSingle();
    expect(row.sessionKind, 'STRENGTH');
    expect(row.activityType, isNull);
    expect(row.movingSeconds, isNull);
    expect(await db.select(db.cardioDetails).get(), isEmpty);
    expect(await db.select(db.cardioSplits).get(), isEmpty);
  });

  test('a response with no sessionKind key at all still defaults locally to STRENGTH', () async {
    // Simulates a legacy/cached response shape — the "critical" rule from
    // docs/cardio/53-cardio-mobile-plan.md §1.4.
    final session = _baseSession(1)..remove('sessionKind');
    adapter.sessions = [session];

    await pullEngine.pullAll();

    final row = await db.select(db.workoutSessions).getSingle();
    expect(row.sessionKind, 'STRENGTH');
  });

  test('a CARDIO response maps activityType/movingSeconds/cardio/splits', () async {
    adapter.sessions = [
      {
        ..._baseSession(2),
        'sessionKind': 'CARDIO',
        'activityType': 'RUNNING',
        'movingSeconds': 1860,
        'cardio': {
          'distanceMeters': 5230.5,
          'elevationGainMeters': 42.0,
          'elevationLossMeters': null,
          'maxAltitudeMeters': null,
          'steps': null,
          'avgCadence': 172.0,
          'maxCadence': null,
          'avgWatts': null,
          'maxWatts': null,
          'resistanceLevel': null,
          'deviceCalories': null,
          'maxHeartRate': 178.0,
          'hrZone1Seconds': null,
          'hrZone2Seconds': null,
          'hrZone3Seconds': 900,
          'hrZone4Seconds': null,
          'hrZone5Seconds': null,
          'intensity': 4,
          'venue': 'OUTDOOR',
          'gameFormat': null,
          'scorePoints': null,
          'scoreAssists': null,
          'scoreRebounds': null,
          'distanceSource': 'MEASURED',
          'caloriesSource': null,
          'routePolyline': 'encoded-stub',
          'routePointCount': 812,
        },
        'splits': [
          {
            'splitIndex': 0,
            'distanceMeters': 1000.0,
            'durationSeconds': 342,
            'elevationDeltaM': -2.5,
            'avgHeartRate': 151.0,
          },
          {
            'splitIndex': 1,
            'distanceMeters': 1000.0,
            'durationSeconds': 358,
            'elevationDeltaM': null,
            'avgHeartRate': null,
          },
        ],
      },
    ];

    await pullEngine.pullAll();

    final row = await db.select(db.workoutSessions).getSingle();
    expect(row.sessionKind, 'CARDIO');
    expect(row.activityType, 'RUNNING');
    expect(row.movingSeconds, 1860);

    final cardioRow = await db.select(db.cardioDetails).getSingle();
    expect(cardioRow.distanceMeters, 5230.5);
    expect(cardioRow.intensity, 4);
    expect(cardioRow.venue, 'OUTDOOR');
    expect(cardioRow.hrZone3Seconds, 900);
    expect(cardioRow.routePolyline, 'encoded-stub');

    final splitRows = await (db.select(db.cardioSplits)
          ..orderBy([(t) => OrderingTerm.asc(t.splitIndex)]))
        .get();
    expect(splitRows, hasLength(2));
    expect(splitRows[0].durationSeconds, 342);
    expect(splitRows[0].avgHeartRate, 151.0);
    expect(splitRows[1].elevationDeltaM, isNull);
  });

  test('best efforts pulled from the server land in the local row (C6.3)', () async {
    adapter.sessions = [
      {
        ..._baseSession(5),
        'sessionKind': 'CARDIO',
        'activityType': 'RUNNING',
        'movingSeconds': 3600,
        'cardio': {
          'distanceMeters': 12000.0,
          'best1kSeconds': 250,
          'best5kSeconds': 1400,
          'best10kSeconds': 2980,
        },
        'splits': const [],
      },
    ];

    await pullEngine.pullAll();

    final cardioRow = await db.select(db.cardioDetails).getSingle();
    expect(cardioRow.best1kSeconds, 250);
    expect(cardioRow.best5kSeconds, 1400);
    expect(cardioRow.best10kSeconds, 2980);
  });

  test('a cardio response without best-effort keys leaves them null, not zero', () async {
    // What every session recorded before C6.1 looks like coming back from the
    // server: the keys simply aren't there. Zero would read as an impossibly
    // fast record (docs/cardio/60 §9).
    adapter.sessions = [
      {
        ..._baseSession(6),
        'sessionKind': 'CARDIO',
        'activityType': 'RUNNING',
        'movingSeconds': 1860,
        'cardio': {'distanceMeters': 5230.5},
        'splits': const [],
      },
    ];

    await pullEngine.pullAll();

    final cardioRow = await db.select(db.cardioDetails).getSingle();
    expect(cardioRow.best1kSeconds, isNull);
    expect(cardioRow.best5kSeconds, isNull);
    expect(cardioRow.best10kSeconds, isNull);
  });

  test('re-pulling the same session replaces cardio metrics rather than duplicating', () async {
    adapter.sessions = [
      {
        ..._baseSession(3),
        'sessionKind': 'CARDIO',
        'activityType': 'RUNNING',
        'cardio': {'distanceMeters': 2000.0},
      },
    ];
    await pullEngine.pullAll();

    adapter.sessions = [
      {
        ..._baseSession(3, updatedAt: '2026-07-10T19:00:00.000Z'),
        'sessionKind': 'CARDIO',
        'activityType': 'RUNNING',
        'cardio': {'distanceMeters': 5230.5},
      },
    ];
    await pullEngine.pullAll();

    final cardioRows = await db.select(db.cardioDetails).get();
    expect(cardioRows, hasLength(1));
    expect(cardioRows.single.distanceMeters, 5230.5);
  });
}
