import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifey/core/location/location_service.dart';
import 'package:lifey/features/workouts/domain/auto_pause_detector.dart';

/// docs/cardio/53-cardio-mobile-plan.md §4.3, C4a.5a — kész-ha: "auto-pause
/// a sebesség-küszöbön ki-/bekapcsol (teszt)". `AutoPauseDetector` has no
/// Flutter dependency of its own, but its Timer needs `flutter_test`'s
/// fake-async clock to be testable deterministically (`tester.pump(duration)`
/// advances `Timer`s without a real wait — see `cardio_session_screen.dart`'s
/// identical reasoning for its own weak-signal timer) — hence `testWidgets`
/// with a throwaway widget rather than a plain `test()`.

LocationFix _fix({double? speed, double? accuracy}) => LocationFix(
      latitude: 47.5,
      longitude: 19.05,
      recordedAt: DateTime.utc(2026, 8, 13),
      speed: speed,
      accuracy: accuracy,
    );

void main() {
  late int stopCalls;
  late int motionCalls;
  late AutoPauseDetector detector;

  Future<void> setUp(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink()); // establishes the fake-async zone
    stopCalls = 0;
    motionCalls = 0;
    detector = AutoPauseDetector(
      accuracyThresholdMeters: 20,
      onSustainedStop: () => stopCalls++,
      onMotion: () => motionCalls++,
    );
  }

  testWidgets('a slow fix held for the full delay fires onSustainedStop', (tester) async {
    await setUp(tester);
    detector.addFix(_fix(speed: 0.2));

    await tester.pump(const Duration(seconds: 15));

    expect(stopCalls, 1);
    expect(motionCalls, 0);
  });

  testWidgets('a slow fix that recovers before the delay elapses never fires onSustainedStop',
      (tester) async {
    await setUp(tester);
    detector.addFix(_fix(speed: 0.2));
    await tester.pump(const Duration(seconds: 10));
    detector.addFix(_fix(speed: 3.0)); // recovers with 5 s to spare

    await tester.pump(const Duration(seconds: 10)); // well past the original deadline

    expect(stopCalls, 0);
    expect(motionCalls, 1);
  });

  testWidgets('a fix exactly at the speed threshold counts as motion, not "slow"',
      (tester) async {
    await setUp(tester);
    detector.addFix(_fix(speed: 0.5)); // >= threshold

    await tester.pump(const Duration(seconds: 15));

    expect(motionCalls, 1);
    expect(stopCalls, 0);
  });

  testWidgets('onMotion fires on every fast fix, even with nothing currently paused',
      (tester) async {
    await setUp(tester);
    detector.addFix(_fix(speed: 3.0));
    detector.addFix(_fix(speed: 3.0));

    expect(motionCalls, 2);
    expect(stopCalls, 0);
  });

  testWidgets('an inaccurate fix ("nincs GPS-jel") is ignored entirely — no countdown starts',
      (tester) async {
    await setUp(tester);
    detector.addFix(_fix(speed: 0.1, accuracy: 999)); // way over the 20 m threshold

    await tester.pump(const Duration(seconds: 15));

    expect(stopCalls, 0);
    expect(motionCalls, 0);
  });

  testWidgets('a null speed reading is ignored — neither starts nor cancels the countdown',
      (tester) async {
    await setUp(tester);
    detector.addFix(_fix(speed: 0.2));
    await tester.pump(const Duration(seconds: 5));
    detector.addFix(_fix()); // no speed at all
    await tester.pump(const Duration(seconds: 10)); // completes the original 15 s

    expect(stopCalls, 1); // the null-speed fix didn't reset or cancel anything
  });

  testWidgets('reset() cancels a pending countdown without firing', (tester) async {
    await setUp(tester);
    detector.addFix(_fix(speed: 0.2));
    await tester.pump(const Duration(seconds: 10));

    detector.reset();
    await tester.pump(const Duration(seconds: 10));

    expect(stopCalls, 0);
  });

  testWidgets('a second slow fix while already counting down does not restart the clock',
      (tester) async {
    await setUp(tester);
    detector.addFix(_fix(speed: 0.2));
    await tester.pump(const Duration(seconds: 10));
    detector.addFix(_fix(speed: 0.1)); // still slow — must not push the deadline out further
    await tester.pump(const Duration(seconds: 5)); // 15 s since the *first* slow fix

    expect(stopCalls, 1);
  });

  testWidgets('dispose() cancels a pending countdown without firing', (tester) async {
    await setUp(tester);
    detector.addFix(_fix(speed: 0.2));
    await tester.pump(const Duration(seconds: 10));

    detector.dispose();
    await tester.pump(const Duration(seconds: 10));

    expect(stopCalls, 0);
  });
}
