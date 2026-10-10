import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifey/features/nutrition/application/food_controller.dart';
import 'package:lifey/features/nutrition/application/meal_estimation_controller.dart';
import 'package:lifey/features/nutrition/domain/food.dart';
import 'package:lifey/features/nutrition/domain/meal_estimate.dart';
import 'package:lifey/features/nutrition/presentation/widgets/add_meal_entry_sheet.dart';
import 'package:lifey/features/nutrition/presentation/widgets/meal_estimate_sheet.dart';
import 'package:lifey/l10n/app_localizations.dart';

class _FakeEstimation extends MealEstimationController {
  _FakeEstimation(this._result);

  final MealEstimationState _result;
  int calls = 0;

  @override
  MealEstimationState build() => const MealEstimationIdle();

  @override
  Future<void> estimate(String imagePath) async {
    calls++;
    state = const MealEstimationLoading();
    await Future<void>.delayed(Duration.zero);
    state = _result;
  }
}

class _FakeFoods extends FoodController {
  final added = <Food>[];

  @override
  Stream<List<Food>> build() => Stream.value(const []);

  @override
  Future<Food> addFood({
    required String name,
    required double calories,
    required double protein,
    double? carbs,
    double? fat,
    double? fiber,
    double? sugar,
    List<FoodServing> servings = const [],
    bool favorite = false,
    String? barcode,
    bool hidden = false,
  }) async {
    final food = Food(
      clientId: 'food-${added.length}',
      name: name,
      caloriesPer100g: calories,
      proteinPer100g: protein,
      carbsPer100g: carbs,
      fatPer100g: fat,
      fiberPer100g: fiber,
      sugarPer100g: sugar,
      hidden: hidden,
    );
    added.add(food);
    return food;
  }
}

const _rice = EstimatedItem(
    name: 'Rice', grams: 200, calories: 260, protein: 5, carbs: 56, fat: 0.6,
    confidence: EstimateConfidence.high);
const _chicken = EstimatedItem(
    name: 'Chicken', grams: 150, calories: 248, protein: 46.5, carbs: 0, fat: 5.4,
    confidence: EstimateConfidence.low);

const _oats = EstimatedItem(
    name: 'Oats', grams: 250, calories: 190, protein: 7, carbs: 32, fat: 4,
    confidence: EstimateConfidence.medium, fiber: 5, sugar: 7.5);

