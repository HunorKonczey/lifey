import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/api_endpoints.dart';
import '../../../core/network/dio_client.dart';
import '../domain/barcode_lookup_result.dart';

/// Online-only lookup of a food by barcode (`GET /foods/barcode/{barcode}`).
///
/// Unlike [FoodRepository], this never touches the local drift cache and
/// never enqueues an outbox entry — the result is a transient suggestion to
/// prefill a form, not a write.
class BarcodeLookupRepository {
  BarcodeLookupRepository(this._dio);

  final Dio _dio;

  Future<BarcodeLookupResult> lookupByBarcode(String barcode) async {
    final response =
        await _dio.get<Map<String, dynamic>>(ApiEndpoints.foodByBarcode(barcode));
    return BarcodeLookupResult.fromJson(response.data!);
  }
}

final barcodeLookupRepositoryProvider = Provider<BarcodeLookupRepository>((ref) {
  return BarcodeLookupRepository(ref.watch(dioClientProvider));
});
