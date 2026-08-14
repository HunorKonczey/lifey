import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifey/features/dashboard/application/dashboard_controller.dart';
import 'package:lifey/features/nutrition/application/meal_controller.dart';
import 'package:lifey/features/nutrition/domain/meal.dart';
import 'package:lifey/features/water/data/water_entry_repository.dart';
import 'package:lifey/features/weight/application/weight_controller.dart';
import 'package:lifey/features/weight/domain/weight_entry.dart';
import 'package:lifey/features/workouts/application/exercise_controller.dart';
import 'package:lifey/features/workouts/application/workout_session_controller.dart';
import 'package:lifey/features/workouts/domain/exercise.dart';
import 'package:lifey/features/workouts/domain/workout_session.dart';

/// This is the dashboard feature's first test file — `dashboard_controller.dart`
/// had none before C3.4 added the strength/cardio breakdown
/// (docs/cardio/56-cardio-statistics-plan.md §4). Everything else this
/// provider computes (calories/protein/water/weight) stays deliberately
/// untested here — this file only covers what C3.4 actually changed.
final _now = DateTime.now();
DateTime _today({int hour = 12}) => DateTime(_now.year, _now.month, _now.day, hour);

WorkoutSession _strengthSession(DateTime startedAt) {
  return WorkoutSession(
    clientId: 'strength-${startedAt.microsecondsSinceEpoch}',
    startedAt: startedAt,
    finishedAt: startedAt.add(const Duration(minutes: 40)),
    exercises: const [],
    sets: const [],
  );
}

WorkoutSession _cardioSession(DateTime startedAt, {String activityType = 'RUNNING'}) {
  return WorkoutSession(
    clientId: 'cardio-${startedAt.microsecondsSinceEpoch}',
    startedAt: startedAt,
    finishedAt: startedAt.add(const Duration(hours: 1)),
    exercises: const [],
    sets: const [],
    sessionKind: 'CARDIO',
    activityType: activityType,
  );
}

class _FakeMealController extends MealController {
  @override
  Stream<List<Meal>> build() => Stream.value(const []);
}

class _FakeWorkoutSessionController extends WorkoutSessionController {
  _FakeWorkoutSessionController(this._sessions);
  final List<WorkoutSession> _sessions;

  @override
  Stream<List<WorkoutSession>> build() => Stream.value(_sessions);
}

class _FakeExerciseController extends ExerciseController {
  @override
  Stream<List<Exercise>> build() => Stream.value(const []);
}

class _FakeWeightController extends WeightController {
  @override
  Stream<List<WeightEntry>> build() => Stream.value(const []);
}

ProviderContainer _buildContainer(List<WorkoutSession> sessions) {
  return ProviderContainer(
    overrides: [
      mealControllerProvider.overrideWith(_FakeMealController.new),
      workoutSessionControllerProvider.overrideWith(() => _FakeWorkoutSessionController(sessions)),
      exerciseControllerProvider.overrideWith(_FakeExerciseController.new),
      weightControllerProvider.overrideWith(_FakeWeightController.new),
      todayWaterTotalProvider.overrideWith((ref) => Stream.value(0.0)),
    ],
  );
}

Future<void> _settle(ProviderContainer container) async {
  await container.listen(workoutSessionControllerProvider.future, (previous, next) {}).read();
}

void main() {
  group('dashboardControllerProvider — strength/cardio breakdown (C3.4)', () {
    test('strengthWorkoutCount + cardioWorkoutCount always sum to workoutCount', () async {
      final container = _buildContainer([
        _strengthSession(_today(hour: 7)),
        _cardioSession(_today(hour: 9)),
        _cardioSession(_today(hour: 18), activityType: 'INDOOR_BIKE'),
      ]);
      addTearDown(container.dispose);
      await _settle(container);

      final stats = container.read(dashboardControllerProvider).stats;
      expect(stats.workoutCount, 3);
      expect(stats.strengthWorkoutCount, 1);
      expect(stats.cardioWorkoutCount, 2);
    });

    test('a purely strength day has cardioWorkoutCount 0', () async {
      final container = _buildContainer([_strengthSession(_today())]);
      addTearDown(container.dispose);
      await _settle(container);

      final stats = container.read(dashboardControllerProvider).stats;
      expect(stats.strengthWorkoutCount, 1);
      expect(stats.cardioWorkoutCount, 0);
    });

    test('no workouts today -> both counts are 0', () async {
      final container = _buildContainer(const []);
      addTearDown(container.dispose);
      await _settle(container);

      final stats = container.read(dashboardControllerProvider).stats;
      expect(stats.workoutCount, 0);
      expect(stats.strengthWorkoutCount, 0);
      expect(stats.cardioWorkoutCount, 0);
    });

    test('a session from a previous day does not count toward today\'s breakdown', () async {
      final container = _buildContainer([
        _cardioSession(_today().subtract(const Duration(days: 1))),
      ]);
      addTearDown(container.dispose);
      await _settle(container);

      final stats = container.read(dashboardControllerProvider).stats;
      expect(stats.workoutCount, 0);
      expect(stats.cardioWorkoutCount, 0);
    });
  });

  group('dashboardControllerProvider — RecentWorkout kind fields (C3.4)', () {
    test('carries sessionKind + activityType through for the icon', () async {
      final container = _buildContainer([
        _cardioSession(_today(hour: 9), activityType: 'WALKING'),
        _strengthSession(_today(hour: 7)),
      ]);
      addTearDown(container.dispose);
      await _settle(container);

      final recent = container.read(dashboardControllerProvider).recentWorkouts;
      final cardio = recent.firstWhere((w) => w.isCardio);
      final strength = recent.firstWhere((w) => !w.isCardio);

      expect(cardio.sessionKind, 'CARDIO');
      expect(cardio.activityType, 'WALKING');
      expect(strength.sessionKind, 'STRENGTH');
      expect(strength.activityType, isNull);
    });
  });
}