void main() {
  late _FakeFoods foods;
  late _FakeEstimation estimation;
  List<MealEntryDraft>? popped;

  Future<void> open(WidgetTester tester, MealEstimationState result) async {
    foods = _FakeFoods();
    estimation = _FakeEstimation(result);
    popped = null;
    tester.view.physicalSize = const Size(800, 2000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(ProviderScope(
      overrides: [
        mealEstimationControllerProvider.overrideWith(() => estimation),
        foodControllerProvider.overrideWith(() => foods),
      ],
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () async {
                popped = await showModalBottomSheet<List<MealEntryDraft>>(
                  context: context,
                  isScrollControlled: true,
                  builder: (_) => const MealEstimateSheet(imagePath: 'missing.jpg'),
                );
              },
              child: const Text('open'),
            ),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  testWidgets('adds every reviewed item as a hidden food with its portion', (tester) async {
    await open(tester, const MealEstimationDone(MealEstimate(items: [_rice, _chicken])));

    expect(find.text('Rough guess'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Add 2 items'));
    await tester.pumpAndSettle();

    expect(popped, hasLength(2));
    expect(popped![0].grams, 200);
    expect(popped![1].grams, 150);
    expect(foods.added.every((f) => f.hidden), isTrue);
    // Per-100 g back-calculated from the portion: 260 kcal / 200 g.
    expect(foods.added[0].caloriesPer100g, closeTo(130, 0.001));
    expect(foods.added[1].proteinPer100g, closeTo(31, 0.001));
  });

  testWidgets('changing the portion rescales calories and macros', (tester) async {
    await open(tester, const MealEstimationDone(MealEstimate(items: [_rice])));

    await tester.enterText(find.widgetWithText(TextFormField, '200'), '100');
    await tester.pump();

    expect(find.widgetWithText(TextFormField, '130'), findsOneWidget);
    expect(find.widgetWithText(TextFormField, '28'), findsOneWidget);
    expect(find.widgetWithText(TextFormField, '0.3'), findsOneWidget);
  });

  testWidgets('the estimated fibre and sugar are reviewable, rescale with the portion and are saved per 100 g (LIF-152)',
      (tester) async {
    await open(tester, const MealEstimationDone(MealEstimate(items: [_oats])));

    expect(tester.widget<TextFormField>(find.byKey(const Key('estimate-fiber'))).controller!.text, '5');
    expect(tester.widget<TextFormField>(find.byKey(const Key('estimate-sugar'))).controller!.text, '7.5');

    // Half the portion: half the fibre and sugar.
    await tester.enterText(find.widgetWithText(TextFormField, '250'), '125');
    await tester.pump();
    expect(tester.widget<TextFormField>(find.byKey(const Key('estimate-fiber'))).controller!.text, '2.5');
    expect(tester.widget<TextFormField>(find.byKey(const Key('estimate-sugar'))).controller!.text, '3.8');

    // A correction by the user is what is saved: 3 g fibre in 125 g = 2.4 g per 100 g.
    await tester.enterText(find.byKey(const Key('estimate-fiber')), '3');
    await tester.tap(find.widgetWithText(FilledButton, 'Add 1 item'));
    await tester.pumpAndSettle();

    expect(foods.added.single.fiberPer100g, closeTo(2.4, 0.001));
    expect(foods.added.single.sugarPer100g, closeTo(3.8 / 125 * 100, 0.001));
  });

  testWidgets('no estimate stays unknown: the saved food has no fibre or sugar, and the fields may stay empty',
      (tester) async {
    await open(tester, const MealEstimationDone(MealEstimate(items: [_rice])));

    expect(tester.widget<TextFormField>(find.byKey(const Key('estimate-fiber'))).controller!.text, isEmpty);
    await tester.tap(find.widgetWithText(FilledButton, 'Add 1 item'));
    await tester.pumpAndSettle();

    expect(foods.added.single.fiberPer100g, isNull);
    expect(foods.added.single.sugarPer100g, isNull);
  });

  testWidgets('a negative fibre figure is refused', (tester) async {
    await open(tester, const MealEstimationDone(MealEstimate(items: [_oats])));

    await tester.enterText(find.byKey(const Key('estimate-fiber')), '-1');
    await tester.tap(find.widgetWithText(FilledButton, 'Add 1 item'));
    await tester.pumpAndSettle();

    expect(foods.added, isEmpty);
    expect(popped, isNull);
  });

  testWidgets('a removed item is not added', (tester) async {
    await open(tester, const MealEstimationDone(MealEstimate(items: [_rice, _chicken])));

    await tester.tap(find.byTooltip('Remove item').first);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Add 1 item'));
    await tester.pumpAndSettle();

    expect(popped!.single.food.name, 'Chicken');
  });

  testWidgets('a photo with no food says so and offers nothing to add', (tester) async {
    await open(tester, const MealEstimationDone(MealEstimate(items: [], notes: 'A cat.')));

    expect(find.textContaining('No food recognized'), findsOneWidget);
    expect(find.text('A cat.'), findsOneWidget);
    expect(find.byType(FilledButton), findsNothing);
  });

  testWidgets('a failed estimate can be retried', (tester) async {
    await open(tester, const MealEstimationFailed());

    expect(find.textContaining('No credit was used'), findsOneWidget);
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();

    expect(estimation.calls, 2);
  });

  testWidgets('out of credits closes the sheet with nothing added', (tester) async {
    await open(tester, const MealEstimationCreditsExhausted());

    expect(find.byType(MealEstimateSheet), findsNothing);
    expect(popped, isNull);
  });
}
