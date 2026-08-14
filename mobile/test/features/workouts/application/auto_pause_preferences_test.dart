import 'package:flutter_test/flutter_test.dart';
import 'package:lifey/features/workouts/application/auto_pause_preferences.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// docs/cardio/59-cardio-implementation-plan.md C4a.5a, Q-D3 — decided: on
/// by default, uniformly across every DISTANCE activity type.

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('isEnabled() defaults to true (Q-D3: on by default)', () async {
    expect(await AutoPausePreferences().isEnabled(), isTrue);
  });

  test('setEnabled(false) persists the opt-out', () async {
    final prefs = AutoPausePreferences();
    await prefs.setEnabled(false);
    expect(await prefs.isEnabled(), isFalse);
  });

  test('setEnabled(true) after an opt-out re-enables it', () async {
    final prefs = AutoPausePreferences();
    await prefs.setEnabled(false);
    await prefs.setEnabled(true);
    expect(await prefs.isEnabled(), isTrue);
  });

  test('a fresh instance reads back what a prior instance wrote (device-local, not in-memory only)',
      () async {
    await AutoPausePreferences().setEnabled(false);
    expect(await AutoPausePreferences().isEnabled(), isFalse);
  });
}
