import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:drift/drift.dart' show OrderingTerm, Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifey/core/local_db/app_database.dart';
import 'package:lifey/core/sync/pull_engine.dart';

/// docs/cardio/60 C7.3 — the pull side of interval-plan sync: a plan created
/// on another device arrives with its whole step tree, a step-only edit
/// replaces every local step, a tombstone removes the plan and its steps, and
/// a local row with a queued write is never overwritten from the server.
///
/// Routes GET /cardio-interval-plans to a configurable fixture; every other
/// pullAll() entity gets an empty, harmless response. Like
/// pull_engine_cardio_test.dart's adapter, it serves a plain array on the
/// full pull and a paged `{content, last}` envelope once `updatedSince` is
/// present — serving the wrong shape would silently break the second pass.
class _IntervalPlansAdapter implements HttpClientAdapter {
  List<Map<String, dynamic>> plans = [];
  final requestedPaths = <String>[];

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    if (options.path == '/cardio-interval-plans') {
      requestedPaths.add(options.uri.toString());
      final isDelta = options.uri.queryParameters.containsKey('updatedSince');
      final body = isDelta ? jsonEncode({'content': plans, 'last': true}) : jsonEncode(plans);
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

Map<String, dynamic> _section(String name, String intensity, int seconds) => {
      'type': 'STEP',
      'name': name,
      'intensity': intensity,
      'durationSeconds': seconds,
      'repeatCount': null,
      'children': null,
    };

Map<String, dynamic> _block(int count, List<Map<String, dynamic>> children) => {
      'type': 'REPEAT',
      'name': null,
      'intensity': null,
      'durationSeconds': null,
      'repeatCount': count,
      'children': children,
    };

Map<String, dynamic> _plan(
  int id, {
  String name = 'Kedd esti 4x4',
  List<Map<String, dynamic>>? steps,
  String updatedAt = '2026-08-19T08:00:00.000Z',
  String? deletedAt,
}) =>
    {
      'id': id,
      'name': name,
      'steps': steps ??
          [
            _section('Bemelegítés', 'EASY', 300),
            _block(4, [
              _section('Kemény', 'HARD', 240),
              _section('Pihenő', 'EASY', 180),
            ]),
            _section('Levezetés', 'EASY', 300),
          ],
      'updatedAt': updatedAt,
      'deletedAt': deletedAt,
    };

void main() {
  late AppDatabase db;
  late Dio dio;
  late _IntervalPlansAdapter adapter;
  late PullEngine engine;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    dio = Dio();
    adapter = _IntervalPlansAdapter();
    dio.httpClientAdapter = adapter;
    engine = PullEngine(db, dio);
  });

  tearDown(() => db.close());

  Future<List<CardioIntervalStepRow>> steps() => (db.select(db.cardioIntervalSteps)
        ..orderBy([(t) => OrderingTerm.asc(t.stepIndex)]))
      .get();

  test('the first pull stores the plan and its whole step tree', () async {
    adapter.plans = [_plan(7)];

    await engine.pullAll();

    final plans = await db.select(db.cardioIntervalPlans).get();
    expect(plans.single.serverId, 7);
    expect(plans.single.name, 'Kedd esti 4x4');

    final rows = await steps();
    expect(rows, hasLength(5));
    final topLevel = rows.where((r) => r.parentStepClientId == null).toList();
    expect(topLevel.map((r) => r.stepType), ['STEP', 'REPEAT', 'STEP']);
    final block = topLevel[1];
    expect(block.repeatCount, 4);
    final children = rows.where((r) => r.parentStepClientId == block.clientId).toList();
    expect(children.map((r) => r.durationSeconds), [240, 180]);
    expect(children.map((r) => r.intensity), ['HARD', 'EASY']);
  });

  test('a step-only edit on the next pull replaces every local step', () async {
    adapter.plans = [_plan(7)];
    await engine.pullAll();

    // Same name, different steps — exactly the case §2.3 warns about: steps
    // have no delta feed of their own, so the plan's own updatedAt is the
    // only signal, and the pull has to bring a fresh full set.
    adapter.plans = [
      _plan(7, steps: [_section('Bemelegítés', 'EASY', 600)],
          updatedAt: '2026-08-19T09:00:00.000Z'),
    ];
    await engine.pullAll();

    final rows = await steps();
    expect(rows, hasLength(1));
    expect(rows.single.durationSeconds, 600);
    expect(rows.single.parentStepClientId, isNull);
    // Still one plan row, not a second copy.
    expect(await db.select(db.cardioIntervalPlans).get(), hasLength(1));
  });

  test('the second pull uses the delta feed', () async {
    adapter.plans = [_plan(7)];
    await engine.pullAll();
    await engine.pullAll();

    expect(adapter.requestedPaths.first, isNot(contains('updatedSince')));
    expect(adapter.requestedPaths.last, contains('updatedSince'));
  });

  test('a tombstone in the delta feed removes the plan and its steps', () async {
    adapter.plans = [_plan(7)];
    await engine.pullAll();

    adapter.plans = [
      _plan(7, updatedAt: '2026-08-19T10:00:00.000Z', deletedAt: '2026-08-19T10:00:00.000Z'),
    ];
    await engine.pullAll();

    expect(await db.select(db.cardioIntervalPlans).get(), isEmpty);
    expect(await steps(), isEmpty);
  });

  test('a plan deleted on the server disappears on a full pull too', () async {
    adapter.plans = [_plan(7)];
    await engine.pullAll();
    // Wipe the cursor so the next pass is a full pull again.
    await db.delete(db.syncCursors).go();

    adapter.plans = [];
    await engine.pullAll();

    expect(await db.select(db.cardioIntervalPlans).get(), isEmpty);
    expect(await steps(), isEmpty);
  });

  test('a plan with a queued local write is never overwritten by the pull', () async {
    adapter.plans = [_plan(7)];
    await engine.pullAll();
    final clientId = (await db.select(db.cardioIntervalPlans).get()).single.clientId;

    // The user renamed it offline; the edit hasn't reached the server yet, so
    // the local copy — not the stale server one — is the source of truth.
    await (db.update(db.cardioIntervalPlans)..where((t) => t.clientId.equals(clientId)))
        .write(const CardioIntervalPlansCompanion(name: Value('Helyi átnevezés')));
    await db.into(db.pendingOperations).insert(PendingOperationsCompanion.insert(
          clientId: clientId,
          entityType: 'cardio_interval_plan',
          operation: 'update',
          payloadJson: '{}',
          createdAt: DateTime.utc(2026, 8, 19, 11),
        ));

    adapter.plans = [
      _plan(7, name: 'Szerverről', steps: [_section('Más', 'HARD', 60)],
          updatedAt: '2026-08-19T12:00:00.000Z'),
    ];
    await engine.pullAll();

    final plan = (await db.select(db.cardioIntervalPlans).get()).single;
    expect(plan.name, 'Helyi átnevezés');
    // ...and its steps weren't replaced out from under the pending edit either.
    expect(await steps(), hasLength(5));
  });
}
