import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/api_endpoints.dart';
import '../../../core/network/dio_client.dart';
import '../domain/my_trainer.dart';

/// Online-only read/write of the current user's active trainer
/// relationships — never persisted locally (Settings §"Edzőim").
class MyTrainersRepository {
  MyTrainersRepository(this._dio);

  final Dio _dio;

  Future<List<MyTrainer>> fetchActiveTrainers() async {
    final response = await _dio.get<List<dynamic>>(ApiEndpoints.myTrainers);
    return (response.data ?? [])
        .map((json) => MyTrainer.fromJson(json as Map<String, dynamic>))
        .toList();
  }

  Future<void> leave(int trainerId) {
    return _dio.delete<void>(ApiEndpoints.myTrainer(trainerId));
  }
}

final myTrainersRepositoryProvider = Provider<MyTrainersRepository>((ref) {
  return MyTrainersRepository(ref.watch(dioClientProvider));
});
