import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Device-local persistence for the morning weigh-in reminder toggle + time
/// (docs/30-push-notifications-plan.md, M4).
///
/// Deliberately NOT part of the synced `UserSettings`, same reasoning as
/// [HealthPreferences]: this is a per-device notification schedule, not an
/// account-level preference. Stored via secure storage simply because that's
/// the device-local key/value store already wired up — the value isn't
/// secret.
class WeighInReminderPreferences {
  WeighInReminderPreferences(this._storage);

  final FlutterSecureStorage _storage;

  static const _enabledKey = 'weighInReminder.enabled';
  static const _hourKey = 'weighInReminder.hour';
  static const _minuteKey = 'weighInReminder.minute';

  static const defaultHour = 8;
  static const defaultMinute = 0;

  Future<bool> isEnabled() async {
    return (await _storage.read(key: _enabledKey)) == 'true';
  }

  Future<void> setEnabled(bool enabled) {
    return _storage.write(key: _enabledKey, value: enabled ? 'true' : 'false');
  }

  /// The user-chosen reminder time, defaulting to 08:00 if never set.
  Future<({int hour, int minute})> time() async {
    final hour = int.tryParse(await _storage.read(key: _hourKey) ?? '') ?? defaultHour;
    final minute = int.tryParse(await _storage.read(key: _minuteKey) ?? '') ?? defaultMinute;
    return (hour: hour, minute: minute);
  }

  Future<void> setTime({required int hour, required int minute}) async {
    await _storage.write(key: _hourKey, value: hour.toString());
    await _storage.write(key: _minuteKey, value: minute.toString());
  }

  /// Clears the device-local preference on logout, so a different account
  /// signing in on this device doesn't inherit (or silently keep firing) it.
  Future<void> clear() async {
    await _storage.delete(key: _enabledKey);
    await _storage.delete(key: _hourKey);
    await _storage.delete(key: _minuteKey);
  }
}

final weighInReminderPreferencesProvider = Provider<WeighInReminderPreferences>((ref) {
  return WeighInReminderPreferences(const FlutterSecureStorage());
});
