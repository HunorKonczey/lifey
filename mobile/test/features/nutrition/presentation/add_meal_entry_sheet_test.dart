import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifey/features/nutrition/application/food_controller.dart';
import 'package:lifey/features/nutrition/application/food_usage_provider.dart';
import 'package:lifey/features/nutrition/domain/food.dart';
import 'package:lifey/features/nutrition/domain/food_usage.dart';
import 'package:lifey/features/nutrition/presentation/widgets/add_meal_entry_sheet.dart';
import 'package:lifey/features/nutrition/application/selected_meal_day_provider.dart';
import 'package:lifey/features/nutrition/domain/meal.dart';
import 'package:lifey/features/settings/application/settings_controller.dart';
import 'package:lifey/features/settings/domain/user_settings.dart';
import 'package:lifey/l10n/app_localizations.dart';

class _NoGoal extends SettingsController {
  @override
  Stream<UserSettings> build() => Stream.value(const UserSettings.defaults());
}

Food _food(String id, String name) =>
    Food(clientId: id, name: name, caloriesPer100g: 100, proteinPer100g: 10);

final _foods = [
  _food('bread', 'Bread'),
  _food('chicken', 'Chicken'),
  _food('rice', 'Rice'),
];

final _usage = {
  'chicken': FoodUsage(lastUsedAt: DateTime(2026, 7, 9), useCount: 4, lastGrams: 150),
  'rice': FoodUsage(lastUsedAt: DateTime(2026, 7, 8), useCount: 2, lastGrams: 80),
};

