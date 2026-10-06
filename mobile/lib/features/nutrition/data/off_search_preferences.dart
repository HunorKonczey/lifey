import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _enabledKey = 'nutrition.offSearch.enabled';

/// Per-device memory of the "Search OpenFoodFacts too" checkbox (docs/84 D10): off until the user ticks it, then
/// remembered. Plain `shared_preferences` — a non-sensitive flag, like `InterstitialPreferences`; deliberately not part
/// of the synced `UserSettings`.
class OffSearchPreferences {
  Future<bool> isEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_enabledKey) ?? false;
  }

  Future<void> setEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_enabledKey, enabled);
  }
}

final offSearchPreferencesProvider = Provider<OffSearchPreferences>((ref) => OffSearchPreferences());
