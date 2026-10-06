import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifey/features/nutrition/data/off_search_repository.dart';
import 'package:lifey/features/nutrition/domain/off_search.dart';

/// Records the request and replies with canned JSON — the same fake-adapter shape the other Dio tests use.
class _FakeAdapter implements HttpClientAdapter {
  RequestOptions? last;
  Object? body;
  int statusCode = 200;

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(RequestOptions options, Stream<Uint8List>? requestStream, Future<void>? cancelFuture) async {
    last = options;
    if (statusCode >= 400) {
      throw DioException(requestOptions: options, response: Response(requestOptions: options, statusCode: statusCode));
    }
    return ResponseBody.fromString(jsonEncode(body), statusCode, headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType],
    });
  }
}

void main() {
  late _FakeAdapter adapter;
  late OffSearchRepository repo;

  setUp(() {
    adapter = _FakeAdapter();
    repo = OffSearchRepository(Dio()..httpClientAdapter = adapter);
  });

  test('asks GET /foods/off-search with q and lang and parses the answer', () async {
    adapter.body = {
      'status': 'OK',
      'language': 'hu',
      'fellBackToEnglish': false,
      'items': [
        {'barcode': '1', 'name': 'Csirkemell', 'brand': 'Pikok', 'caloriesPer100g': 110, 'proteinPer100g': 14, 'carbsPer100g': 2.4, 'fatPer100g': 4.9},
      ],
    };

    final result = await repo.search('csirkemell', 'hu');

    expect(adapter.last!.method, 'GET');
    expect(adapter.last!.path, '/foods/off-search');
    expect(adapter.last!.queryParameters, {'q': 'csirkemell', 'lang': 'hu'});
    expect(result.status, OffSearchStatus.ok);
    expect(result.items.single.name, 'Csirkemell');
  });

  test('an OpenFoodFacts problem is a normal answer with a status, not an exception', () async {
    adapter.body = {'status': 'RATE_LIMITED', 'language': 'hu', 'fellBackToEnglish': false, 'items': []};

    final result = await repo.search('tej', 'hu');

    expect(result.status, OffSearchStatus.rateLimited);
    expect(result.items, isEmpty);
  });

  test('an HTTP error (the backend refusing, e.g. 400 for a too-short text) is thrown', () async {
    adapter.statusCode = 400;

    await expectLater(repo.search('ab', 'en'), throwsA(isA<DioException>()));
  });

  test('a cancelled request throws a cancel exception the caller can recognise', () async {
    final token = CancelToken()..cancel();

    await expectLater(
      repo.search('tej', 'hu', cancelToken: token),
      throwsA(predicate((e) => e is DioException && CancelToken.isCancel(e))),
    );
  });
}
