import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifey/features/nutrition/application/daily_macros_controller.dart';
import 'package:lifey/features/nutrition/domain/daily_macros.dart';
import 'package:lifey/features/settings/application/settings_controller.dart';
import 'package:lifey/features/settings/domain/user_settings.dart';
import 'package:lifey/features/steps/data/step_count_repository.dart';
import 'package:lifey/features/streaks/application/streaks_provider.dart';
import 'package:lifey/features/streaks/application/weekly_recap_provider.dart';
import 'package:lifey/features/streaks/domain/weekly_recap.dart';
import 'package:lifey/features/water/application/daily_water_totals_provider.dart';
import 'package:lifey/features/weight/application/weight_controller.dart';
import 'package:lifey/features/weight/domain/weight_entry.dart';
import 'package:lifey/features/workouts/application/workout_session_controller.dart';
import 'package:lifey/features/workouts/domain/workout_session.dart';

final _monday = DateTime(2026, 6, 1);
DateTime _weekDay(int offset) => DateTime(_monday.year, _monday.month, _monday.day + offset);

DailyMacros _macros(DateTime day, double calories) =>
    DailyMacros(day: day, calories: calories, protein: 0, carbs: 0, fat: 0);

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

class _FakeWeightController extends WeightController {
  _FakeWeightController(this._entries);
  final List<WeightEntry> _entries;

  @override
  Stream<List<WeightEntry>> build() => Stream.value(_entries);
}

ProviderContainer _buildContainer({
  UserSettings settings = const UserSettings.defaults(),
  List<DailyMacros> macros = const [],
  List<WorkoutSession> sessions = const [],
  List<WeightEntry> weights = const [],
  Map<DateTime, double> water = const {},
}) {
  return ProviderContainer(
    overrides: [
      settingsControllerProvider.overrideWith(() => _FakeSettingsController(settings)),
      dailyMacrosProvider.overrideWith((ref) => Stream.value(macros)),
      workoutSessionControllerProvider.overrideWith(
        () => _FakeWorkoutSessionController(sessions),
      ),
      weightControllerProvider.overrideWith(() => _FakeWeightController(weights)),
      dailyWaterTotalsProvider.overrideWith((ref) => AsyncValue.data(water)),
      allStepCountsProvider.overrideWith((ref) => Stream.value(const [])),
    ],
  );
}

Future<void> _settle(ProviderContainer container) async {
  await container.listen(settingsControllerProvider.future, (previous, next) {}).read();
  await container.listen(dailyMacrosProvider.future, (previous, next) {}).read();
  await container.listen(workoutSessionControllerProvider.future, (previous, next) {}).read();
  await container.listen(weightControllerProvider.future, (previous, next) {}).read();
  await container.listen(allStepCountsProvider.future, (previous, next) {}).read();
}

void main() {
  group('weeklyRecapProvider', () {
    test('combines every source into one WeeklyRecap for the requested week', () async {
      final container = _buildContainer(
        settings: const UserSettings.defaults().copyWith(dailyCalorieGoal: 2000),
        macros: [_macros(_weekDay(0), 1800), _macros(_weekDay(1), 2500)],
        sessions: [
          WorkoutSession(
            clientId: 's1',
            startedAt: _weekDay(2),
            finishedAt: _weekDay(2).add(const Duration(minutes: 40)),
            exercises: const [],
            sets: const [],
          ),
        ],
        weights: [WeightEntry(clientId: 'w1', date: _weekDay(3), weight: 80, recordedAt: _weekDay(3))],
      );
      addTearDown(container.dispose);
      await _settle(container);

      final recap = container.read(weeklyRecapProvider(_monday));
      expect(recap.weekStart, _monday);
      expect(recap.workoutsDone, 1);
      expect(recap.workoutMinutes, 40);
      expect(recap.loggedDayCount, 2);
      expect(recap.avgCalories, 2150);
      expect(recap.calorieGoalSet, isTrue);
      expect(recap.caloriesDaysMet, 1);
      expect(recap.weightEnd, 80);
    });

    test('is keyed by week — a different weekStart yields a different recap', () async {
      final container = _buildContainer(macros: [
        _macros(_weekDay(0), 1500),
        _macros(_weekDay(7), 3000), // the following week
      ]);
      addTearDown(container.dispose);
      await _settle(container);

      final thisWeek = container.read(weeklyRecapProvider(_monday));
      final nextWeek = container.read(weeklyRecapProvider(_weekDay(7)));

      expect(thisWeek.avgCalories, 1500);
      expect(nextWeek.avgCalories, 3000);
    });

    test('a missing (still-loading) source contributes empty data, not an error', () async {
      // Deliberately not awaiting settle for every source — the provider
      // must fall back to defaults rather than throwing while a stream is
      // still on its first (pending) emission when first read.
      final container = _buildContainer();
      addTearDown(container.dispose);

      final recap = container.read(weeklyRecapProvider(_monday));
      expect(recap.workoutsDone, 0);
      expect(recap.avgCalories, isNull);
    });

    test('carries through the live streaksProvider snapshot', () async {
      final container = _buildContainer(
        settings: const UserSettings.defaults().copyWith(dailyStepGoal: 8000),
      );
      addTearDown(container.dispose);
      await _settle(container);

      final recap = container.read(weeklyRecapProvider(_monday));
      expect(recap.streaks, container.read(streaksProvider));
    });
  });

  group('latestWeeklyRecapProvider', () {
    test('resolves to the last completed week, not the current one', () async {
      final container = _buildContainer(macros: [
        _macros(WeeklyRecap.lastCompletedWeekStart(), 1900),
      ]);
      addTearDown(container.dispose);
      await _settle(container);

      final recap = container.read(latestWeeklyRecapProvider);
      expect(recap.weekStart, WeeklyRecap.lastCompletedWeekStart());
      expect(recap.avgCalories, 1900);
    });
  });
}
