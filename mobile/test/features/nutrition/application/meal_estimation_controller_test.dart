import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifey/core/entitlements/entitlement_repository.dart';
import 'package:lifey/features/nutrition/application/meal_estimation_controller.dart';
import 'package:lifey/features/nutrition/data/meal_estimation_repository.dart';
import 'package:lifey/features/nutrition/domain/meal_estimate.dart';

class _FakeRepo implements MealEstimationRepository {
  _FakeRepo(this._answer);

  final Future<MealEstimate> Function() _answer;

  @override
  Future<MealEstimate> estimate(String imagePath) => _answer();
}

class _FakeEntitlements implements EntitlementRepository {
  int refreshes = 0;

  @override
  Future<bool> refresh() async {
    refreshes++;
    return true;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

DioException _status(int code) {
  final options = RequestOptions(path: '/meals/estimate');
  return DioException(
    requestOptions: options,
    type: DioExceptionType.badResponse,
    response: Response(requestOptions: options, statusCode: code),
  );
}

void main() {
  late _FakeEntitlements entitlements;

  ProviderContainer containerWith(Future<MealEstimate> Function() answer) {
    entitlements = _FakeEntitlements();
    final container = ProviderContainer(overrides: [
      mealEstimationRepositoryProvider.overrideWithValue(_FakeRepo(answer)),
      entitlementRepositoryProvider.overrideWithValue(entitlements),
    ]);
    addTearDown(container.dispose);
    return container;
  }

  test('a successful estimate is exposed and refreshes the credit count', () async {
    const estimate = MealEstimate(items: [
      EstimatedItem(
          name: 'Rice', grams: 180, calories: 234, protein: 4.3, carbs: 50.8, fat: 0.5,
          confidence: EstimateConfidence.high),
    ]);
    final container = containerWith(() async => estimate);

    await container.read(mealEstimationControllerProvider.notifier).estimate('meal.jpg');

    final state = container.read(mealEstimationControllerProvider);
    expect(state, isA<MealEstimationDone>());
    expect((state as MealEstimationDone).estimate, same(estimate));
    expect(entitlements.refreshes, 1);
  });

  test('402 means the monthly AI credits are used up', () async {
    final container = containerWith(() => Future.error(_status(402)));

    await container.read(mealEstimationControllerProvider.notifier).estimate('meal.jpg');

    expect(container.read(mealEstimationControllerProvider), isA<MealEstimationCreditsExhausted>());
    expect(entitlements.refreshes, 0);
  });

  test('502 from the model is a retryable failure', () async {
    final container = containerWith(() => Future.error(_status(502)));

    await container.read(mealEstimationControllerProvider.notifier).estimate('meal.jpg');

    expect(container.read(mealEstimationControllerProvider), isA<MealEstimationFailed>());
  });

  test('no connection is reported as offline', () async {
    final container = containerWith(() => Future.error(DioException(
          requestOptions: RequestOptions(path: '/meals/estimate'),
          type: DioExceptionType.connectionError,
        )));

    await container.read(mealEstimationControllerProvider.notifier).estimate('meal.jpg');

    expect(container.read(mealEstimationControllerProvider), isA<MealEstimationOffline>());
  });

  test('parses the backend payload, defaulting an unknown confidence to low', () {
    final estimate = MealEstimate.fromJson({
      'items': [
        {
          'name': 'Grilled chicken breast',
          'estimatedGrams': 150,
          'calories': 248,
          'proteinGrams': 46.5,
          'carbsGrams': 0,
          'fatGrams': 5.4,
          'confidence': 'SOMETHING_NEW',
        },
      ],
      'notes': null,
    });

    final item = estimate.items.single;
    expect(item.grams, 150.0);
    expect(item.protein, 46.5);
    expect(item.confidence, EstimateConfidence.low);
    expect(estimate.notes, isNull);
  });
}
