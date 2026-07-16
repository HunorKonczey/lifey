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

class _FakeSettingsController extends SettingsController {
  _FakeSettingsController(this._settings);
  final UserSettings _settings;

  @override
  Stream<UserSettings> build() => Stream.value(_settings);
}

ProviderContainer _buildContainer({
  required UserSettings settings,
  List<DailyMacros>? macros,
  List<DailyStepCount>? steps,
  Map<DateTime, double>? water,
}) {
  return ProviderContainer(
    overrides: [
      settingsControllerProvider.overrideWith(() => _FakeSettingsController(settings)),
      if (macros != null) dailyMacrosProvider.overrideWith((ref) => Stream.value(macros)),
      if (steps != null) allStepCountsProvider.overrideWith((ref) => Stream.value(steps)),
      if (water != null)
        dailyWaterTotalsProvider.overrideWith((ref) => AsyncValue.data(water)),
    ],
  );
}

Future<void> _settle(ProviderContainer container) async {
  await container.listen(settingsControllerProvider.future, (previous, next) {}).read();
}

void main() {
  group('streaksProvider', () {
    test('no goals set -> empty list, no sources touched', () async {
      final container = _buildContainer(settings: const UserSettings.defaults());
      addTearDown(container.dispose);
      await _settle(container);

      expect(container.read(streaksProvider), isEmpty);
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

      final streak = container.read(streaksProvider).single;
      expect(streak.metric, StreakMetric.calories);
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

      final streak = container.read(streaksProvider).single;
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

      final streak = container.read(streaksProvider).single;
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

      final streak = container.read(streaksProvider).single;
      expect(streak.metric, StreakMetric.steps);
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

      final streak = container.read(streaksProvider).single;
      expect(streak.metric, StreakMetric.water);
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
      ]);
    });
  });
}
