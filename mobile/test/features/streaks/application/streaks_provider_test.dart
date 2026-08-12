import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifey/features/nutrition/application/daily_macros_controller.dart';
import 'package:lifey/features/nutrition/domain/daily_macros.dart';
import 'package:lifey/features/settings/application/settings_controller.dart';
import 'package:lifey/features/settings/domain/user_settings.dart';
import 'package:lifey/features/steps/data/step_count_repository.dart';
import 'package:lifey/features/steps/domain/daily_step_count.dart';
import 'package:lifey/features/streaks/application/streaks_provider.dart';
import 'package:lifey/features/streaks/domain/streak.dart';
import 'package:lifey/features/water/application/daily_water_totals_provider.dart';
import 'package:lifey/features/workouts/application/workout_session_controller.dart';
import 'package:lifey/features/workouts/domain/workout_session.dart';

/// Anchors every test's dates relative to "now", same convention as
/// `stat_chart_data_test.dart`, so the suite never goes stale.
final _now = DateTime.now();
DateTime _day(int offset) =>
    DateTime(_now.year, _now.month, _now.day).subtract(Duration(days: offset));

DailyMacros _macros(DateTime day, {double calories = 0}) {
  return DailyMacros(day: day, calories: calories, protein: 0, carbs: 0, fat: 0);
}

DailyStepCount _steps(DateTime day, int steps) {
  return DailyStepCount(clientId: 'steps-${day.microsecondsSinceEpoch}', date: day, steps: steps);
}

WorkoutSession _strengthSession(DateTime startedAt) {
  return WorkoutSession(
    clientId: 'strength-${startedAt.microsecondsSinceEpoch}',
    startedAt: startedAt,
    finishedAt: startedAt.add(const Duration(minutes: 45)),
    exercises: const [],
    sets: const [],
  );
}

WorkoutSession _cardioSession(DateTime startedAt, {required int movingSeconds}) {
  return WorkoutSession(
    clientId: 'cardio-${startedAt.microsecondsSinceEpoch}',
    startedAt: startedAt,
    finishedAt: startedAt.add(const Duration(hours: 1)),
    exercises: const [],
    sets: const [],
    sessionKind: 'CARDIO',
    activityType: 'RUNNING',
    movingSeconds: movingSeconds,
  );
}

class _FakeSettingsController extends SettingsController {
  _FakeSettingsController(this._settings);
  final UserSettings _settings;

  @override
  Stream<UserSettings> build() => Stream.value(_settings);
}

class _FakeWorkoutSessionController extends WorkoutSessionController {
  _FakeWorkoutSessionController(this._sessions);
  final List<WorkoutSession> _sessions;

  @override
  Stream<List<WorkoutSession>> build() => Stream.value(_sessions);
}

ProviderContainer _buildContainer({
  required UserSettings settings,
  List<DailyMacros>? macros,
  List<DailyStepCount>? steps,
  Map<DateTime, double>? water,
  // Always overridden (not conditional like the three above): the workout
  // streak is unconditional (Q1: "Nem beállítás"), so streaksProvider reads
  // this on every call, not just when a goal is set.
  List<WorkoutSession> sessions = const [],
}) {
  return ProviderContainer(
    overrides: [
      settingsControllerProvider.overrideWith(() => _FakeSettingsController(settings)),
      if (macros != null) dailyMacrosProvider.overrideWith((ref) => Stream.value(macros)),
      if (steps != null) allStepCountsProvider.overrideWith((ref) => Stream.value(steps)),
      if (water != null)
        dailyWaterTotalsProvider.overrideWith((ref) => AsyncValue.data(water)),
      workoutSessionControllerProvider.overrideWith(() => _FakeWorkoutSessionController(sessions)),
    ],
  );
}

Future<void> _settle(ProviderContainer container) async {
  await container.listen(settingsControllerProvider.future, (previous, next) {}).read();
}

