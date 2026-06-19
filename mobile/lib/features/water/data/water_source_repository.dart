import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/dio_client.dart';
import '../domain/water_source.dart';

/// REST access to the `/water-sources` endpoints.
class WaterSourceRepository {
  WaterSourceRepository(this._dio);

  final Dio _dio;

  Future<List<WaterSource>> fetchAll() async {
    final response = await _dio.get<List<dynamic>>('/water-sources');
    return (response.data ?? const [])
        .map((e) => WaterSource.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<WaterSource> create({required String name, required double volumeLiters}) async {
    final response = await _dio.post<Map<String, dynamic>>('/water-sources', data: {
      'name': name,
      'volumeLiters': volumeLiters,
    });
    return WaterSource.fromJson(response.data!);
  }

  Future<WaterSource> update(int id, {required String name, required double volumeLiters}) async {
    final response = await _dio.put<Map<String, dynamic>>('/water-sources/$id', data: {
      'name': name,
      'volumeLiters': volumeLiters,
    });
    return WaterSource.fromJson(response.data!);
  }

  Future<void> delete(int id) async {
    await _dio.delete('/water-sources/$id');
  }
}

final waterSourceRepositoryProvider = Provider<WaterSourceRepository>((ref) {
  return WaterSourceRepository(ref.watch(dioClientProvider));
});
