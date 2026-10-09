import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifey/core/sync/connectivity_status_provider.dart';
import 'package:lifey/features/nutrition/application/food_controller.dart';
import 'package:lifey/features/nutrition/data/off_search_preferences.dart';
import 'package:lifey/features/nutrition/data/off_search_repository.dart';
import 'package:lifey/features/nutrition/domain/food.dart';
import 'package:lifey/features/nutrition/domain/off_search.dart';
import 'package:lifey/features/nutrition/presentation/widgets/add_food_sheet.dart';
import 'package:lifey/l10n/app_localizations.dart';

/// docs/84 follow-up: the OpenFoodFacts option in the plain create-food sheet — the checkbox under the name field, the list
/// of products to choose from, and picking one fills the form (nothing is saved until the user saves).

class _Call {
  _Call(this.text, this.lang) : completer = Completer<OffSearchResult>();
  final String text;
  final String lang;
  final Completer<OffSearchResult> completer;
}

class _FakeRepo implements OffSearchRepository {
  final calls = <_Call>[];

  @override
  Future<OffSearchResult> search(String text, String lang, {CancelToken? cancelToken}) {
    final call = _Call(text, lang);
    calls.add(call);
    return call.completer.future;
  }
}

class _FakePrefs implements OffSearchPreferences {
  bool stored = false;

  @override
  Future<bool> isEnabled() async => stored;

  @override
  Future<void> setEnabled(bool enabled) async => stored = enabled;
}

class _FakeFoodController extends FoodController {
  _FakeFoodController(this.saved);
  final List<Map<String, Object?>> saved;

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
    String? barcode,
    bool hidden = false,
  }) async {
    saved.add({
      'name': name,
      'calories': calories,
      'protein': protein,
      'carbs': carbs,
      'fat': fat,
      if (fiber != null) 'fiber': fiber,
      if (sugar != null) 'sugar': sugar,
      'barcode': barcode,
    });
    return Food(clientId: 'new', name: name, caloriesPer100g: calories, proteinPer100g: protein);
  }
}

const _csirke = OffSearchItem(
  barcode: '4056489827702',
  name: 'Csirkemell',
  brand: 'Pikok',
  caloriesPer100g: 110,
  proteinPer100g: 14,
  carbsPer100g: 2.4,
  fatPer100g: 4.9,
);
const _muesli = OffSearchItem(
  barcode: '5900000000017',
  name: 'Muesli',
  brand: 'Acme',
  caloriesPer100g: 360,
  proteinPer100g: 9,
  carbsPer100g: 62,
  fatPer100g: 6,
  fiberPer100g: 8.5,
  sugarPer100g: 14,
);
const _noMacros = OffSearchItem(barcode: '5997000000001', name: 'Túró Rudi', caloriesPer100g: 400, proteinPer100g: 11);

OffSearchResult _answer(List<OffSearchItem> items, {OffSearchStatus status = OffSearchStatus.ok, bool fellBack = false}) =>
    OffSearchResult(status: status, language: 'en', fellBackToEnglish: fellBack, items: items);

late _FakeRepo _repo;
final _saved = <Map<String, Object?>>[];