void main() {
  group('streaksProvider', () {
    test('no goals set -> only the always-present workout streak', () async {
      final container = _buildContainer(settings: const UserSettings.defaults());
      addTearDown(container.dispose);
      await _settle(container);
      await container.listen(workoutSessionControllerProvider.future, (previous, next) {}).read();

      final streak = container.read(streaksProvider).single;
      expect(streak.metric, StreakMetric.workout);
      expect(streak.current, 0);
    });

    test('calorie streak: consecutive under-budget days ending today extends the streak', () async {
      final container = _buildContainer(
        settings: const UserSettings.defaults().copyWith(dailyCalorieGoal: 2000),
        macros: [
          _macros(_day(3), calories: 1800),
          _macros(_day(2), calories: 1900),
          _macros(_day(1), calories: 1950),
          _macros(_day(0), calories: 1700),
        ],
      );
      addTearDown(container.dispose);
      await _settle(container);
      await container.listen(dailyMacrosProvider.future, (previous, next) {}).read();

      // The always-present workout streak is also in the list now — filter
      // to the one this test cares about rather than assuming `.single`.
      final streak =
          container.read(streaksProvider).firstWhere((s) => s.metric == StreakMetric.calories);
      expect(streak.current, 4);
      expect(streak.best, 4);
      expect(streak.todayMet, isTrue);
    });

    test('calorie streak: a day over budget does not count as met', () async {
      final container = _buildContainer(
        settings: const UserSettings.defaults().copyWith(dailyCalorieGoal: 2000),
        macros: [
          _macros(_day(1), calories: 2500), // over budget
          _macros(_day(0), calories: 1900),
        ],
      );
      addTearDown(container.dispose);
      await _settle(container);
      await container.listen(dailyMacrosProvider.future, (previous, next) {}).read();

      final streak =
          container.read(streaksProvider).firstWhere((s) => s.metric == StreakMetric.calories);
      expect(streak.current, 1); // only today, yesterday was over
      expect(streak.todayMet, isTrue);
    });

    test('calorie streak: an unlogged day is not free — no bucket means not met', () async {
      final container = _buildContainer(
        settings: const UserSettings.defaults().copyWith(dailyCalorieGoal: 2000),
        // Yesterday has no entry at all (nothing logged) even though 0 <= 2000.
        macros: [_macros(_day(0), calories: 1500)],
      );
      addTearDown(container.dispose);
      await _settle(container);
      await container.listen(dailyMacrosProvider.future, (previous, next) {}).read();

      final streak =
          container.read(streaksProvider).firstWhere((s) => s.metric == StreakMetric.calories);
      expect(streak.current, 1);
      expect(streak.best, 1);
    });

    test('steps streak: reads goal-met days from allStepCountsProvider', () async {
      final container = _buildContainer(
        settings: const UserSettings.defaults().copyWith(dailyStepGoal: 8000),
        steps: [
          _steps(_day(2), 9000),
          _steps(_day(1), 8500),
          _steps(_day(0), 6000), // today, not yet met
        ],
      );
      addTearDown(container.dispose);
      await _settle(container);
      await container.listen(allStepCountsProvider.future, (previous, next) {}).read();

      final streak =
          container.read(streaksProvider).firstWhere((s) => s.metric == StreakMetric.steps);
      expect(streak.current, 2); // today not yet met doesn't break it
      expect(streak.todayMet, isFalse);
    });

    test('water streak: reads goal-met days from dailyWaterTotalsProvider', () async {
      final container = _buildContainer(
        settings: const UserSettings.defaults().copyWith(dailyWaterGoalLiters: 2.0),
        water: {
          _day(1): 2.5,
          _day(0): 2.1,
        },
      );
      addTearDown(container.dispose);
      await _settle(container);

      final streak =
          container.read(streaksProvider).firstWhere((s) => s.metric == StreakMetric.water);
      expect(streak.current, 2);
      expect(streak.todayMet, isTrue);
    });

    test('emits one streak per goal that is set, in a stable order', () async {
      final container = _buildContainer(
        settings: const UserSettings.defaults().copyWith(
          dailyCalorieGoal: 2000,
          dailyStepGoal: 8000,
          dailyWaterGoalLiters: 2.0,
        ),
        macros: const [],
        steps: const [],
        water: const {},
      );
      addTearDown(container.dispose);
      await _settle(container);
      await container.listen(dailyMacrosProvider.future, (previous, next) {}).read();
      await container.listen(allStepCountsProvider.future, (previous, next) {}).read();

      final streaks = container.read(streaksProvider);
      expect(streaks.map((s) => s.metric).toList(), [
        StreakMetric.calories,
        StreakMetric.steps,
        StreakMetric.water,
        StreakMetric.workout,
      ]);
    });

    group('workout streak (docs/cardio/51-cardio-overview-plan.md §8 Q1)', () {
      test('a STRENGTH session always counts, regardless of length', () async {
        final container = _buildContainer(
          settings: const UserSettings.defaults(),
          sessions: [_strengthSession(_day(1)), _strengthSession(_day(0))],
        );
        addTearDown(container.dispose);
        await _settle(container);
        await container.listen(workoutSessionControllerProvider.future, (previous, next) {}).read();

        final streak = container.read(streaksProvider).single;
        expect(streak.metric, StreakMetric.workout);
        expect(streak.current, 2);
        expect(streak.todayMet, isTrue);
      });

      test('a cardio session below the 15-minute moving-time threshold does not count', () async {
        final container = _buildContainer(
          settings: const UserSettings.defaults(),
          sessions: [_cardioSession(_day(0), movingSeconds: 899)],
        );
        addTearDown(container.dispose);
        await _settle(container);
        await container.listen(workoutSessionControllerProvider.future, (previous, next) {}).read();

        final streak = container.read(streaksProvider).single;
        expect(streak.current, 0);
        expect(streak.todayMet, isFalse);
      });

      test('a cardio session at exactly the 15-minute threshold counts', () async {
        final container = _buildContainer(
          settings: const UserSettings.defaults(),
          sessions: [
            _cardioSession(_day(0), movingSeconds: workoutStreakMovingSecondsThreshold),
          ],
        );
        addTearDown(container.dispose);
        await _settle(container);
        await container.listen(workoutSessionControllerProvider.future, (previous, next) {}).read();

        final streak = container.read(streaksProvider).single;
        expect(streak.current, 1);
        expect(streak.todayMet, isTrue);
      });

      test('two sessions the same day: one unmet cardio + one strength still meets the day',
          () async {
        final container = _buildContainer(
          settings: const UserSettings.defaults(),
          sessions: [
            _cardioSession(_day(0).add(const Duration(hours: 7)), movingSeconds: 120),
            _strengthSession(_day(0).add(const Duration(hours: 18))),
          ],
        );
        addTearDown(container.dispose);
        await _settle(container);
        await container.listen(workoutSessionControllerProvider.future, (previous, next) {}).read();

        final streak = container.read(streaksProvider).single;
        expect(streak.current, 1);
        expect(streak.todayMet, isTrue);
      });

      test('the threshold is not configurable — it stays constant regardless of settings',
          () async {
        expect(workoutStreakMovingSecondsThreshold, 900); // 15 minutes
      });
    });
  });
}
