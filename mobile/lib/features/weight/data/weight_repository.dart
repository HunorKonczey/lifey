import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/network/dio_client.dart';
import '../domain/weight_entry.dart';

/// REST access to the `/weights` endpoints.
class WeightRepository {
  WeightRepository(this._dio);

  final Dio _dio;

  static final _dateFormat = DateFormat('yyyy-MM-dd');

  Future<List<WeightEntry>> fetchAll() async {
    final response = await _dio.get<List<dynamic>>('/weights');
    return (response.data ?? const [])
        .map((e) => WeightEntry.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<WeightEntry> create({required DateTime date, required double weight}) async {
    final response = await _dio.post<Map<String, dynamic>>('/weights', data: {
      'date': _dateFormat.format(date),
      'weight': weight,
    });
    return WeightEntry.fromJson(response.data!);
  }

  Future<void> delete(int id) async {
    await _dio.delete('/weights/$id');
  }
}

final weightRepositoryProvider = Provider<WeightRepository>((ref) {
  return WeightRepository(ref.watch(dioClientProvider));
});
