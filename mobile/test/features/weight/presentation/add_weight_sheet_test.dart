import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifey/core/theme/app_theme.dart';
import 'package:lifey/features/weight/application/weight_controller.dart';
import 'package:lifey/features/weight/domain/weight_entry.dart';
import 'package:lifey/features/weight/presentation/widgets/add_weight_sheet.dart';
import 'package:lifey/l10n/app_localizations.dart';

/// R4.4: the log-weight sheet — 72 px value, 56 dp ±0.1 buttons, a reference,
/// a date row, Save; grams inside so steps never drift.

class _RecordingWeights extends WeightController {
  _RecordingWeights(this._entries);

  final List<WeightEntry> _entries;
  final saved = <({DateTime date, double weight})>[];

  @override
  Stream<List<WeightEntry>> build() => Stream.value(_entries);

  @override
  Future<void> addEntry({required DateTime date, required double weight}) async {
    saved.add((date: date, weight: weight));
  }
}

final _now = DateTime.now();
DateTime _day(int daysAgo) => DateTime(_now.year, _now.month, _now.day).subtract(Duration(days: daysAgo));

WeightEntry _e(int daysAgo, double kg) =>
    WeightEntry(clientId: 'w$daysAgo', date: _day(daysAgo), weight: kg, recordedAt: _day(daysAgo));

final _canvas = [_e(0, 64.5), _e(1, 64.6), _e(4, 64.9)];

Future<_RecordingWeights> _open(
  WidgetTester tester,
  List<WeightEntry> entries, {
  Locale locale = const Locale('en'),
  double width = 411,
  double textScale = 1,
  ThemeData? theme,
}) async {
  tester.view.physicalSize = Size(width * 2.625, 923 * 2.625);
  tester.view.devicePixelRatio = 2.625;
  addTearDown(tester.view.reset);
  final controller = _RecordingWeights(entries);
  await tester.pumpWidget(ProviderScope(
    overrides: [weightControllerProvider.overrideWith(() => controller)],
    child: MaterialApp(
      theme: theme ?? AppTheme.dark,
      locale: locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(textScale)),
        child: child!,
      ),
      home: Builder(
        builder: (context) => Scaffold(
          body: Center(child: ElevatedButton(onPressed: () => showAddWeightSheet(context), child: const Text('open'))),
        ),
      ),
    ),
  ));
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
  // the provider only streams once something reads it
  await tester.pump();
  return controller;
}

double _valueFontSize(WidgetTester tester, String value) {
  final text = tester.widgetList<Text>(find.byType(Text)).firstWhere((t) => t.textSpan?.toPlainText() == value);
  return (text.textSpan! as TextSpan).style!.fontSize!;
}

void main() {
  testWidgets('the canvas sheet: title, 72 px latest weight, yesterday, today\'s date row, Save', (tester) async {
    await _open(tester, _canvas);

    expect(find.text('Log weight'), findsOneWidget);
    expect(find.text('64.5 kg'), findsOneWidget);
    expect(_valueFontSize(tester, '64.5 kg'), 72);
    expect(find.text('Yesterday 64.6 kg'), findsOneWidget);
    expect(find.textContaining('Today · '), findsOneWidget);
    expect(find.text('Save'), findsOneWidget);
    expect(find.byIcon(Icons.close_rounded), findsOneWidget);
    // never claims a write to Health Connect — the app only imports weight
    expect(find.textContaining('Health Connect'), findsNothing);
  });

  testWidgets('the ± buttons are 56 dp and step 0.1 kg', (tester) async {
    await _open(tester, _canvas);

    final plus = find.byIcon(Icons.add_rounded);
    final button = find.ancestor(of: plus, matching: find.byType(InkWell)).first;
    expect(tester.getSize(button), const Size(56, 56));

    await tester.tap(plus);
    await tester.pump();
    expect(find.text('64.6 kg'), findsOneWidget);
    await tester.tap(find.byIcon(Icons.remove_rounded));
    await tester.tap(find.byIcon(Icons.remove_rounded));
    await tester.pump();
    expect(find.text('64.4 kg'), findsOneWidget);
  });

  testWidgets('holding + repeats; the number never drifts off the tenth', (tester) async {
    await _open(tester, _canvas);

    final gesture = await tester.startGesture(tester.getCenter(find.byIcon(Icons.add_rounded)));
    await tester.pump(const Duration(milliseconds: 400 + 90 * 20));
    await gesture.up();
    await tester.pump();

    final shown = tester.widgetList<Text>(find.byType(Text)).map((t) => t.textSpan?.toPlainText()).whereType<String>();
    final value = shown.firstWhere((s) => RegExp(r'^\d+\.\d kg$').hasMatch(s));
    final kg = double.parse(value.replaceAll(' kg', ''));
    expect(kg, greaterThan(65.5));
    expect(kg * 10, closeTo((kg * 10).roundToDouble(), 1e-9)); // whole tenths only
  });

  testWidgets('Save writes exactly the value shown', (tester) async {
    final controller = await _open(tester, _canvas);

    await tester.tap(find.byIcon(Icons.add_rounded));
    await tester.tap(find.byIcon(Icons.add_rounded));
    await tester.pump();
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(controller.saved, hasLength(1));
    expect(controller.saved.single.weight, 64.7); // not 64.699999999999996
    expect(find.text('Log weight'), findsNothing); // the sheet closed
  });

  testWidgets('tap the number to type it; a comma works; Save uses it', (tester) async {
    final controller = await _open(tester, _canvas);

    await tester.tap(find.text('64.5 kg'));
    await tester.pump();
    await tester.enterText(find.byType(TextField), '70,3');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(controller.saved.single.weight, 70.3);
  });

  testWidgets('something that is not a weight is refused with a message', (tester) async {
    final controller = await _open(tester, _canvas);

    await tester.tap(find.text('64.5 kg'));
    await tester.pump();
    await tester.enterText(find.byType(TextField), '0');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();

    expect(find.text('Enter a number'), findsOneWidget);
    expect(tester.widget<FilledButton>(find.byType(FilledButton)).onPressed, isNull);
    expect(controller.saved, isEmpty);
  });

  testWidgets('no history: starts from a neutral value and shows no reference', (tester) async {
    await _open(tester, const []);

    expect(find.text('70.0 kg'), findsOneWidget);
    expect(find.textContaining('Yesterday'), findsNothing);
    expect(find.textContaining('Last '), findsNothing);
  });

  testWidgets('no weigh-in yesterday: the reference is the last one, with its date', (tester) async {
    await _open(tester, [_e(0, 64.5), _e(3, 64.9)]);

    expect(find.textContaining('Last 64.9 kg · '), findsOneWidget);
    expect(find.textContaining('Yesterday'), findsNothing);
  });

  testWidgets('the minus stops at the lower limit', (tester) async {
    await _open(tester, [_e(0, 1.0)]);

    final minus = find.ancestor(of: find.byIcon(Icons.remove_rounded), matching: find.byType(InkWell)).first;
    expect(tester.widget<InkWell>(minus).onTap, isNull);
  });

  for (final width in [411.0, 360.0]) {
    testWidgets('no overflow at ${width.toInt()} dp, text x1.3, HU, light', (tester) async {
      await _open(tester, _canvas, locale: const Locale('hu'), width: width, textScale: 1.3, theme: AppTheme.light);

      final error = tester.takeException();
      expect(error is FlutterError ? error.toStringDeep() : error, isNull);
      expect(find.text('Súly rögzítése'), findsOneWidget);
      expect(find.text('Tegnap 64,6 kg'), findsOneWidget);
    });
  }
}
