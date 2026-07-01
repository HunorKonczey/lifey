import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifey/core/local_db/app_database.dart';
import 'package:lifey/core/sync/pull_engine.dart';

/// Serves GET /foods as a paged endpoint (see docs/05-backend-api.md) across
/// however many pages [pagesOfFoods] describes, and an empty response for
/// every other pullAll() entity so their (guarded) pulls are harmless no-ops.
class _PagedFoodsAdapter implements HttpClientAdapter {
  _PagedFoodsAdapter(this.pagesOfFoods);

  /// Each inner list is one page's `content`; the last page is inferred as
  /// whichever list matches the requested `page` index closest to the end.
  List<List<Map<String, dynamic>>> pagesOfFoods;

  final List<Uri> requestedFoodsUris = [];

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    if (options.path == '/foods') {
      requestedFoodsUris.add(options.uri);
      final page = int.parse(options.uri.queryParameters['page']!);
      final content = page < pagesOfFoods.length ? pagesOfFoods[page] : <Map<String, dynamic>>[];
      final isLast = page >= pagesOfFoods.length - 1;
      final body = {'content': content, 'last': isLast};
      return ResponseBody.fromString(
        jsonEncode(body),
        200,
        headers: {
          Headers.contentTypeHeader: [Headers.jsonContentType],
        },
      );
    }

    // Every other pullAll() entity: an empty response is a harmless no-op —
    // each _pull* is wrapped in PullEngine._guard, so a shape mismatch (e.g.
    // /settings expecting a Map) is swallowed rather than failing the test.
    return ResponseBody.fromString(
      '[]',
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }
}

Map<String, dynamic> _food(int id, String name) => {
      'id': id,
      'name': name,
      'caloriesPer100g': 100.0,
      'proteinPer100g': 5.0,
      'carbsPer100g': 10.0,
      'fatPer100g': 2.0,
      'barcode': null,
      'hidden': false,
    };

void main() {
  late AppDatabase db;
  late Dio dio;
  late _PagedFoodsAdapter adapter;
  late PullEngine pullEngine;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    dio = Dio(BaseOptions(baseUrl: 'http://test'));
    adapter = _PagedFoodsAdapter([]);
    dio.httpClientAdapter = adapter;
    pullEngine = PullEngine(db, dio);
  });

  tearDown(() => db.close());

  test('pullAll loops GET /foods?page=N until last:true and merges every page', () async {
    adapter.pagesOfFoods = [
      [_food(1, 'Apple')],
      [_food(2, 'Banana')],
    ];

    await pullEngine.pullAll();

    expect(adapter.requestedFoodsUris.map((u) => u.queryParameters['page']), ['0', '1']);
    expect(adapter.requestedFoodsUris.every((u) => u.queryParameters['size'] == '200'), isTrue);

    final names = (await db.select(db.foods).get()).map((f) => f.name).toSet();
    expect(names, {'Apple', 'Banana'});
  });

  test('a food missing from a later pull is deleted locally, even though it '
      'was only ever seen via the paged endpoint', () async {
    adapter.pagesOfFoods = [
      [_food(1, 'Apple'), _food(2, 'Banana')],
    ];
    await pullEngine.pullAll();
    expect((await db.select(db.foods).get()).map((f) => f.name).toSet(), {'Apple', 'Banana'});

    // Banana no longer appears server-side.
    adapter.pagesOfFoods = [
      [_food(1, 'Apple')],
    ];
    await pullEngine.pullAll();

    final names = (await db.select(db.foods).get()).map((f) => f.name).toSet();
    expect(names, {'Apple'});
  });

  test('single-page response (last:true immediately) does not request a second page', () async {
    adapter.pagesOfFoods = [
      [_food(1, 'Apple')],
    ];

    await pullEngine.pullAll();

    expect(adapter.requestedFoodsUris.map((u) => u.queryParameters['page']), ['0']);
  });
}
