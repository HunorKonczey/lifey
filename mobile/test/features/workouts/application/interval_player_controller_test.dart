import 'package:flutter_test/flutter_test.dart';
import 'package:lifey/features/workouts/application/interval_player_controller.dart';
import 'package:lifey/features/workouts/domain/cardio_interval_plan.dart';
import 'package:lifey/features/workouts/domain/workout_session.dart';

/// docs/cardio/60 C7.5 — the player's whole contract, minus pixels: it owns
/// no clock. Every case here drives it with a moving-second number, which is
/// what makes the two risky promises testable without a 30-minute device
/// ride: the section clock stops when the session pauses (docs/cardio/60 §9),
/// and the executed sections are saved as INTERVAL splits.

const _fourByFour = CardioIntervalPlan(
  clientId: 'plan-1',
  name: 'Kedd esti 4x4',
  steps: [
    IntervalStep.section(
        name: 'Warm-up', intensity: IntervalIntensity.easy, durationSeconds: 300),
    IntervalStep.block(repeatCount: 4, children: [
      IntervalStep.section(
          name: 'Hard', intensity: IntervalIntensity.hard, durationSeconds: 240),
      IntervalStep.section(
          name: 'Rest', intensity: IntervalIntensity.easy, durationSeconds: 180),
    ]),
    IntervalStep.section(
        name: 'Cool-down', intensity: IntervalIntensity.easy, durationSeconds: 300),
  ],
);

