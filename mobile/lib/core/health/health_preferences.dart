import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Device-local persistence for the "Connect Health" opt-in.
///
/// This is deliberately NOT part of the synced [UserSettings] (which is
/// per-account and pushed to the backend): whether Health is connected is a
/// property of *this device* and its platform permission (HealthKit on iOS,
/// Health Connect on Android), meaningless on another device or account.
/// Stored via secure storage simply because that's the device-local
/// key/value store already wired up (see `core/storage/token_storage.dart`);
/// the value isn't secret.
class HealthPreferences {
  HealthPreferences(this._storage);

  final FlutterSecureStorage _storage;

  static const _enabledKey = 'health.enabled';
  static const _lastWeightImportKey = 'health.lastHealthWeightImportedAt';
  static const _lastStepGoalNotifiedKey = 'health.lastStepGoalNotifiedDate';
  static const _stepGoalNotificationEnabledKey = 'health.stepGoalNotificationEnabled';
  static const _cardioImportEnabledKey = 'health.cardioImport.enabled';
  static const _cardioImportCursorKey = 'health.cardioImport.cursor';
  static const _sleepImportEnabledKey = 'health.sleepImport.enabled';
  static const _sleepImportCursorKey = 'health.sleepImport.cursor';
  static const _vitalsImportEnabledKey = 'health.vitalsImport.enabled';
  static const _vitalsImportCursorKey = 'health.vitalsImport.cursor';

  /// Whether finished cardio workouts from other apps are imported
  /// (docs/integrations/89 D-G5). Off until the user turns it on. The toggle
  /// itself is G1.6. Also requires the general Health opt-in ([isEnabled]).
  Future<bool> isCardioImportEnabled() async {
    return (await _storage.read(key: _cardioImportEnabledKey)) == 'true';
  }

  Future<void> setCardioImportEnabled(bool enabled) {
    return _storage.write(key: _cardioImportEnabledKey, value: enabled ? 'true' : 'false');
  }

  /// The end time of the last imported cardio workout: the next import reads
  /// from here (docs/integrations/89 D-G5). Null before the first import,
  /// which then looks back 14 days.
  Future<DateTime?> cardioImportCursor() async {
    final raw = await _storage.read(key: _cardioImportCursorKey);
    return raw == null ? null : DateTime.tryParse(raw);
  }

  Future<void> setCardioImportCursor(DateTime endOfLastImported) {
    return _storage.write(key: _cardioImportCursorKey, value: endOfLastImported.toUtc().toIso8601String());
  }

  /// Whether sleep sessions from the health store are imported
  /// (docs/integrations/89 D-G5). Off until the user turns it on; the toggle
  /// itself is G2.4. Also requires the general Health opt-in ([isEnabled]).
  Future<bool> isSleepImportEnabled() async {
    return (await _storage.read(key: _sleepImportEnabledKey)) == 'true';
  }

  Future<void> setSleepImportEnabled(bool enabled) {
    return _storage.write(key: _sleepImportEnabledKey, value: enabled ? 'true' : 'false');
  }

  /// The end time of the last imported sleep session: the next import reads
  /// from here (D-G5). Null before the first import, which then looks back
  /// 14 days.
  Future<DateTime?> sleepImportCursor() async {
    final raw = await _storage.read(key: _sleepImportCursorKey);
    return raw == null ? null : DateTime.tryParse(raw);
  }

  Future<void> setSleepImportCursor(DateTime endOfLastImported) {
    return _storage.write(key: _sleepImportCursorKey, value: endOfLastImported.toUtc().toIso8601String());
  }

  /// Whether daily resting HR and HRV from the health store are imported
  /// (docs/integrations/89 D-G5, G3.3). Off until the user turns it on. Also
  /// requires the general Health opt-in ([isEnabled]).
  Future<bool> isVitalsImportEnabled() async {
    return (await _storage.read(key: _vitalsImportEnabledKey)) == 'true';
  }

  Future<void> setVitalsImportEnabled(bool enabled) {
    return _storage.write(key: _vitalsImportEnabledKey, value: enabled ? 'true' : 'false');
  }

  /// The time of the newest vitals sample imported (D-G5). The next import
  /// re-reads from the start of the day before it, see [VitalsHealthImporter].
  /// Null before the first import, which then looks back 14 days.
  Future<DateTime?> vitalsImportCursor() async {
    final raw = await _storage.read(key: _vitalsImportCursorKey);
    return raw == null ? null : DateTime.tryParse(raw);
  }

  Future<void> setVitalsImportCursor(DateTime lastSampleAt) {
    return _storage.write(key: _vitalsImportCursorKey, value: lastSampleAt.toUtc().toIso8601String());
  }

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

  /// The calendar date on which the "daily step goal reached" notification last
  /// fired — prevents firing it more than once per day.
  Future<DateTime?> lastStepGoalNotifiedDate() async {
    final raw = await _storage.read(key: _lastStepGoalNotifiedKey);
    return raw == null ? null : DateTime.tryParse(raw);
  }

  Future<void> setLastStepGoalNotifiedDate(DateTime date) {
    return _storage.write(key: _lastStepGoalNotifiedKey, value: date.toIso8601String());
  }

  /// Whether the "daily step goal reached" local notification should fire at
  /// all (docs/30-push-notifications-plan.md, M5) — defaults on, preserving
  /// the pre-existing behavior for anyone who never visits the new
  /// notification settings screen.
  Future<bool> isStepGoalNotificationEnabled() async {
    final raw = await _storage.read(key: _stepGoalNotificationEnabledKey);
    return raw != 'false';
  }

  Future<void> setStepGoalNotificationEnabled(bool enabled) {
    return _storage.write(
      key: _stepGoalNotificationEnabledKey,
      value: enabled ? 'true' : 'false',
    );
  }

  /// Clears device-local health preferences on logout, so a different
  /// account signing in on this device doesn't inherit them.
  Future<void> clear() async {
    await _storage.delete(key: _enabledKey);
    await _storage.delete(key: _lastWeightImportKey);
    await _storage.delete(key: _lastStepGoalNotifiedKey);
    await _storage.delete(key: _stepGoalNotificationEnabledKey);
    await _storage.delete(key: _cardioImportEnabledKey);
    await _storage.delete(key: _cardioImportCursorKey);
    await _storage.delete(key: _sleepImportEnabledKey);
    await _storage.delete(key: _sleepImportCursorKey);
    await _storage.delete(key: _vitalsImportEnabledKey);
    await _storage.delete(key: _vitalsImportCursorKey);
  }
}

final healthPreferencesProvider = Provider<HealthPreferences>((ref) {
  return HealthPreferences(const FlutterSecureStorage());
});
