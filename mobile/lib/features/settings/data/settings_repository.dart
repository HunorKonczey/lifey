import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/dio_client.dart';
import '../domain/user_settings.dart';

/// REST access to the `/settings` endpoint.
class SettingsRepository {
  SettingsRepository(this._dio);

  final Dio _dio;

  Future<UserSettings> fetch() async {
    final response = await _dio.get<Map<String, dynamic>>('/settings');
    return UserSettings.fromJson(response.data!);
  }

  Future<UserSettings> update(UserSettings settings) async {
    final response = await _dio.put<Map<String, dynamic>>('/settings', data: settings.toJson());
    return UserSettings.fromJson(response.data!);
  }
}

final settingsRepositoryProvider = Provider<SettingsRepository>((ref) {
  return SettingsRepository(ref.watch(dioClientProvider));
});
