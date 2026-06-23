import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifey/core/local_db/app_database.dart';
import 'package:lifey/core/sync/outbox_writer.dart';
import 'package:lifey/core/sync/sync_engine.dart';
import 'package:lifey/features/nutrition/data/food_repository.dart';

/// Records every request's method + path instead of hitting the network, so
/// these tests can assert exactly which HTTP verb the sync engine actually
/// sends for a given local operation.
class _RecordingAdapter implements HttpClientAdapter {
  final List<String> methods = [];
  final List<String> paths = [];

  /// Auto-incrementing id handed back as `{"id": N, ...}` for POSTs, so the
  /// sync engine's `_applySuccess` has something to stamp onto the local row.
  int _nextId = 1;

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    methods.add(options.method);
    paths.add(options.path);
    final body = options.method == 'POST' ? '{"id": ${_nextId++}}' : '{}';
    return ResponseBody.fromString(
      body,
      200,
      headers: {Headers.contentTypeHeader: [Headers.jsonContentType]},
    );
  }
}

void main() {
  late AppDatabase db;
  late Dio dio;
  late _RecordingAdapter adapter;
  late SyncEngine syncEngine;
  late FoodRepository repo;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    dio = Dio(BaseOptions(baseUrl: 'http://test'));
    adapter = _RecordingAdapter();
    dio.httpClientAdapter = adapter;
    syncEngine = SyncEngine(db, dio);
    // OutboxWriter fires a fire-and-forget `sync()` on every write
    // (production behavior, so queued writes go out without the caller
    // waiting on the network) — racing that against this test's own explicit
    // `await syncEngine.sync()` calls is a test-only problem (the explicit
    // call's `_running` guard would just no-op while the background kick is
    // still mid-flight). Give the writer a no-op engine so only the test's
    // explicit calls below ever actually drain.
    repo = FoodRepository(db, OutboxWriter(db, _NoopSyncEngine(db, dio)));
  });

  tearDown(() => db.close());

  test('editing an already-synced food sends PUT to /foods/{id}, not POST', () async {
    await repo.create(name: 'Egg', calories: 155, protein: 13);
    await syncEngine.sync(); // drains the create -> POST /foods, serverId = 1
    expect(adapter.methods, ['POST']);

    final clientId = (await db.select(db.foods).getSingle()).clientId;
    adapter.methods.clear();
    adapter.paths.clear();

    await repo.update(clientId, name: 'Egg (updated)', calories: 160, protein: 14);
    await syncEngine.sync();

    expect(adapter.methods, ['PUT']);
    expect(adapter.paths, ['/foods/1']);
  });

  test('editing a food whose create has not synced yet queues the update '
      'until the create succeeds, instead of crashing the sync pass', () async {
    // Regression test for a real bug: SyncEngine._hasPendingOperation used to
    // filter only by clientId, not operation. Once an update is queued
    // alongside a still-unsynced create for the same food (e.g. edited while
    // offline / the create is failing), TWO pending_operations rows share
    // that clientId, and the clientId-only lookup threw "Too many elements"
    // every sync pass — silently, since nothing awaits the fire-and-forget
    // kick. The practical symptom: the create's POST kept retrying forever
    // while the edit's PUT was never even attempted.
    var blockCreate = true;
    dio.httpClientAdapter = _ConditionalAdapter(adapter, blockUntil: () => blockCreate);

    await repo.create(name: 'Egg', calories: 155, protein: 13);
    await syncEngine.sync(); // create fails (network) and stays queued
    expect(adapter.methods, isEmpty);

    final clientId = (await db.select(db.foods).getSingle()).clientId;
    await repo.update(clientId, name: 'Egg (updated)', calories: 160, protein: 14);

    // Must not throw, and must not send the update's PUT while its create is
    // still unsynced.
    await syncEngine.sync();
    expect(adapter.methods, isEmpty);

    blockCreate = false;
    await syncEngine.sync(); // create now succeeds, unblocking the update

    expect(adapter.methods, ['POST', 'PUT']);
    expect(adapter.paths, ['/foods', '/foods/1']);
  });
}

/// See the note in `setUp` above — used only as the [OutboxWriter]'s engine
/// so its internal fire-and-forget kick can't race the test's own explicit
/// drains.
class _NoopSyncEngine extends SyncEngine {
  _NoopSyncEngine(super.db, super.dio);

  @override
  Future<void> sync() async {}
}

/// Lets a single test flip a network condition (online/offline) between
/// [SyncEngine.sync] calls.
class _ConditionalAdapter implements HttpClientAdapter {
  _ConditionalAdapter(this._inner, {required this.blockUntil});

  final HttpClientAdapter _inner;
  final bool Function() blockUntil;

  @override
  void close({bool force = false}) => _inner.close();

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) {
    if (blockUntil()) {
      throw DioException.connectionError(requestOptions: options, reason: 'offline');
    }
    return _inner.fetch(options, requestStream, cancelFuture);
  }
}
