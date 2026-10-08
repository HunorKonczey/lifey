import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifey/core/local_db/app_database.dart';
import 'package:lifey/core/sync/pull_engine.dart';

/// Routes GET /meals to a configurable fixture — the full pull answers with a list, the delta pull (it carries
/// `updatedSince`) with a page — and every other entity with an empty, harmless response.
class _MealsAdapter implements HttpClientAdapter {
  List<Map<String, dynamic>> meals = [];

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final headers = {
      Headers.contentTypeHeader: [Headers.jsonContentType],
    };
    if (options.path == '/meals') {
      final isDelta = options.uri.queryParameters.containsKey('updatedSince');
      final body = isDelta ? {'content': meals, 'last': true} : meals;
      return ResponseBody.fromString(jsonEncode(body), 200, headers: headers);
    }
    return ResponseBody.fromString('[]', 200, headers: headers);
  }
}

Map<String, dynamic> _meal(int id, {String? trainerComment, String? trainerCommentAt, String updatedAt = '2026-06-18T07:00:00.000Z'}) => {
      'id': id,
      'dateTime': '2026-06-18T12:00:00.000Z',
      'mealType': 'LUNCH',
      'name': null,
      'entries': const [],
      'updatedAt': updatedAt,
      'deletedAt': null,
      'trainerComment': trainerComment,
      'trainerCommentAt': trainerCommentAt,
    };

void main() {
  late AppDatabase db;
  late _MealsAdapter adapter;
  late PullEngine pullEngine;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    final dio = Dio(BaseOptions(baseUrl: 'http://test'));
    adapter = _MealsAdapter();
    dio.httpClientAdapter = adapter;
    pullEngine = PullEngine(db, dio);
  });

  tearDown(() => db.close());

  test('maps trainerComment/trainerCommentAt from the pull JSON onto the local meal row (LIF-144)', () async {
    adapter.meals = [_meal(1, trainerComment: 'More greens next time', trainerCommentAt: '2026-06-18T09:00:00.000Z')];

    await pullEngine.pullAll();

    final row = await db.select(db.meals).getSingle();
    expect(row.trainerComment, 'More greens next time');
    // Drift round-trips DateTime as local time (same instant), so compare in UTC.
    expect(row.trainerCommentAt!.toUtc(), DateTime.parse('2026-06-18T09:00:00.000Z'));
  });

  test('a meal without a comment stays uncommented', () async {
    adapter.meals = [_meal(2)];

    await pullEngine.pullAll();

    final row = await db.select(db.meals).getSingle();
    expect(row.trainerComment, isNull);
    expect(row.trainerCommentAt, isNull);
  });

  test('a comment the trainer adds, then removes, follows the next pulls', () async {
    adapter.meals = [_meal(3)];
    await pullEngine.pullAll();

    adapter.meals = [_meal(3, trainerComment: 'Skip the sauce', trainerCommentAt: '2026-06-19T09:00:00.000Z', updatedAt: '2026-06-19T09:00:00.000Z')];
    await pullEngine.pullAll();
    expect((await db.select(db.meals).getSingle()).trainerComment, 'Skip the sauce');

    adapter.meals = [_meal(3, updatedAt: '2026-06-20T09:00:00.000Z')];
    await pullEngine.pullAll();
    final row = await db.select(db.meals).getSingle();
    expect(row.trainerComment, isNull);
    expect(row.trainerCommentAt, isNull);
  });
}
