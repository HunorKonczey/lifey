import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'cardio_health_importer.dart';
import 'health_preferences.dart';
import 'health_service.dart';

/// What the cardio-import settings row shows (docs/integrations/89 G1.6).
class CardioImportStatus {
  const CardioImportStatus({required this.enabled, this.permissionMissing = false});

  /// The device-local opt-in (D-G5), off until the user turns it on.
  final bool enabled;

  /// On, but Health Connect says the workout access was revoked. Only ever
  /// true on Android ([HealthService.hasCardioImportPermissions]).
  final bool permissionMissing;
}

/// Exposes and changes the "Cardio from other apps" opt-in (D-G5).
///
/// Turning it on asks for the workout permissions and runs an import right
/// away, instead of waiting for the next app resume. Turning it off only
/// stops future imports (§1 point 5): sessions already imported stay. The
/// importer additionally requires the general Health toggle; the row shows
/// that dependency, this controller doesn't duplicate it.
class CardioImportController extends AsyncNotifier<CardioImportStatus> {
  HealthPreferences get _prefs => ref.read(healthPreferencesProvider);
  HealthService get _service => ref.read(healthServiceProvider);

  @override
  Future<CardioImportStatus> build() async {
    if (!_service.isAvailable) return const CardioImportStatus(enabled: false);
    final enabled = await _prefs.isCardioImportEnabled();
    return CardioImportStatus(enabled: enabled, permissionMissing: enabled && await _permissionRevoked());
  }

  Future<void> setEnabled(bool enabled) async {
    if (!_service.isAvailable) return;
    state = AsyncData(CardioImportStatus(enabled: enabled));
    await _prefs.setCardioImportEnabled(enabled);
    if (enabled) await _requestAndImport();
  }

  /// Re-asks for the permission after the user revoked it (the row's tap
  /// action in the "permission needed" state).
  Future<void> requestPermissionAgain() async {
    if (!_service.isAvailable) return;
    await _requestAndImport();
  }

  Future<void> _requestAndImport() async {
    await _service.requestCardioImportPermissions();
    state = AsyncData(CardioImportStatus(enabled: true, permissionMissing: await _permissionRevoked()));
    unawaited(ref.read(cardioHealthImporterProvider).import());
  }

  Future<bool> _permissionRevoked() async => await _service.hasCardioImportPermissions() == false;
}

final cardioImportControllerProvider =
    AsyncNotifierProvider<CardioImportController, CardioImportStatus>(CardioImportController.new);
