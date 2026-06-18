import 'package:flutter/foundation.dart'
    show kIsWeb, defaultTargetPlatform, TargetPlatform;

/// Resolves the backend base URL for the current platform.
///
/// Override at run time with:
///   flutter run --dart-define=API_BASE_URL=http://192.168.0.42:8080/api/v1
/// (needed for a physical device, which must reach the host over the LAN).
class ApiConfig {
  const ApiConfig._();

  static const String _override = String.fromEnvironment('API_BASE_URL');

  static String get baseUrl {
    if (_override.isNotEmpty) return _override;
    if (kIsWeb) return 'http://localhost:8080/api/v1';
    // Android emulator maps the host loopback to 10.0.2.2.
    if (defaultTargetPlatform == TargetPlatform.android) {
      return 'http://10.0.2.2:8080/api/v1';
    }
    // iOS simulator shares the host network; physical devices need --dart-define.
    return 'http://localhost:8080/api/v1';
  }
}
