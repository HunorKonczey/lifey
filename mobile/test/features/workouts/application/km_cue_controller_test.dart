import 'package:flutter_test/flutter_test.dart';
import 'package:lifey/features/workouts/application/km_cue_controller.dart';

/// docs/cardio/60 C6.6 — the kilometre cue's boundary maths. Every failure
/// mode here is silent in the sense that matters on a run: a missed buzz or a
/// spurious one is only noticed mid-workout, with nothing to inspect after.

void main() {
  group('KmCueController', () {
    late List<int> cues;
    late KmCueController controller;

    setUp(() {
      cues = [];
      controller = KmCueController(unitMeters: 1000, onCue: (unit, _) => cues.add(unit));
    });

    test('fires once as each kilometre completes', () {
      controller.onDistance(400);
      controller.onDistance(999);
      expect(cues, isEmpty);

      controller.onDistance(1000);
      expect(cues, [1]);

      controller.onDistance(1500);
      expect(cues, [1]);

      controller.onDistance(2010);
      expect(cues, [1, 2]);
    });

    test('never fires twice for the same kilometre', () {
      controller.onDistance(1200);
      controller.onDistance(1300);
      controller.onDistance(1400);

      expect(cues, [1]);
    });

    test('a jump across several boundaries is one cue, not a burst', () {
      // A long GPS gap, or a coarse fix after a tunnel: the runner is on km 4
      // and wants to know that — not to be buzzed three times in a row.
      controller.onDistance(4100);

      expect(cues, [4]);
    });

    test('a distance that goes backwards never re-fires', () {
      // The filtered distance only grows in practice, but a rebuilt
      // accumulator could hand over a smaller number — that must stay silent
      // rather than re-announcing kilometres already called.
      controller.onDistance(3000);
      controller.onDistance(2000);
      controller.onDistance(2500);

      expect(cues, [3]);
    });

    test('seeding adopts covered ground without announcing it', () {
      // Reopening a 7 km run after an app kill replays the whole stored
      // track into the live distance in one frame.
      controller.seed(7300);
      controller.onDistance(7300);
      expect(cues, isEmpty);

      controller.onDistance(8000);
      expect(cues, [8]);
    });

    test('seeding a fresh session leaves the first kilometre to be announced', () {
      controller.seed(0);
      controller.onDistance(1000);

      expect(cues, [1]);
    });

    test('an imperial profile cues on miles, not kilometres', () {
      final miles = <int>[];
      final imperial =
          KmCueController(unitMeters: 1609.344, onCue: (unit, _) => miles.add(unit));

      imperial.onDistance(1000);
      imperial.onDistance(1500);
      expect(miles, isEmpty, reason: 'a kilometre is not a mile');

      imperial.onDistance(1610);
      expect(miles, [1]);

      imperial.onDistance(3220);
      expect(miles, [1, 2]);
    });

    test('the cue carries the distance at the moment it fired', () {
      final seen = <(int, double)>[];
      final c = KmCueController(
        unitMeters: 1000,
        onCue: (unit, meters) => seen.add((unit, meters)),
      );

      c.onDistance(2004.5);

      expect(seen, [(2, 2004.5)]);
    });

    test('zero and negative distances are silent, not a crash', () {
      controller.onDistance(0);
      controller.onDistance(-5);

      expect(cues, isEmpty);
    });
  });
}
