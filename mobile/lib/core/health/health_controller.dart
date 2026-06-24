import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'health_preferences.dart';
import 'health_service.dart';
import 'step_history_importer.dart';
import 'weight_health_importer.dart';

/// Exposes (and mutates) the "Connect Apple Health" opt-in toggle.
///
/// The boolean is the stored device-local preference. Turning it on also fires
/// the HealthKit permission request — there's no point holding the preference
/// without asking for access. Turning it off just clears the preference; we
/// can't revoke HealthKit permission programmatically (the user does that in
/// the Health app), so later phases must additionally check this flag before
/// reading, not assume permission state.
class AppleHealthController extends AsyncNotifier<bool> {
  HealthPreferences get _prefs => ref.read(healthPreferencesProvider);
  HealthService get _service => ref.read(healthServiceProvider);

  @override
  Future<bool> build() async {
    if (!_service.isAvailable) return false;
    return _prefs.isEnabled();
  }

  Future<void> setEnabled(bool enabled) async {
    if (!_service.isAvailable) return;
    state = AsyncData(enabled);
    await _prefs.setEnabled(enabled);
    if (enabled) {
      // Best-effort: HealthKit won't tell us whether READ was actually
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

final appleHealthControllerProvider =
    AsyncNotifierProvider<AppleHealthController, bool>(AppleHealthController.new);
