import 'package:flutter/foundation.dart'
    show kIsWeb, defaultTargetPlatform, TargetPlatform;

/// Resolves the backend base URL for the current platform.
///
/// Override at run time with, e.g.:
///   flutter run --dart-define=API_BASE_URL=http://192.168.0.42:8080/api/v1
/// — needed for the iOS simulator (or anything else) to reach a *local*
/// backend instead of the deployed one below.
class ApiConfig {
  const ApiConfig._();

  static const String _override = String.fromEnvironment('API_BASE_URL');

  /// The deployed backend — the default everywhere except web/Android
  /// emulator (which assume a local backend during development there).
  static const String _productionUrl = 'https://lifey-production-7aa5.up.railway.app/api/v1';

  static String get baseUrl {
    if (_override.isNotEmpty) return _override;
    if (kIsWeb) return 'http://localhost:8080/api/v1';
    // Android emulator maps the host loopback to 10.0.2.2.
    if (defaultTargetPlatform == TargetPlatform.android) {
      return 'http://10.0.2.2:8080/api/v1';
    }
    // iOS — mainly run on a physical device, which can't reach "localhost"
    // (that's the phone itself), so default to the deployed backend. For
    // the iOS *simulator* with a local backend, override explicitly:
    // --dart-define=API_BASE_URL=http://localhost:8080/api/v1
    return _productionUrl;
  }
}
