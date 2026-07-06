import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifey/core/network/dio_client.dart';
import 'package:lifey/features/my_trainers/application/my_trainers_controller.dart';

class _FakeAdapter implements HttpClientAdapter {
  Object body = [];
  final List<String> methods = [];
  final List<String> paths = [];

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
    if (options.method == 'DELETE') {
      return ResponseBody.fromString('', 204);
    }
    return ResponseBody.fromString(
      jsonEncode(body),
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }
}

Map<String, dynamic> _trainer(int id, {String email = 'trainer@example.com'}) => {
      'trainerId': id,
      'trainerEmail': email,
      'activeSince': '2026-06-01T10:00:00Z',
    };

void main() {
  late _FakeAdapter adapter;
  late ProviderContainer container;

  setUp(() {
    adapter = _FakeAdapter();
    final dio = Dio(BaseOptions(baseUrl: 'http://test'))..httpClientAdapter = adapter;
    container = ProviderContainer(
      overrides: [dioClientProvider.overrideWithValue(dio)],
    );
    addTearDown(container.dispose);
  });

  test('build() fetches the active trainers on first read', () async {
    adapter.body = [_trainer(1)];

    final trainers = await container.read(myTrainersControllerProvider.future);

    expect(trainers, hasLength(1));
    expect(trainers.single.trainerId, 1);
    expect(adapter.paths, ['/my-trainers']);
  });

  test('leave() DELETEs the relationship and removes it from local state', () async {
    adapter.body = [_trainer(1), _trainer(2)];
    await container.read(myTrainersControllerProvider.future);

    await container.read(myTrainersControllerProvider.notifier).leave(1);

    expect(adapter.paths.last, '/my-trainers/1');
    expect(adapter.methods.last, 'DELETE');
    final trainers = container.read(myTrainersControllerProvider).value!;
    expect(trainers.map((t) => t.trainerId), [2]);
  });
}
