import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _lastSeenKey = 'streaks.lastSeenRecapWeekStart';

/// Device-local "have I already seen this week's recap" marker for the
/// dashboard's recap-ready card (docs/37-streaks-weekly-recap-plan.md, M6).
///
/// Deliberately not part of synced [UserSettings] — same reasoning as
/// `core/health/health_preferences.dart`'s device-local opt-in: whether
/// *this device* has already nudged the user about a given week is
/// meaningless to reconcile across devices or accounts, so there's nothing
/// to sync. Uses `shared_preferences` (not secure storage) matching
/// `OnboardingBanner`'s dismissal flag — a plain "seen" marker, not secret.
class RecapPreferences {
  Future<DateTime?> lastSeenRecapWeekStart() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_lastSeenKey);
    return raw == null ? null : DateTime.tryParse(raw);
  }

  /// Marks [weekStart] as seen — called both when the recap screen is
  /// opened (any entry point) and when the dashboard card is explicitly
  /// dismissed, so either action suppresses the nudge for that week.
  Future<void> markRecapSeen(DateTime weekStart) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_lastSeenKey, weekStart.toIso8601String());
  }
}

final recapPreferencesProvider = Provider<RecapPreferences>((ref) => RecapPreferences());
