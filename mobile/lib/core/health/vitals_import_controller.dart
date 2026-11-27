import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'health_preferences.dart';
import 'health_service.dart';
import 'vitals_health_importer.dart';

/// What the vitals-import settings row shows (docs/integrations/89 G3.3).
class VitalsImportStatus {
  const VitalsImportStatus({required this.enabled, this.permissionMissing = false});

  /// The device-local opt-in (D-G5), off until the user turns it on.
  final bool enabled;

  /// On, but Health Connect says the access was revoked. Only ever true on
  /// Android ([HealthService.hasVitalsImportPermissions]).
  final bool permissionMissing;
}

/// Exposes and changes the "Resting heart rate & HRV" opt-in (D-G5), the
/// vitals counterpart of [SleepImportController].
///
/// Turning it on asks for the resting-HR and HRV permissions and runs an
/// import right away. Turning it off only stops future imports: days already
/// imported stay. The importer also requires the general Health toggle; the
/// row shows that dependency.
class VitalsImportController extends AsyncNotifier<VitalsImportStatus> {
  HealthPreferences get _prefs => ref.read(healthPreferencesProvider);
  HealthService get _service => ref.read(healthServiceProvider);

  @override
  Future<VitalsImportStatus> build() async {
    if (!_service.isAvailable) return const VitalsImportStatus(enabled: false);
    final enabled = await _prefs.isVitalsImportEnabled();
    return VitalsImportStatus(enabled: enabled, permissionMissing: enabled && await _permissionRevoked());
  }

  Future<void> setEnabled(bool enabled) async {
    if (!_service.isAvailable) return;
    state = AsyncData(VitalsImportStatus(enabled: enabled));
    await _prefs.setVitalsImportEnabled(enabled);
    if (enabled) await _requestAndImport();
  }

  /// Re-asks for the permission after the user revoked it (the row's tap
  /// action in the "permission needed" state).
  Future<void> requestPermissionAgain() async {
    if (!_service.isAvailable) return;
    await _requestAndImport();
  }

  Future<void> _requestAndImport() async {
    await _service.requestVitalsImportPermissions();
    state = AsyncData(VitalsImportStatus(enabled: true, permissionMissing: await _permissionRevoked()));
    unawaited(ref.read(vitalsHealthImporterProvider).import());
  }

  Future<bool> _permissionRevoked() async => await _service.hasVitalsImportPermissions() == false;
}

final vitalsImportControllerProvider =
    AsyncNotifierProvider<VitalsImportController, VitalsImportStatus>(VitalsImportController.new);
