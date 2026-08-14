import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _autoPauseEnabledKey = 'cardio.autoPauseEnabled';

/// Device-local "GPS auto-pause on/off" switch
/// (docs/cardio/53-cardio-mobile-plan.md §4.3, Q-D3 — decided: on by
/// default, uniformly across every DISTANCE activity type, no per-type
/// override). A plain, non-secret `shared_preferences` flag, same choice as
/// `LocationPermissionPreferences` — and, unlike that one, deliberately
/// *not* cleared on logout: this is a device/workout convenience setting a
/// returning user would expect to stay put, not a one-time onboarding flag
/// tied to a specific account's first-run experience.
class AutoPausePreferences {
  Future<bool> isEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_autoPauseEnabledKey) ?? true;
  }

  Future<void> setEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_autoPauseEnabledKey, enabled);
  }
}

final autoPausePreferencesProvider =
    Provider<AutoPausePreferences>((ref) => AutoPausePreferences());
