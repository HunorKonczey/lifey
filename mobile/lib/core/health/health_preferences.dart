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
  static const _lastWeightImportKey = 'health.lastHealthWeightImportedAt';

  Future<bool> isEnabled() async {
    return (await _storage.read(key: _enabledKey)) == 'true';
  }

  Future<void> setEnabled(bool enabled) {
    return _storage.write(key: _enabledKey, value: enabled ? 'true' : 'false');
  }

  /// When the Phase 3 weight importer last created an entry from a HealthKit
  /// sample — guards against re-importing the same sample on every app resume.
  Future<DateTime?> lastHealthWeightImportedAt() async {
    final raw = await _storage.read(key: _lastWeightImportKey);
    return raw == null ? null : DateTime.tryParse(raw);
  }

  Future<void> setLastHealthWeightImportedAt(DateTime timestamp) {
    return _storage.write(key: _lastWeightImportKey, value: timestamp.toIso8601String());
  }
}

final healthPreferencesProvider = Provider<HealthPreferences>((ref) {
  return HealthPreferences(const FlutterSecureStorage());
});
