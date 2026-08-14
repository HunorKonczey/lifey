import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _gpsExplainerSeenKey = 'location.gpsExplainerSeen';

/// Device-local "has the user already seen the GPS explainer sheet" flag
/// (docs/cardio/54-cardio-gps-route-plan.md §3.1: shown once, before the
/// very first DISTANCE-family cardio session ever, never again — regardless
/// of which button the user tapped, "Allow location" or "Start without
/// GPS"). A plain non-secret flag, matching `MusicPreferences`'s choice of
/// `shared_preferences` over secure storage for the same reason.
class LocationPermissionPreferences {
  Future<bool> hasSeenGpsExplainer() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_gpsExplainerSeenKey) ?? false;
  }

  Future<void> setSeenGpsExplainer() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_gpsExplainerSeenKey, true);
  }

  /// Fresh start for whoever logs into this device next — same
  /// "per-account, not per-device" policy `AuthController.logout()` already
  /// applies to `MusicPreferences`/`HealthPreferences`.
  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_gpsExplainerSeenKey);
  }
}

final locationPermissionPreferencesProvider =
    Provider<LocationPermissionPreferences>((ref) => LocationPermissionPreferences());
