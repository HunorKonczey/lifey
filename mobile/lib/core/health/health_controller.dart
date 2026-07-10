import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'health_preferences.dart';
import 'health_service.dart';
import 'step_history_importer.dart';
import 'weight_health_importer.dart';

/// Exposes (and mutates) the "Connect Health" opt-in toggle — Apple Health on
/// iOS, Google Health Connect on Android
/// (docs/26-android-health-connect-integration-plan.md).
///
/// The boolean is the stored device-local preference. Turning it on also fires
/// the platform permission request — there's no point holding the preference
/// without asking for access. On Android, if Health Connect isn't installed
/// yet, turning it on instead prompts the Play Store install and leaves the
/// toggle off (there's nothing to request permission against). Turning it off
/// just clears the preference; neither platform lets us revoke permission
/// programmatically (the user does that in the Health/Health Connect app), so
/// later reads must additionally check this flag, not assume permission state.
class HealthController extends AsyncNotifier<bool> {
  HealthPreferences get _prefs => ref.read(healthPreferencesProvider);
  HealthService get _service => ref.read(healthServiceProvider);

  @override
  Future<bool> build() async {
    if (!_service.isAvailable) return false;
    return _prefs.isEnabled();
  }

  Future<void> setEnabled(bool enabled) async {
    if (!_service.isAvailable) return;

    if (enabled && Platform.isAndroid && !await _service.isHealthConnectInstalled()) {
      await _service.promptInstallHealthConnect();
      return;
    }

    state = AsyncData(enabled);
    await _prefs.setEnabled(enabled);
    if (enabled) {
      // Best-effort: neither platform tells us whether READ was actually
      // granted, so we don't flip the toggle back on a `false` return.
      await _service.requestPermissions();
      // Phase 3: try the weight import right away rather than waiting for the
      // next app resume, since granting permission is the other documented
      // trigger.
      unawaited(ref.read(weightHealthImporterProvider).import());
      // Phase 2: backfill recent step counts immediately after permission grant.
      unawaited(ref.read(stepHistoryImporterProvider).import());
    }
  }
}

final healthControllerProvider =
    AsyncNotifierProvider<HealthController, bool>(HealthController.new);