Future<void> _open(WidgetTester tester, {bool offline = false, Food? food, double textScale = 1.0}) async {
  _repo = _FakeRepo();
  _saved.clear();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        foodControllerProvider.overrideWith(() => _FakeFoodController(_saved)),
        offSearchRepositoryProvider.overrideWithValue(_repo),
        offSearchPreferencesProvider.overrideWithValue(_FakePrefs()),
        isOfflineProvider.overrideWith((ref) => Stream.value(offline)),
      ],
      child: MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(textScale)),
          child: child!,
        ),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: TextButton(
                onPressed: () => showModalBottomSheet<void>(
                  context: context,
                  isScrollControlled: true,
                  builder: (_) => AddFoodSheet(food: food),
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
}

Finder _toggle() => find.byKey(const ValueKey('off-search-toggle'));
Finder _nameField() => find.byType(TextFormField).first;
Finder _sectionTitle() => find.byKey(const ValueKey('off-section-title'));
Finder _field(String label) => find.widgetWithText(TextFormField, label);

String _text(WidgetTester tester, Finder field) => tester.widget<TextFormField>(field).controller!.text;

Future<void> _tick(WidgetTester tester) async {
  await tester.tap(_toggle());
  await tester.pumpAndSettle();
}

Future<void> _type(WidgetTester tester, String text) async {
  await tester.enterText(_nameField(), text);
  await tester.pump();
}

Future<void> _debounce(WidgetTester tester) => tester.pump(offSearchDebounce + const Duration(milliseconds: 50));

Future<void> _answerLast(WidgetTester tester, OffSearchResult result) async {
  _repo.calls.last.completer.complete(result);
  await tester.pump();
  await tester.pump();
}

void main() {
  testWidgets('a new food has the checkbox, unticked, and no hint yet', (tester) async {
    await _open(tester);
    expect(_toggle(), findsOneWidget);
    expect(find.text('Also search the OpenFoodFacts food database'), findsOneWidget);
    expect(tester.widget<CheckboxListTile>(_toggle()).value, isFalse);
    expect(find.byKey(const ValueKey('off-search-hint')), findsNothing);
  });

  testWidgets('editing a food shows its stored fibre and sugar (LIF-145)', (tester) async {
    await _open(tester,
        food: const Food(clientId: 'f', name: 'Oats', caloriesPer100g: 370, proteinPer100g: 13, fiberPer100g: 10, sugarPer100g: 1.2));
    expect(_text(tester, _field('Fibre (optional)')), '10');
    expect(_text(tester, _field('Sugar (optional)')), '1.2');
  });

  testWidgets('editing a food with no fibre or sugar figure leaves the fields blank', (tester) async {
    await _open(tester, food: const Food(clientId: 'g', name: 'Egg', caloriesPer100g: 155, proteinPer100g: 13));
    expect(_text(tester, _field('Fibre (optional)')), '');
    expect(_text(tester, _field('Sugar (optional)')), '');
  });

  testWidgets('editing an existing food has no OpenFoodFacts option', (tester) async {
    await _open(tester, food: const Food(clientId: 'f', name: 'Egg', caloriesPer100g: 155, proteinPer100g: 13));

    expect(_toggle(), findsNothing);
  });

  testWidgets('unticked: typing a name searches nothing and shows no list', (tester) async {
    await _open(tester);

    await _type(tester, 'csirkemell');
    await _debounce(tester);

    expect(_sectionTitle(), findsNothing);
    expect(_repo.calls, isEmpty);
  });

  testWidgets('ticked: the hint says it is the OpenFoodFacts database; then the list of products appears under the name', (tester) async {
    await _open(tester);
    await _tick(tester);
    expect(find.byKey(const ValueKey('off-search-hint')), findsOneWidget);
    expect(find.textContaining('public food database run by volunteers'), findsOneWidget);

    await _type(tester, 'Csirkemell');
    expect(_repo.calls, isEmpty); // the debounce
    await _debounce(tester);
    expect(_repo.calls.single.text, 'csirkemell');
    expect(find.text('Searching OpenFoodFacts…'), findsOneWidget);
    await _answerLast(tester, _answer([_csirke, _noMacros]));

    expect(find.text('FROM THE OPENFOODFACTS DATABASE'), findsOneWidget);
    expect(find.textContaining('Csirkemell', findRichText: true), findsWidgets);
    expect(find.text('Pikok'), findsOneWidget);
    expect(find.text('OpenFoodFacts'), findsOneWidget); // the brandless one names its source
    expect(find.text('110 kcal'), findsOneWidget);
  });

  testWidgets('choosing a product fills name, calories, protein, carbs, fat and the barcode, closes the list and says so', (tester) async {
    await _open(tester);
    await _tick(tester);
    await _type(tester, 'csirkemell');
    await _debounce(tester);
    await _answerLast(tester, _answer([_csirke]));

    await tester.tap(find.text('Pikok')); // the row
    await tester.pumpAndSettle();

    expect(_text(tester, _nameField()), 'Csirkemell');
    expect(_text(tester, _field('Calories')), '110');
    expect(_text(tester, _field('Protein')), '14');
    expect(_text(tester, _field('Carbs (optional)')), '2.4');
    expect(_text(tester, _field('Fat (optional)')), '4.9');
    expect(_sectionTitle(), findsNothing);
    expect(find.byKey(const ValueKey('off-filled')), findsOneWidget);
    expect(find.textContaining('4056489827702'), findsOneWidget); // "Linked to barcode …"
    expect(_repo.calls, hasLength(1)); // filling the name did not search again
    expect(_saved, isEmpty); // nothing is saved by choosing
  });

  testWidgets('a product without carbs and fat leaves them blank', (tester) async {
    await _open(tester);
    await _tick(tester);
    await _type(tester, 'rudi');
    await _debounce(tester);
    await _answerLast(tester, _answer([_noMacros]));

    await tester.tap(find.text('OpenFoodFacts'));
    await tester.pumpAndSettle();

    expect(_text(tester, _nameField()), 'Túró Rudi');
    expect(_text(tester, _field('Carbs (optional)')), '');
    expect(_text(tester, _field('Fat (optional)')), '');
  });

  testWidgets('choosing a product with fibre and sugar fills them, and saving sends them (LIF-145)', (tester) async {
    await _open(tester);
    await _tick(tester);
    await _type(tester, 'muesli');
    await _debounce(tester);
    await _answerLast(tester, _answer([_muesli]));
    await tester.tap(find.text('Acme'));
    await tester.pumpAndSettle();

    expect(_text(tester, _field('Fibre (optional)')), '8.5');
    expect(_text(tester, _field('Sugar (optional)')), '14');

    await tester.ensureVisible(find.text('Save'));
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(_saved.single['fiber'], 8.5);
    expect(_saved.single['sugar'], 14.0);
  });

  testWidgets('a product without fibre and sugar leaves them blank, and nothing is sent for them', (tester) async {
    await _open(tester);
    await _tick(tester);
    await _type(tester, 'csirkemell');
    await _debounce(tester);
    await _answerLast(tester, _answer([_csirke]));
    await tester.tap(find.text('Pikok'));
    await tester.pumpAndSettle();

    expect(_text(tester, _field('Fibre (optional)')), '');
    expect(_text(tester, _field('Sugar (optional)')), '');
  });

  testWidgets('saving after choosing sends the filled values with the barcode', (tester) async {
    await _open(tester);
    await _tick(tester);
    await _type(tester, 'csirkemell');
    await _debounce(tester);
    await _answerLast(tester, _answer([_csirke]));
    await tester.tap(find.text('Pikok'));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Save'));
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(_saved, [
      {'name': 'Csirkemell', 'calories': 110.0, 'protein': 14.0, 'carbs': 2.4, 'fat': 4.9, 'barcode': '4056489827702'},
    ]);
  });

  testWidgets('editing the name after choosing shows the list again', (tester) async {
    await _open(tester);
    await _tick(tester);
    await _type(tester, 'csirkemell');
    await _debounce(tester);
    await _answerLast(tester, _answer([_csirke]));
    await tester.tap(find.text('Pikok'));
    await tester.pumpAndSettle();
    expect(_sectionTitle(), findsNothing);

    await _type(tester, 'csirkemell sonka');
    await _debounce(tester);
    await _answerLast(tester, _answer([_csirke]));

    expect(_sectionTitle(), findsOneWidget);
    expect(find.byKey(const ValueKey('off-filled')), findsNothing);
  });

  testWidgets('under three letters it asks for more; the fallback and failure notes show', (tester) async {
    await _open(tester);
    await _tick(tester);

    await _type(tester, 'cs');
    await _debounce(tester);
    expect(find.text('Type at least 3 letters to search OpenFoodFacts.'), findsOneWidget);
    expect(_repo.calls, isEmpty);

    await _type(tester, 'pumpkin');
    await _debounce(tester);
    await _answerLast(tester, _answer([_csirke], fellBack: true));
    expect(find.textContaining('Nothing found among products sold in Hungary'), findsOneWidget);

    await _type(tester, 'pumpkins');
    await _debounce(tester);
    await _answerLast(tester, _answer(const [], status: OffSearchStatus.unavailable));
    expect(find.text("OpenFoodFacts isn't answering right now."), findsOneWidget);
  });

  testWidgets('offline the checkbox is disabled and says why; the form works as before', (tester) async {
    await _open(tester, offline: true);

    expect(tester.widget<CheckboxListTile>(_toggle()).onChanged, isNull);
    expect(find.text("You're offline — OpenFoodFacts search needs a connection."), findsOneWidget);
    await _type(tester, 'csirkemell');
    await _debounce(tester);
    expect(_repo.calls, isEmpty);
  });

  testWidgets('at 1.3x text on a 360x640 phone the form scrolls instead of overflowing, with the list open', (tester) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await _open(tester, textScale: 1.3);
    await _tick(tester);

    await _type(tester, 'csirkemell');
    await _debounce(tester);
    await _answerLast(tester, _answer([_csirke, _noMacros, _csirke], fellBack: true));

    expect(tester.takeException(), isNull);
    expect(_sectionTitle(), findsOneWidget);
  });
}
