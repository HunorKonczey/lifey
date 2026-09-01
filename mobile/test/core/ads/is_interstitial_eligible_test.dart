import 'package:flutter_test/flutter_test.dart';
import 'package:lifey/core/ads/interstitial_manager.dart';

/// Covers Prompt 10's verify line: unit tests per condition, over the pure
/// `isInterstitialEligible` (`67` §5.3's six conditions, all required).

void main() {
  final now = DateTime(2026, 9, 1, 12, 0, 0);

  bool eligible({
    bool adsEnabled = true,
    bool hasActiveSession = false,
    bool shownThisSession = false,
    Duration foregroundDuration = const Duration(minutes: 5),
    bool openedFromPush = false,
    DateTime? lastShownAt,
  }) {
    return isInterstitialEligible(
      adsEnabled: adsEnabled,
      hasActiveSession: hasActiveSession,
      shownThisSession: shownThisSession,
      foregroundDuration: foregroundDuration,
      openedFromPush: openedFromPush,
      lastShownAt: lastShownAt,
      now: now,
    );
  }

  test('all six conditions satisfied: eligible', () {
    expect(eligible(), isTrue);
  });

  test('adsEnabled: false (Pro, or unresolved and fail-open) makes it ineligible', () {
    expect(eligible(adsEnabled: false), isFalse);
  });

  test('an active workout or cardio session makes it ineligible', () {
    expect(eligible(hasActiveSession: true), isFalse);
  });

  test('already shown this app session makes it ineligible', () {
    expect(eligible(shownThisSession: true), isFalse);
  });

  test('foregrounded under 60s (a cold start, or a very recent resume) makes it ineligible', () {
    expect(eligible(foregroundDuration: const Duration(seconds: 59)), isFalse);
  });

  test('foregrounded for exactly 60s is already eligible', () {
    expect(eligible(foregroundDuration: const Duration(seconds: 60)), isTrue);
  });

  test('a route opened from a push notification makes it ineligible', () {
    expect(eligible(openedFromPush: true), isFalse);
  });

  test('under 4h since the last interstitial makes it ineligible', () {
    expect(eligible(lastShownAt: now.subtract(const Duration(hours: 3, minutes: 59))), isFalse);
  });

  test('exactly 4h since the last interstitial is already eligible again', () {
    expect(eligible(lastShownAt: now.subtract(const Duration(hours: 4))), isTrue);
  });

  test('never shown before (lastShownAt: null) does not gate on the rate limit', () {
    expect(eligible(lastShownAt: null), isTrue);
  });
}
