import 'package:flutter_test/flutter_test.dart';
import 'package:lifey/features/workouts/domain/workout_session.dart';

/// C2.1: the epoch-checkpoint live-duration math
/// (docs/cardio/59-cardio-implementation-plan.md C2.1) — the piece the
/// step's kész-ha ("App-kilövés után az edzés helyreáll a pontos
/// mozgásidővel") actually rests on. A session freshly loaded from Drift
/// after an app kill is exactly the same shape as one built directly here:
/// `movingSeconds` frozen as of the last checkpoint, `movingSinceEpochMs`
/// unchanged since — so these pure tests double as the "restores after a
/// kill" proof, without needing to simulate an actual process kill.

WorkoutSession _cardioSession({
  int? movingSeconds,
  int? movingSinceEpochMs,
  DateTime? finishedAt,
}) {
  final startedAt = DateTime(2026, 8, 11, 7);
  return WorkoutSession(
    clientId: 'c1',
    exercises: const [],
    sets: const [],
    startedAt: startedAt,
    finishedAt: finishedAt,
    sessionKind: 'CARDIO',
    activityType: 'RUNNING',
    movingSeconds: movingSeconds,
    movingSinceEpochMs: movingSinceEpochMs,
  );
}

void main() {
  group('liveMovingSeconds', () {
    test('paused (no checkpoint): returns the frozen total as-is', () {
      final session = _cardioSession(movingSeconds: 754);
      expect(session.liveMovingSeconds(DateTime(2026, 8, 11, 8)), 754);
    });

    test('never moved yet: null movingSeconds reads as 0, not a crash', () {
      final session = _cardioSession();
      expect(session.liveMovingSeconds(DateTime(2026, 8, 11, 8)), 0);
    });

    test('running: adds the elapsed wall-clock time since the checkpoint', () {
      final since = DateTime(2026, 8, 11, 7, 30);
      final session = _cardioSession(movingSeconds: 600, movingSinceEpochMs: since.millisecondsSinceEpoch);
      final now = since.add(const Duration(minutes: 5));
      expect(session.liveMovingSeconds(now), 600 + 300);
    });

    test('a checkpoint far in the past (simulating an app-kill gap) is folded in whole', () {
      // This is the exact shape a session loaded fresh from Drift after the
      // OS killed the app mid-workout would have: movingSinceEpochMs still
      // points at whenever the last RUNNING interval started, however long
      // ago that was — nothing about it "expires" just because the process died.
      final since = DateTime(2026, 8, 11, 7, 0);
      final session = _cardioSession(movingSeconds: 0, movingSinceEpochMs: since.millisecondsSinceEpoch);
      final reopenedAt = since.add(const Duration(hours: 1, minutes: 12));
      expect(session.liveMovingSeconds(reopenedAt), const Duration(hours: 1, minutes: 12).inSeconds);
    });
  });

  group('isCardioRunning', () {
    test('true when in progress with an open checkpoint', () {
      final session = _cardioSession(movingSeconds: 10, movingSinceEpochMs: 1000);
      expect(session.isCardioRunning, isTrue);
    });

    test('false when paused (no checkpoint)', () {
      final session = _cardioSession(movingSeconds: 10);
      expect(session.isCardioRunning, isFalse);
    });

    test('false once finished, even if a checkpoint was left dangling', () {
      final session = _cardioSession(
        movingSeconds: 10,
        movingSinceEpochMs: 1000,
        finishedAt: DateTime(2026, 8, 11, 8),
      );
      expect(session.isCardioRunning, isFalse);
    });
  });
}
