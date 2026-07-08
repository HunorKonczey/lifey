import 'package:flutter_test/flutter_test.dart';
import 'package:lifey/features/workouts/domain/workout_session.dart';
import 'package:lifey/features/workouts/presentation/widgets/upcoming_sessions_section.dart';

WorkoutSession _upcoming(DateTime scheduledFor, {String? scheduledTime}) {
  return WorkoutSession(
    clientId: 'c',
    exercises: const [],
    sets: const [],
    scheduledFor: scheduledFor,
    scheduledTime: scheduledTime,
  );
}

DateTime _today() {
  final now = DateTime.now();
  return DateTime(now.year, now.month, now.day);
}

void main() {
  group('isWithinUpcomingWindow', () {
    test('includes today', () {
      expect(isWithinUpcomingWindow(_upcoming(_today())), isTrue);
    });

    test('includes exactly 6 days from now (the inclusive boundary)', () {
      expect(isWithinUpcomingWindow(_upcoming(_today().add(const Duration(days: 6)))), isTrue);
    });

    test('excludes 7 days from now (one day past the window)', () {
      expect(isWithinUpcomingWindow(_upcoming(_today().add(const Duration(days: 7)))), isFalse);
    });

    test('excludes yesterday (already missed)', () {
      expect(isWithinUpcomingWindow(_upcoming(_today().subtract(const Duration(days: 1)))), isFalse);
    });

    test('excludes a session that has already started, even if scheduledFor is in range', () {
      final session = WorkoutSession(
        clientId: 'c',
        exercises: const [],
        sets: const [],
        startedAt: DateTime.now(),
        scheduledFor: _today(),
      );
      expect(isWithinUpcomingWindow(session), isFalse);
    });

    test('excludes a normal (non-scheduled) session', () {
      final session = WorkoutSession(
        clientId: 'c',
        exercises: const [],
        sets: const [],
        startedAt: DateTime.now(),
      );
      expect(isWithinUpcomingWindow(session), isFalse);
    });
  });
}
