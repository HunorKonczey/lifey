import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifey/features/nutrition/domain/meal.dart' show MealType;
import 'package:lifey/features/trainer/client_detail/data/client_detail_repository.dart';
import 'package:lifey/features/trainer/client_detail/domain/client_data.dart';

class _FakeAdapter implements HttpClientAdapter {
  final List<String> methods = [];
  final List<String> paths = [];
  final List<Map<String, dynamic>> queries = [];
  final List<Object?> bodies = [];
  Object body = <Object>[];

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    methods.add(options.method);
    paths.add(options.path);
    queries.add(Map<String, dynamic>.from(options.queryParameters));
    bodies.add(options.data);
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

  group('workout sessions', () {
    test('asks for one page and reads the Spring page envelope', () async {
      adapter.body = {
        'content': [
          {
            'id': 31,
            'startedAt': '2026-07-08T17:00:00Z',
            'finishedAt': '2026-07-08T18:05:00Z',
            'templateName': 'Push day',
            'sessionKind': 'STRENGTH',
            'exercises': [
              {'exerciseId': 1, 'exerciseName': 'Bench press', 'targetSets': 3},
            ],
            'sets': [
              {'exerciseId': 1, 'exerciseName': 'Bench press', 'reps': 10, 'weight': 60.0},
              {'exerciseId': 1, 'exerciseName': 'Bench press', 'reps': 8, 'weight': 65.0},
            ],
            'rpe': 8,
            'feedbackNote': 'Tough one',
            'trainerComment': null,
            'trainerCommentAt': null,
          },
        ],
        'last': false,
      };

      final page = await repo.fetchWorkoutSessions(9, page: 2, size: 20);

      expect(adapter.paths.single, '/trainer/clients/9/workout-sessions');
      expect(adapter.queries.single['page'], 2);
      expect(adapter.queries.single['size'], 20);
      expect(page.isLast, isFalse);

      final session = page.sessions.single;
      expect(session.templateName, 'Push day');
      expect(session.duration, const Duration(hours: 1, minutes: 5));
      expect(session.exerciseCount, 1);
      expect(session.rpe, 8);
      expect(session.feedbackNote, 'Tough one');
      expect(session.hasTrainerComment, isFalse);
      expect(session.setsOf(1).length, 2);
    });

    test('a cardio session carries no sets, and its distance comes from cardio',
        () async {
      adapter.body = {
        'content': [
          {
            'id': 32,
            'startedAt': '2026-07-09T06:00:00Z',
            'finishedAt': '2026-07-09T06:40:00Z',
            'sessionKind': 'CARDIO',
            'activityType': 'RUNNING',
            'movingSeconds': 2280,
            'exercises': <Object>[],
            'sets': <Object>[],
            'cardio': {'distanceMeters': 7400.0},
          },
        ],
        'last': true,
      };

      final session = (await repo.fetchWorkoutSessions(9)).sessions.single;

      expect(session.isCardio, isTrue);
      expect(session.activityType, 'RUNNING');
      expect(session.distanceMeters, 7400.0);
      expect(session.sets, isEmpty);
    });

    test('an empty envelope reads as a last page with nothing in it', () async {
      adapter.body = <String, dynamic>{};

      final page = await repo.fetchWorkoutSessions(9);

      expect(page.sessions, isEmpty);
      expect(page.isLast, isTrue);
    });
  });

  group('session comment', () {
    test('PUTs the comment and returns the session the server stored',
        () async {
      adapter.body = {
        'id': 31,
        'startedAt': '2026-07-08T17:00:00Z',
        'sessionKind': 'STRENGTH',
        'exercises': <Object>[],
        'sets': <Object>[],
        'trainerComment': 'Nice pace',
        'trainerCommentAt': '2026-07-09T09:00:00Z',
      };

      final session = await repo.putSessionComment(9, 31, 'Nice pace');

      expect(adapter.methods.single, 'PUT');
      expect(
        adapter.paths.single,
        '/trainer/clients/9/workout-sessions/31/comment',
      );
      expect(adapter.bodies.single, {'comment': 'Nice pace'});
      expect(session.trainerComment, 'Nice pace');
      expect(session.trainerCommentAt, DateTime.utc(2026, 7, 9, 9));
    });

    test('DELETE clears it and returns the session without one', () async {
      adapter.body = {
        'id': 31,
        'startedAt': '2026-07-08T17:00:00Z',
        'sessionKind': 'STRENGTH',
        'exercises': <Object>[],
        'sets': <Object>[],
        'trainerComment': null,
        'trainerCommentAt': null,
      };

      final session = await repo.deleteSessionComment(9, 31);

      expect(adapter.methods.single, 'DELETE');
      expect(session.hasTrainerComment, isFalse);
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
