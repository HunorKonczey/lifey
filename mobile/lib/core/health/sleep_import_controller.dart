import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'health_preferences.dart';
import 'health_service.dart';
import 'sleep_health_importer.dart';

/// What the sleep-import settings row shows (docs/integrations/89 G2.4).
class SleepImportStatus {
  const SleepImportStatus({required this.enabled, this.permissionMissing = false});

  /// The device-local opt-in (D-G5), off until the user turns it on.
  final bool enabled;

  /// On, but Health Connect says the sleep access was revoked. Only ever
  /// true on Android ([HealthService.hasSleepImportPermissions]).
  final bool permissionMissing;
}

/// Exposes and changes the "Sleep from other apps" opt-in (D-G5), the sleep
/// counterpart of [CardioImportController].
///
/// Turning it on asks for the sleep permissions and runs an import right
/// away, instead of waiting for the next app resume. Turning it off only
/// stops future imports: nights already imported stay. The importer also
/// requires the general Health toggle; the row shows that dependency.
class SleepImportController extends AsyncNotifier<SleepImportStatus> {
  HealthPreferences get _prefs => ref.read(healthPreferencesProvider);
  HealthService get _service => ref.read(healthServiceProvider);

  @override
  Future<SleepImportStatus> build() async {
    if (!_service.isAvailable) return const SleepImportStatus(enabled: false);
    final enabled = await _prefs.isSleepImportEnabled();
    return SleepImportStatus(enabled: enabled, permissionMissing: enabled && await _permissionRevoked());
  }

  Future<void> setEnabled(bool enabled) async {
    if (!_service.isAvailable) return;
    state = AsyncData(SleepImportStatus(enabled: enabled));
    await _prefs.setSleepImportEnabled(enabled);
    if (enabled) await _requestAndImport();
  }

  /// Re-asks for the permission after the user revoked it (the row's tap
  /// action in the "permission needed" state).
  Future<void> requestPermissionAgain() async {
    if (!_service.isAvailable) return;
    await _requestAndImport();
  }

  Future<void> _requestAndImport() async {
    await _service.requestSleepImportPermissions();
    state = AsyncData(SleepImportStatus(enabled: true, permissionMissing: await _permissionRevoked()));
    unawaited(ref.read(sleepHealthImporterProvider).import());
  }

  Future<bool> _permissionRevoked() async => await _service.hasSleepImportPermissions() == false;
}

final sleepImportControllerProvider =
    AsyncNotifierProvider<SleepImportController, SleepImportStatus>(SleepImportController.new);
