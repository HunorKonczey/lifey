import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/dio_client.dart';
import '../domain/water_entry.dart';

/// REST access to the `/water-entries` endpoint.
class WaterEntryRepository {
  WaterEntryRepository(this._dio);

  final Dio _dio;

  Future<WaterEntry> create({
    required DateTime consumedAt,
    int? sourceId,
    required double volumeLiters,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>('/water-entries', data: {
      'consumedAt': consumedAt.toUtc().toIso8601String(),
      if (sourceId != null) 'sourceId': sourceId,
      'volumeLiters': volumeLiters,
    });
    return WaterEntry.fromJson(response.data!);
  }
}

final waterEntryRepositoryProvider = Provider<WaterEntryRepository>((ref) {
  return WaterEntryRepository(ref.watch(dioClientProvider));
});
