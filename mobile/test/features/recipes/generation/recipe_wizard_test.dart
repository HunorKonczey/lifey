import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifey/features/recipes/generation/domain/recipe_wizard.dart';
import 'package:lifey/features/recipes/generation/presentation/recipe_wizard_sheet.dart';
import 'package:lifey/l10n/app_localizations.dart';

/// The wizard (docs/23-ai-calorie-estimation-plan.md Phase 2): five steps, the
/// meat one skipped in both directions for a meatless diet, and nothing sent
/// until the last press.

Future<RecipeWizardAnswers?> _openWizard(WidgetTester tester) async {
  RecipeWizardAnswers? result;
  await tester.pumpWidget(MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Builder(
      builder: (context) => Scaffold(
        body: TextButton(
          onPressed: () async {
            result = await showModalBottomSheet<RecipeWizardAnswers>(
              context: context,
              isScrollControlled: true,
              builder: (_) => const RecipeWizardSheet(),
            );
          },
          child: const Text('open'),
        ),
      ),
    ),
  ));
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
  return result;
}

Future<void> _choose(WidgetTester tester, String label) async {
  await tester.tap(find.widgetWithText(ChoiceChip, label));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('walks all five steps and pops the answers', (tester) async {
    await _openWizard(tester);

    expect(find.text('What should it be made of?'), findsOneWidget);
    await _choose(tester, 'With meat');
    expect(find.text('Which meal is it for?'), findsOneWidget);
    await _choose(tester, 'Dinner');
    expect(find.text('How many calories per serving?'), findsOneWidget);
    await _choose(tester, '500–700');
    expect(find.text('Which meat or fish?'), findsOneWidget);
    await _choose(tester, 'Chicken');

    expect(find.text('Anything else?'), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'no mushrooms');
    await tester.tap(find.widgetWithText(FilledButton, 'Generate recipe'));
    await tester.pumpAndSettle();

    expect(find.byType(RecipeWizardSheet), findsNothing);
  });

  testWidgets('skips the meat step for a vegan diet, forwards and back', (tester) async {
    await _openWizard(tester);

    await _choose(tester, 'Vegan');
    await _choose(tester, 'Lunch');
    await _choose(tester, 'Under 300');

    expect(find.text('Anything else?'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.arrow_back));
    await tester.pumpAndSettle();

    expect(find.text('How many calories per serving?'), findsOneWidget);
  });

  testWidgets('the first back press closes the wizard', (tester) async {
    await _openWizard(tester);

    await tester.tap(find.byIcon(Icons.close));
    await tester.pumpAndSettle();

    expect(find.byType(RecipeWizardSheet), findsNothing);
  });

  group('answers', () {
    test('serialize only what was answered', () {
      const answers = RecipeWizardAnswers(
        dietType: RecipeDietType.fish,
        mealType: RecipeMealType.breakfast,
        calorieBand: RecipeCalorieBand.from300To500,
      );

      expect(answers.toJson(), {
        'dietType': 'FISH',
        'mealType': 'BREAKFAST',
        'calorieBand': 'FROM_300_TO_500',
      });
    });

    test('a meatless diet drops a meat chosen earlier', () {
      const answers = RecipeWizardAnswers(
        dietType: RecipeDietType.meat,
        mealType: RecipeMealType.dinner,
        calorieBand: RecipeCalorieBand.over700,
        meatType: RecipeMeatType.beef,
      );

      final vegan = answers.copyWith(dietType: RecipeDietType.vegan);

      expect(vegan.meatType, isNull);
      expect(vegan.toJson().containsKey('meatType'), isFalse);
    });

    test('blank extras are left out entirely', () {
      const answers = RecipeWizardAnswers(
        dietType: RecipeDietType.vegan,
        mealType: RecipeMealType.snack,
        calorieBand: RecipeCalorieBand.under300,
        extraRequest: '   ',
      );

      expect(answers.toJson().containsKey('extraRequest'), isFalse);
    });
  });
}