void main() {
  group('expanding the plan', () {
    test('a repeat block becomes one section per repetition', () {
      final sections = IntervalPlayerController.expandPlan(_fourByFour);

      // Warm-up + 4×(hard, rest) + cool-down = 10, the number M37's header
      // shows and the player counts down from.
      expect(sections, hasLength(10));
      expect(sections.map((s) => s.durationSeconds),
          [300, 240, 180, 240, 180, 240, 180, 240, 180, 300]);
      expect(sections[1].intensity, IntervalIntensity.hard);
      expect(sections[2].intensity, IntervalIntensity.easy);
    });
  });

  group('playback against moving time', () {
    test('the first section counts down from its own length', () {
      final player = IntervalPlayerController(plan: _fourByFour);

      final state = player.update(12);

      expect(state.sectionNumber, 1);
      expect(state.totalSections, 10);
      expect(state.secondsRemaining, 288);
      expect(state.intensity, IntervalIntensity.easy);
      // "Utána: 4:00 kemény" — the preview is part of the same state.
      expect(state.nextIntensity, IntervalIntensity.hard);
      expect(state.nextDurationSeconds, 240);
    });

    test('crossing a boundary advances exactly one section', () {
      final player = IntervalPlayerController(plan: _fourByFour);
      player.update(299);
      final state = player.update(300);

      expect(state.sectionNumber, 2);
      expect(state.intensity, IntervalIntensity.hard);
      expect(state.secondsRemaining, 240);
    });

    test('a section that the app slept through is caught up in one update', () {
      // Backgrounded for eight minutes: moving time kept accruing, so the
      // player has to land on the section the rider is actually in, not
      // replay the ones behind them.
      final player = IntervalPlayerController(plan: _fourByFour);

      final state = player.update(600);

      expect(state.sectionNumber, 3); // warm-up, first hard, now the first rest
      expect(state.secondsRemaining, 120);
    });

    test('the last three seconds are the countdown the haptics ride on', () {
      final player = IntervalPlayerController(plan: _fourByFour);

      expect(player.update(296).isCountingDown, isFalse);
      expect(player.update(297).isCountingDown, isTrue);
      expect(player.update(299).isCountingDown, isTrue);
    });

    test('a paused session freezes the section clock', () {
      // A pause doesn't advance movingSeconds, so feeding the same number
      // again is exactly what the screen does while paused — and the section
      // must not move on. This is the promise that a plan does not "run out
      // into nothing" during a break (M38's paused state).
      final player = IntervalPlayerController(plan: _fourByFour);
      final before = player.update(200);
      final during = player.update(200);
      final stillThere = player.update(200);

      expect(before.secondsRemaining, 100);
      expect(during.secondsRemaining, 100);
      expect(stillThere.sectionNumber, 1);
    });

    test('the plan running out leaves the screen on the last section', () {
      final player = IntervalPlayerController(plan: _fourByFour);

      final state = player.update(3000);

      expect(state.finished, isTrue);
      expect(state.sectionNumber, 10);
      expect(state.totalSections, 10);
      expect(state.secondsRemaining, 0);
    });

    test('every boundary crossing is announced once', () {
      final seen = <int>[];
      final player = IntervalPlayerController(
        plan: _fourByFour,
        onSectionChanged: (state) => seen.add(state.sectionNumber),
      );

      player.update(0);
      player.update(299);
      player.update(300);
      player.update(400);
      player.update(540);

      // Section 1 is never "changed to" — it's where playback starts.
      expect(seen, [2, 3]);
    });
  });

  group('skip', () {
    test('ends the current section now and moves to the next', () {
      final player = IntervalPlayerController(plan: _fourByFour);
      player.update(60);

      final state = player.skip(60);

      expect(state.sectionNumber, 2);
      expect(state.intensity, IntervalIntensity.hard);
      // The next section starts from the moment of the skip, not from where
      // the skipped one would have ended.
      expect(player.update(60).secondsRemaining, 240);
      expect(player.update(100).secondsRemaining, 200);
    });

    test('records the skipped section with the time it actually got', () {
      final player = IntervalPlayerController(plan: _fourByFour);
      player.update(60);
      player.skip(60);

      final splits = player.executedSplits(60);
      expect(splits.first.durationSeconds, 60); // not 300
    });

    test('skipping past the end is a no-op', () {
      final player = IntervalPlayerController(plan: _fourByFour);
      player.update(3000);

      final state = player.skip(3000);

      expect(state.finished, isTrue);
      expect(state.sectionNumber, 10);
    });
  });

  group('executed splits', () {
    test('are INTERVAL splits carrying their own intensity and no distance', () {
      final player = IntervalPlayerController(plan: _fourByFour);
      // A second into the first rest: the warm-up and the hard section are
      // done, the rest has just started.
      player.update(541);

      final splits = player.executedSplits(541);

      expect(splits.map((s) => s.splitType),
          everyElement(CardioSplitType.interval));
      expect(splits.map((s) => s.distanceMeters), everyElement(isNull));
      expect(splits.map((s) => s.intensity).take(2),
          [IntervalIntensity.easy, IntervalIntensity.hard]);
      expect(splits.map((s) => s.splitIndex), [0, 1, 2]);
    });

    test('include the section still running, cut off where the ride ended', () {
      final player = IntervalPlayerController(plan: _fourByFour);
      player.update(400); // 100 s into the first hard section

      final splits = player.executedSplits(400);

      expect(splits, hasLength(2));
      expect(splits.last.durationSeconds, 100);
      expect(splits.last.intensity, IntervalIntensity.hard);
    });

    test('add up to the moving time, skips and all', () {
      final player = IntervalPlayerController(plan: _fourByFour);
      player.update(300);
      player.skip(420); // cut the first hard section short at 120 s
      player.update(500);

      final total = player
          .executedSplits(500)
          .fold<int>(0, (sum, s) => sum + s.durationSeconds);
      expect(total, 500);
    });

    test('a finished plan stops adding sections even as the ride continues', () {
      final player = IntervalPlayerController(plan: _fourByFour);
      player.update(3000);

      final splits = player.executedSplits(4000);

      expect(splits, hasLength(10));
      expect(splits.fold<int>(0, (sum, s) => sum + s.durationSeconds), 2280);
    });
  });
}
