import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifey/features/nutrition/domain/meal.dart' show MealType;
import 'package:lifey/features/trainer/client_detail/data/client_detail_repository.dart';
import 'package:lifey/features/trainer/client_detail/domain/client_data.dart';

class _FakeAdapter implements HttpClientAdapter {
  final List<String> paths = [];
  final List<Map<String, dynamic>> queries = [];
  Object body = <Object>[];

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    paths.add(options.path);
    queries.add(Map<String, dynamic>.from(options.queryParameters));
    return ResponseBody.fromString(
      jsonEncode(body),
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }
}

void main() {
  late Dio dio;
  late _FakeAdapter adapter;
  late ClientDetailRepository repo;

  setUp(() {
    dio = Dio(BaseOptions(baseUrl: 'http://test'));
    adapter = _FakeAdapter();
    dio.httpClientAdapter = adapter;
    repo = ClientDetailRepository(dio);
  });

  group('statistics', () {
    test('asks for the requested period and reads the totals', () async {
      adapter.body = {
        'totalCalories': 14350.5,
        'totalProtein': 700.0,
        'totalCarbs': 1200.0,
        'totalFat': 400.0,
        'workoutCount': 4,
        'latestWeight': 71.2,
      };

      final stats =
          await repo.fetchStatistics(9, ClientStatisticsPeriod.weekly);

      expect(adapter.paths.single, '/trainer/clients/9/statistics/weekly');
      expect(stats.totalCalories, 14350.5);
      expect(stats.workoutCount, 4);
      expect(stats.latestWeight, 71.2);
    });

    test('sends no date, so mobile and web read the same server day', () async {
      adapter.body = <String, dynamic>{};

      await repo.fetchStatistics(9, ClientStatisticsPeriod.daily);

      // The endpoint anchors "daily" to the server's current date when no
      // `date` is given, and the web admin sends none either. Sending the
      // device's local date instead would put a trainer abroad on a
      // different day from the same figure on their laptop — the two
      // surfaces have to agree, and the server is the one thing they share.
      expect(adapter.queries.single.containsKey('date'), isFalse);
    });
  });

  group('steps and weights', () {
    test('bounds the window with an inclusive yyyy-MM-dd `from`', () async {
      adapter.body = <Object>[];
      final from = DateTime(2026, 7, 1);

      await repo.fetchSteps(3, from: from, to: DateTime(2026, 7, 30));

      expect(adapter.paths.single, '/trainer/clients/3/steps');
      expect(adapter.queries.single['from'], '2026-07-01');
      expect(adapter.queries.single['to'], '2026-07-30');
    });

    test('omits bounds that were not given', () async {
      adapter.body = <Object>[];

      await repo.fetchWeights(3);

      expect(adapter.queries.single, isEmpty);
    });

    test('pads single-digit months and days', () {
      expect(ClientDetailRepository.formatDate(DateTime(2026, 1, 5)), '2026-01-05');
    });

    test('reads a bare LocalDate as UTC midnight', () async {
      adapter.body = [
        {'id': 1, 'date': '2026-07-08', 'steps': 8214},
      ];

      final days = await repo.fetchSteps(3);

      expect(days.single.date, DateTime.utc(2026, 7, 8));
      expect(days.single.steps, 8214);
    });

    test('reads weigh-ins', () async {
      adapter.body = [
        {'id': 1, 'date': '2026-07-08', 'weight': 71.4},
      ];

      final weights = await repo.fetchWeights(3);

      expect(weights.single.weight, 71.4);
    });
  });

  group('meals', () {
    test('asks for exactly one day and totals the entries', () async {
      adapter.body = [
        {
          'id': 11,
          'dateTime': '2026-07-08T07:30:00Z',
          'mealType': 'BREAKFAST',
          'name': 'Oats',
          'entries': [
            {
              'foodName': 'Oats',
              'quantityInGrams': 80.0,
              'calories': 300.0,
              'protein': 10.0,
              'carbs': 50.0,
              'fat': 6.0,
            },
            {
              'foodName': 'Milk',
              'quantityInGrams': 200.0,
              'calories': 90.0,
              'protein': 7.0,
              'carbs': 10.0,
              'fat': 3.0,
            },
          ],
        },
      ];

      final meals = await repo.fetchMealsForDay(4, DateTime(2026, 7, 8));

      expect(adapter.paths.single, '/trainer/clients/4/meals');
      expect(adapter.queries.single['from'], '2026-07-08');
      expect(adapter.queries.single['to'], '2026-07-08');
      final meal = meals.single;
      expect(meal.mealType, MealType.breakfast);
      expect(meal.calories, 390.0);
      expect(meal.protein, 17.0);
      expect(meal.entries.length, 2);
    });

    test('an unknown meal type falls back to snack rather than throwing', () async {
      adapter.body = [
        {
          'id': 12,
          'dateTime': '2026-07-08T21:00:00Z',
          'mealType': 'SECOND_BREAKFAST',
          'name': '',
          'entries': <Object>[],
        },
      ];

      final meals = await repo.fetchMealsForDay(4, DateTime(2026, 7, 8));

      expect(meals.single.mealType, MealType.snack);
    });
  });

  group('nutrition goals', () {
    test('nulls stay null — "no goal" is not zero', () async {
      adapter.body = {
        'dailyCalorieGoal': 2200.0,
        'dailyProteinGoal': null,
        'dailyCarbsGoal': null,
        'dailyFatGoal': null,
      };

      final goals = await repo.fetchNutritionGoals(4);

      expect(goals.dailyCalorieGoal, 2200.0);
      expect(goals.dailyProteinGoal, isNull);
      expect(goals.isEmpty, isFalse);
    });

    test('an all-null response reads as "no goals set"', () async {
      adapter.body = <String, dynamic>{};

      expect((await repo.fetchNutritionGoals(4)).isEmpty, isTrue);
    });
  });
}