Future<void> _pumpSheet(
  WidgetTester tester, {
  Map<String, FoodUsage> usage = const {},
  Stream<Map<String, FoodUsage>>? usageStream,
  Food? initialFood,
  double? initialGrams,
  Food? preselectedFood,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        foodSearchProvider.overrideWith((ref) => Stream.value(_foods)),
        foodUsageProvider.overrideWith((ref) => usageStream ?? Stream.value(usage)),
        settingsControllerProvider.overrideWith(_NoGoal.new),
        mealsOnDayProvider.overrideWith((ref, day) => Stream.value(const <Meal>[])),
      ],
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: AddMealEntrySheet(
            initialFood: initialFood,
            initialGrams: initialGrams,
            preselectedFood: preselectedFood,
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

/// The recent-foods quick-pick row is the only horizontal list in the sheet
/// (the autocomplete's options overlay is a vertical ListView).
Finder _chipsList() => find.byWidgetPredicate(
    (w) => w is ListView && w.scrollDirection == Axis.horizontal);

Finder _chip(String name) =>
    find.descendant(of: _chipsList(), matching: find.text(name));

Finder _gramsField() => find.byKey(const Key('quantityField'));

bool _hasFocus(WidgetTester tester, Finder field) => tester
    .widget<EditableText>(find.descendant(of: field, matching: find.byType(EditableText)))
    .focusNode
    .hasFocus;

String _text(WidgetTester tester, Finder field) => tester
    .widget<EditableText>(find.descendant(of: field, matching: find.byType(EditableText)))
    .controller
    .text;

void main() {
  testWidgets('shows recent chips for previously logged foods only', (tester) async {
    await _pumpSheet(tester, usage: _usage);

    expect(_chip('Chicken'), findsOneWidget);
    expect(_chip('Rice'), findsOneWidget);
    expect(_chip('Bread'), findsNothing);
  });

  testWidgets('hides the recent row without any history', (tester) async {
    await _pumpSheet(tester);

    expect(_chipsList(), findsNothing);
  });

  testWidgets('hides the recent row in edit mode', (tester) async {
    await _pumpSheet(tester,
        usage: _usage, initialFood: _foods[1], initialGrams: 120);

    expect(_chipsList(), findsNothing);
  });

  testWidgets('tapping a chip picks the food and prefills last-used grams', (tester) async {
    await _pumpSheet(tester, usage: _usage);

    await tester.tap(_chip('Chicken'));
    await tester.pumpAndSettle();

    // Food name written into the autocomplete field + grams prefilled.
    expect(find.widgetWithText(TextFormField, 'Chicken'), findsOneWidget);
    expect(find.widgetWithText(TextFormField, '150'), findsOneWidget);
  });

  testWidgets('a second chip tap replaces a prefilled quantity', (tester) async {
    await _pumpSheet(tester, usage: _usage);

    await tester.tap(_chip('Chicken'));
    await tester.pumpAndSettle();
    await tester.tap(_chip('Rice'));
    await tester.pumpAndSettle();

    expect(find.widgetWithText(TextFormField, '80'), findsOneWidget);
    expect(find.widgetWithText(TextFormField, '150'), findsNothing);
  });

  testWidgets('never overwrites hand-typed grams', (tester) async {
    await _pumpSheet(tester, usage: _usage);

    await tester.tap(_chip('Chicken'));
    await tester.pumpAndSettle();
    await tester.enterText(_gramsField(), '75');
    await tester.tap(_chip('Rice'));
    await tester.pumpAndSettle();

    expect(_text(tester, _gramsField()), '75');
  });

  testWidgets('the quantity only appears once a food is picked', (tester) async {
    await _pumpSheet(tester, usage: _usage);

    expect(_gramsField(), findsNothing);
    await tester.tap(_chip('Chicken'));
    await tester.pumpAndSettle();
    expect(_gramsField(), findsOneWidget);
  });

  group('quantity hero', () {
    Future<void> pickChicken(WidgetTester tester) async {
      await _pumpSheet(tester, usage: _usage);
      await tester.tap(_chip('Chicken'));
      await tester.pumpAndSettle();
    }

    testWidgets('+ and − change the amount by 10 g and update the kcal preview', (tester) async {
      await pickChicken(tester); // 150 g of a 100 kcal / 100 g food
      expect(find.text('+150 kcal'), findsOneWidget);

      await tester.tap(find.byTooltip('More'));
      await tester.pump();
      expect(_text(tester, _gramsField()), '160');
      expect(find.text('+160 kcal'), findsOneWidget);

      await tester.tap(find.byTooltip('Less'));
      await tester.tap(find.byTooltip('Less'));
      await tester.pump();
      expect(_text(tester, _gramsField()), '140');
      expect(find.text('+140 kcal'), findsOneWidget);
    });

    testWidgets('− never goes below 1 g', (tester) async {
      await pickChicken(tester);
      await tester.enterText(_gramsField(), '5');

      await tester.tap(find.byTooltip('Less'));
      await tester.pump();

      expect(_text(tester, _gramsField()), '1');
    });

    testWidgets('quick chips: 100 g, 150 g and the last used amount, the matching one selected', (tester) async {
      await _pumpSheet(tester, usage: {
        'chicken': FoodUsage(lastUsedAt: DateTime(2026, 7, 9), useCount: 4, lastGrams: 163),
      });
      await tester.tap(_chip('Chicken'));
      await tester.pumpAndSettle();

      expect(find.widgetWithText(ChoiceChip, '100 g'), findsOneWidget);
      expect(find.widgetWithText(ChoiceChip, '150 g'), findsOneWidget);
      expect(tester.widget<ChoiceChip>(find.widgetWithText(ChoiceChip, '163 g')).selected, isTrue);

      await tester.tap(find.widgetWithText(ChoiceChip, '100 g'));
      await tester.pump();

      expect(_text(tester, _gramsField()), '100');
      expect(tester.widget<ChoiceChip>(find.widgetWithText(ChoiceChip, '100 g')).selected, isTrue);
    });

    testWidgets('the card names the food and its energy per 100 g', (tester) async {
      await pickChicken(tester);

      expect(find.text('per 100 g · 100 kcal'), findsOneWidget);
    });
  });

  group('pre-selected food (docs/75 §2.2)', () {
    final chicken = _foods[1];

    testWidgets('fills the food, prefills last-used grams and focuses quantity',
        (tester) async {
      await _pumpSheet(tester, usage: _usage, preselectedFood: chicken);

      expect(find.text('Add food'), findsOneWidget);
      expect(find.widgetWithText(TextFormField, 'Chicken'), findsOneWidget);
      expect(_text(tester, _gramsField()), '150');
      expect(_hasFocus(tester, _gramsField()), isTrue);
      expect(_chipsList(), findsNothing);
    });

    testWidgets('without usage the quantity is empty but still focused', (tester) async {
      await _pumpSheet(tester, preselectedFood: _foods[0]);

      expect(_text(tester, _gramsField()), isEmpty);
      expect(_hasFocus(tester, _gramsField()), isTrue);
    });

    testWidgets('prefills when usage arrives after the first frame', (tester) async {
      final usage = StreamController<Map<String, FoodUsage>>();
      addTearDown(usage.close);
      await _pumpSheet(tester, usageStream: usage.stream, preselectedFood: chicken);
      expect(_text(tester, _gramsField()), isEmpty);

      usage.add(_usage);
      await tester.pumpAndSettle();

      expect(_text(tester, _gramsField()), '150');
    });

    testWidgets('late usage never overwrites typed grams', (tester) async {
      final usage = StreamController<Map<String, FoodUsage>>();
      addTearDown(usage.close);
      await _pumpSheet(tester, usageStream: usage.stream, preselectedFood: chicken);

      await tester.enterText(_gramsField(), '250');
      usage.add(_usage);
      await tester.pumpAndSettle();

      expect(_text(tester, _gramsField()), '250');
    });

    testWidgets('later usage emissions do not re-apply the prefill', (tester) async {
      final usage = StreamController<Map<String, FoodUsage>>();
      addTearDown(usage.close);
      await _pumpSheet(tester, usageStream: usage.stream, preselectedFood: chicken);
      usage.add(_usage);
      await tester.pumpAndSettle();

      usage.add({
        'chicken': FoodUsage(lastUsedAt: DateTime(2026, 7, 10), useCount: 5, lastGrams: 300),
      });
      await tester.pumpAndSettle();

      expect(_text(tester, _gramsField()), '150');
    });

    testWidgets('clearing the food brings the recents row back', (tester) async {
      await _pumpSheet(tester, usage: _usage, preselectedFood: chicken);

      await tester.tap(find.byIcon(Icons.clear));
      await tester.pumpAndSettle();

      expect(find.widgetWithText(TextFormField, 'Chicken'), findsNothing);
      expect(_chipsList(), findsOneWidget);
    });

    testWidgets('Add pops a draft with the pre-selected food', (tester) async {
      MealEntryDraft? result;
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            foodSearchProvider.overrideWith((ref) => Stream.value(_foods)),
            foodUsageProvider.overrideWith((ref) => Stream.value(_usage)),
            settingsControllerProvider.overrideWith(_NoGoal.new),
            mealsOnDayProvider.overrideWith((ref, day) => Stream.value(const <Meal>[])),
          ],
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Builder(
              builder: (context) => TextButton(
                onPressed: () async {
                  result = await Navigator.of(context).push<MealEntryDraft>(
                    MaterialPageRoute(
                      builder: (_) => Scaffold(body: AddMealEntrySheet(preselectedFood: chicken)),
                    ),
                  );
                },
                child: const Text('open'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      await tester.enterText(_gramsField(), '200');
      await tester.tap(find.widgetWithText(FilledButton, 'Add to meal'));
      await tester.pumpAndSettle();

      expect(result?.food.clientId, 'chicken');
      expect(result?.grams, 200);
    });
  });
}
