import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/api_endpoints.dart';
import '../../../core/network/dio_client.dart';
import '../domain/off_search.dart';

/// Online-only OpenFoodFacts name search (`GET /foods/off-search`, docs/84).
///
/// Like [BarcodeLookupRepository] it never touches the local drift cache and never enqueues an outbox entry: the
/// result is a transient suggestion. Saving a pick as a food goes through the offline-first `FoodRepository`.
class OffSearchRepository {
  OffSearchRepository(this._dio);

  final Dio _dio;

  /// [text] is expected to be sanitised already (`sanitizeOffQuery`); the backend cleans it again and answers 400 for
  /// fewer than three letters or digits. [cancelToken] stops a request a newer keystroke has made pointless.
  Future<OffSearchResult> search(String text, String lang, {CancelToken? cancelToken}) async {
    final response = await _dio.get<Map<String, dynamic>>(
      ApiEndpoints.foodsOffSearch,
      queryParameters: {'q': text, 'lang': lang},
      cancelToken: cancelToken,
    );
    return OffSearchResult.fromJson(response.data!);
  }
}

final offSearchRepositoryProvider = Provider<OffSearchRepository>((ref) {
  return OffSearchRepository(ref.watch(dioClientProvider));
});
