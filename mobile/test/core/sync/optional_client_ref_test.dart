import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:drift/drift.dart' hide isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifey/core/local_db/app_database.dart';
import 'package:lifey/core/sync/client_ref.dart';
import 'package:lifey/core/sync/outbox_dependencies.dart';
import 'package:lifey/core/sync/outbox_writer.dart';
import 'package:lifey/core/sync/sync_engine.dart';

/// Records the body of every request and answers a POST with a fresh id.
class _RecordingAdapter implements HttpClientAdapter {
  final requests = <({String method, String path, Object? body})>[];
  int _nextId = 100;

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(RequestOptions options, Stream<Uint8List>? requestStream, Future<void>? cancelFuture) async {
    requests.add((method: options.method, path: options.path, body: options.data));
    return ResponseBody.fromString(
      options.method == 'POST' ? '{"id": ${_nextId++}}' : '{}',
      200,
      headers: {Headers.contentTypeHeader: [Headers.jsonContentType]},
    );
  }
}

class _NoopSyncEngine extends SyncEngine {
  _NoopSyncEngine(super.db, super.dio);

  @override
  Future<void> sync() async {}
}

/// docs/88 §2.7: a meal entry's recipe tag is a reference the meal can do without. A plain `clientRef` to a row that
/// vanished before it synced fails the operation for good (right for a food, wrong for a tag); an `optionalClientRef`
/// to the same sends null and the meal goes out untagged.
void main() {
  late AppDatabase db;
  late _RecordingAdapter adapter;
  late SyncEngine engine;
  late OutboxWriter outbox;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    adapter = _RecordingAdapter();
    final dio = Dio(BaseOptions(baseUrl: 'http://test'))..httpClientAdapter = adapter;
    engine = SyncEngine(db, dio);
    outbox = OutboxWriter(db, _NoopSyncEngine(db, dio));
  });

  tearDown(() => db.close());

  Future<void> insertRecipe(String clientId, {int? serverId}) => db.into(db.recipes).insert(
        RecipesCompanion.insert(clientId: clientId, name: 'Chilli', serverId: Value(serverId)),
      );

  Future<void> queueMeal(String clientId, Object? recipeRef) async {
    await db.into(db.meals).insert(MealsCompanion.insert(
          clientId: clientId,
          mealDateTime: DateTime.utc(2026, 10, 15, 12),
          mealType: 'LUNCH',
        ));
    await outbox.enqueueCreate(
      clientId: clientId,
      entityType: 'meal',
      payload: {
        'dateTime': '2026-10-15T12:00:00.000Z',
        'mealType': 'LUNCH',
        'entries': [
          {'foodId': 5, 'quantityInGrams': 100, 'recipeId': recipeRef},
        ],
      },
    );
  }

  Map<String, dynamic> sentMeal() => (adapter.requests.single.body as Map).cast<String, dynamic>();

  Object? sentRecipeId() => ((sentMeal()['entries'] as List).single as Map)['recipeId'];

  Future<PendingOperationRow> operationOf(String clientId) =>
      (db.select(db.pendingOperations)..where((t) => t.clientId.equals(clientId))).getSingle();

  test('a synced recipe is sent as its server id', () async {
    await insertRecipe('r1', serverId: 42);
    await queueMeal('m1', optionalClientRef('r1'));

    await engine.sync();

    expect(sentRecipeId(), 42);
    expect(await db.select(db.pendingOperations).get(), isEmpty);
  });

  test('a recipe whose create is still queued is waited for, then sent as its new id', () async {
    await insertRecipe('r1');
    // The meal is queued first, so it is the first candidate of the pass and has to be held back.
    await queueMeal('m1', optionalClientRef('r1'));
    await outbox.enqueueCreate(clientId: 'r1', entityType: 'recipe', payload: {'name': 'Chilli', 'ingredients': <Object>[]});

    await engine.sync();

    expect(adapter.requests.map((r) => r.path), ['/recipes', '/meals']);
    final meal = (adapter.requests.last.body as Map).cast<String, dynamic>();
    expect(((meal['entries'] as List).single as Map)['recipeId'], 100);
  });

  test('a recipe that is gone before it ever synced is sent as null, and the meal still syncs', () async {
    await queueMeal('m1', optionalClientRef('deleted-recipe'));

    await engine.sync();

    expect(sentRecipeId(), isNull);
    expect(await db.select(db.pendingOperations).get(), isEmpty);
  });

  test('a plain clientRef to a row that is gone still fails the operation for good', () async {
    await queueMeal('m1', clientRef('deleted-recipe'));

    await engine.sync();

    expect(adapter.requests, isEmpty);
    final op = await operationOf('m1');
    expect(op.status, 'failed');
    expect(op.lastError, contains('Unresolved clientRef'));
  });

  test('both kinds of marker are dependencies of the operation', () async {
    await queueMeal('m1', optionalClientRef('r1'));
    final op = await operationOf('m1');
    expect(outboxDependencies(op), {'r1'});

    expect(isClientRef(optionalClientRef('r1')), isTrue);
    expect(isOptionalClientRef(optionalClientRef('r1')), isTrue);
    expect(isOptionalClientRef(clientRef('r1')), isFalse);
    expect(clientRefId(optionalClientRef('r1')), 'r1');
    expect(clientRefId(clientRef('r1')), 'r1');
    expect(jsonDecode(op.payloadJson), isA<Map>());
  });
}
