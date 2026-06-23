import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Device-local persistence for the "Connect Apple Health" opt-in.
///
/// This is deliberately NOT part of the synced [UserSettings] (which is
/// per-account and pushed to the backend): whether Apple Health is connected is
/// a property of *this device* and its HealthKit permission, meaningless on
/// another device or account. Stored via secure storage simply because that's
/// the device-local key/value store already wired up (see
/// `core/storage/token_storage.dart`); the value isn't secret.
class HealthPreferences {
  HealthPreferences(this._storage);

  final FlutterSecureStorage _storage;

  static const _enabledKey = 'health.appleHealthEnabled';

  Future<bool> isEnabled() async {
    return (await _storage.read(key: _enabledKey)) == 'true';
  }

  Future<void> setEnabled(bool enabled) {
    return _storage.write(key: _enabledKey, value: enabled ? 'true' : 'false');
  }
}

final healthPreferencesProvider = Provider<HealthPreferences>((ref) {
  return HealthPreferences(const FlutterSecureStorage());
});
