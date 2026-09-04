import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _lastShownKey = 'ads.lastInterstitialShownAt';

/// Persists the interstitial rate limit's anchor (`67` §5.3, "≥ 4 h since
/// the last interstitial, from `shared_preferences`") across process
/// restarts — 63 §8.8 calls out in-memory-only as "the classic bug here":
/// without this surviving a cold start, a killed-and-relaunched app would
/// show a fresh interstitial seconds after the last one. Same
/// `shared_preferences`, same shape as `RecapPreferences`.
class InterstitialPreferences {
  Future<DateTime?> lastShownAt() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_lastShownKey);
    return raw == null ? null : DateTime.tryParse(raw);
  }

  Future<void> markShown(DateTime at) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_lastShownKey, at.toIso8601String());
  }
}

final interstitialPreferencesProvider =
    Provider<InterstitialPreferences>((ref) => InterstitialPreferences());
