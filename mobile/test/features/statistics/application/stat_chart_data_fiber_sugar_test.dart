import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifey/core/entitlements/entitlement_providers.dart';
import 'package:lifey/features/nutrition/application/meal_controller.dart';
import 'package:lifey/features/nutrition/domain/meal.dart';
import 'package:lifey/features/statistics/application/stat_chart_data.dart';
import 'package:lifey/features/statistics/application/stat_metric_controller.dart';
import 'package:lifey/features/statistics/application/stats_range_controller.dart';
import 'package:lifey/features/statistics/domain/metric_summary.dart';
import 'package:lifey/features/statistics/domain/stat_metric.dart';
import 'package:lifey/features/steps/data/step_count_repository.dart';
import 'package:lifey/features/water/data/water_entry_repository.dart';
import 'package:lifey/features/weight/application/weight_controller.dart';
import 'package:lifey/features/weight/domain/weight_entry.dart';
import 'package:lifey/features/workouts/application/workout_session_controller.dart';
import 'package:lifey/features/workouts/domain/workout_session.dart';
import 'package:lifey/shared/widgets/charts/stats_range.dart';

/// Fibre and sugar as chart metrics (LIF-151): a day is charted only when every food eaten that day has a figure - an unknown
/// is not 0, so a day missing some would read as a low day. Such days are left out and counted instead.

final _now = DateTime.now();
DateTime _day(int offset) => DateTime(_now.year, _now.month, _now.day - offset);

MealEntry _entry({double? fiber, double? sugar}) => MealEntry(
      foodClientId: 'f',
      foodName: 'Food',
      quantityInGrams: 100,
      calories: 100,
      protein: 1,
      carbs: 1,
      fat: 1,
      fiber: fiber,
      sugar: sugar,
    );

var _n = 0;
Meal _meal(int daysAgo, List<MealEntry> entries) => Meal(
      clientId: 'm${_n++}',
      dateTime: _day(daysAgo).add(const Duration(hours: 12)),
      mealType: MealType.lunch,
      entries: entries,
    );

class _FakeMeals extends MealController {
  _FakeMeals(this._meals);
  final List<Meal> _meals;

  @override
  Stream<List<Meal>> build() => Stream.value(_meals);
}

ProviderContainer _container(List<Meal> meals) => ProviderContainer(overrides: [
      mealControllerProvider.overrideWith(() => _FakeMeals(meals)),
      workoutSessionControllerProvider.overrideWith(_NoSessions.new),
      weightControllerProvider.overrideWith(_NoWeights.new),
      allWaterEntriesProvider.overrideWith((ref) => Stream.value(const [])),
      allStepCountsProvider.overrideWith((ref) => Stream.value(const [])),
      historyCutoffProvider.overrideWithValue(null),
    ]);

class _NoSessions extends WorkoutSessionController {
  @override
  Stream<List<WorkoutSession>> build() => Stream.value(const []);
}

class _NoWeights extends WeightController {
  @override
  Stream<List<WeightEntry>> build() => Stream.value(const []);
}

Future<StatSeries> _series(ProviderContainer c, StatMetric metric) async {
  c.read(statMetricControllerProvider.notifier).select(metric);
  c.read(statsRangeControllerProvider.notifier).select(StatsRange.month);
  await c.listen(mealControllerProvider.future, (previous, next) {}).read();
  return c.read(statCurrentSeriesProvider).value!;
}

void main() {
  test('a day is a point when every food has a figure: the sum of the day', () async {
    final c = _container([
      _meal(2, [_entry(fiber: 5, sugar: 10), _entry(fiber: 2.5, sugar: 1)]),
      _meal(2, [_entry(fiber: 1, sugar: 4)]),
      _meal(1, [_entry(fiber: 3, sugar: 0)]),
    ]);
    addTearDown(c.dispose);

    final fiber = await _series(c, StatMetric.fiber);
    expect([for (final p in fiber.points) (p.date, p.value)], [(_day(2), 8.5), (_day(1), 3.0)]);
    expect(fiber.incompleteDays, isEmpty);

    final sugar = await _series(c, StatMetric.sugar);
    expect([for (final p in sugar.points) (p.date, p.value)], [(_day(2), 15.0), (_day(1), 0.0)]);
  });

  test('a day with a food that has no figure is left out - not drawn as a low day - and counted', () async {
    final c = _container([
      _meal(3, [_entry(fiber: 6, sugar: 2)]),
      // Some of the day's foods have a figure, one has none: 4 g would be a lower bound, not the day's fibre.
      _meal(2, [_entry(fiber: 4, sugar: 3), _entry()]),
      // No food at all has a figure.
      _meal(1, [_entry()]),
    ]);
    addTearDown(c.dispose);

    final fiber = await _series(c, StatMetric.fiber);
    expect([for (final p in fiber.points) (p.date, p.value)], [(_day(3), 6.0)]);
    expect(fiber.incompleteDays, {_day(2), _day(1)});
  });

  test('fibre and sugar are judged separately: a food with only one of them', () async {
    final c = _container([
      _meal(1, [_entry(fiber: 2), _entry(fiber: 3, sugar: 8)]),
    ]);
    addTearDown(c.dispose);

    final fiber = await _series(c, StatMetric.fiber);
    expect(fiber.points.single.value, 5);
    expect(fiber.incompleteDays, isEmpty);

    final sugar = await _series(c, StatMetric.sugar);
    expect(sugar.points, isEmpty);
    expect(sugar.incompleteDays, {_day(1)});
  });

  test('the range cuts the left-out days too', () async {
    final c = _container([
      _meal(60, [_entry()]),
      _meal(1, [_entry(fiber: 1), _entry()]),
    ]);
    addTearDown(c.dispose);

    final fiber = await _series(c, StatMetric.fiber);
    expect(fiber.incompleteDays, {_day(1)});
  });

  test('the metric is offered once some food eaten has that figure, not before', () async {
    final none = _container([_meal(1, [_entry()])]);
    addTearDown(none.dispose);
    await none.listen(mealControllerProvider.future, (previous, next) {}).read();
    expect(none.read(availableStatMetricsProvider), isNot(contains(StatMetric.fiber)));
    expect(none.read(availableStatMetricsProvider), isNot(contains(StatMetric.sugar)));

    final some = _container([_meal(1, [_entry(fiber: 1)])]);
    addTearDown(some.dispose);
    await some.listen(mealControllerProvider.future, (previous, next) {}).read();
    expect(some.read(availableStatMetricsProvider), contains(StatMetric.fiber));
    expect(some.read(availableStatMetricsProvider), isNot(contains(StatMetric.sugar)));
  });
}
