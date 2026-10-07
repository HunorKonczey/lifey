import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifey/core/theme/app_theme.dart';
import 'package:lifey/features/measurements/application/body_measurement_controller.dart';
import 'package:lifey/features/measurements/domain/body_measurement.dart';
import 'package:lifey/features/measurements/presentation/body_measurements_tab.dart';
import 'package:lifey/features/measurements/presentation/widgets/add_measurement_sheet.dart';
import 'package:lifey/l10n/app_localizations.dart';

class _FakeMeasurements extends BodyMeasurementController {
  _FakeMeasurements(this._entries);

  final List<BodyMeasurement> _entries;
  final added = <({DateTime date, MeasurementSite site, double valueCm})>[];
  final removed = <String>[];

  @override
  Stream<List<BodyMeasurement>> build() => Stream.value(_entries);

  @override
  Future<void> add({required DateTime date, required MeasurementSite site, required double valueCm}) async {
    added.add((date: date, site: site, valueCm: valueCm));
  }

  @override
  Future<void> remove(String clientId) async => removed.add(clientId);

  @override
  Future<void> refresh() async {}
}

final _now = DateTime.now();
DateTime _day(int daysAgo) => DateTime(_now.year, _now.month, _now.day).subtract(Duration(days: daysAgo));

BodyMeasurement _m(String id, int daysAgo, MeasurementSite site, double cm) =>
    BodyMeasurement(clientId: id, date: _day(daysAgo), site: site, valueCm: cm, recordedAt: _day(daysAgo));

Future<_FakeMeasurements> _pump(WidgetTester tester, List<BodyMeasurement> entries, Widget home) async {
  tester.view.physicalSize = const Size(411 * 2.625, 923 * 2.625);
  tester.view.devicePixelRatio = 2.625;
  addTearDown(tester.view.reset);
  final fake = _FakeMeasurements(entries);
  await tester.pumpWidget(ProviderScope(
    overrides: [bodyMeasurementControllerProvider.overrideWith(() => fake)],
    child: MaterialApp(
      theme: AppTheme.dark,
      locale: const Locale('en'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: home,
    ),
  ));
  await tester.pumpAndSettle();
  return fake;
}

/// MetricValue draws its number as a text span, so `find.text` cannot see it.
Finder _value(String v) => find.byWidgetPredicate(
      (w) => w is Text && (w.textSpan?.toPlainText() ?? w.data ?? '').startsWith(v),
    );

void main() {
  testWidgets('empty state invites the first measurement', (tester) async {
    await _pump(tester, const [], const Scaffold(body: BodyMeasurementsTab()));

    expect(find.text('No measurements yet'), findsOneWidget);
  });

  testWidgets('shows the selected site latest value, and switching site switches the list', (tester) async {
    await _pump(
      tester,
      [
        _m('w1', 0, MeasurementSite.waist, 81.0),
        _m('w2', 7, MeasurementSite.waist, 82.5),
        _m('a1', 2, MeasurementSite.arm, 35.0),
      ],
      const Scaffold(body: BodyMeasurementsTab()),
    );

    expect(_value('81.0'), findsWidgets);
    expect(_value('35.0'), findsNothing);

    await tester.tap(find.widgetWithText(ChoiceChip, 'Arm'));
    await tester.pumpAndSettle();

    expect(_value('35.0'), findsWidgets);
    expect(_value('81.0'), findsNothing);
  });

  testWidgets('a site with no entries says so while other sites have data', (tester) async {
    await _pump(tester, [_m('w1', 0, MeasurementSite.waist, 81.0)], const Scaffold(body: BodyMeasurementsTab()));

    await tester.tap(find.widgetWithText(ChoiceChip, 'Hips'));
    await tester.pumpAndSettle();

    expect(find.text('Nothing logged for this part yet'), findsOneWidget);
  });

  testWidgets('swiping a history row away removes that entry', (tester) async {
    final fake = await _pump(
      tester,
      [_m('w1', 0, MeasurementSite.waist, 81.0), _m('w2', 7, MeasurementSite.waist, 82.5)],
      const Scaffold(body: BodyMeasurementsTab()),
    );

    await tester.drag(find.byKey(const ValueKey('measurement-w2')), const Offset(-600, 0));
    await tester.pumpAndSettle();

    expect(fake.removed, ['w2']);
  });

  testWidgets('the sheet saves the typed value (comma decimal) for the chosen site', (tester) async {
    final fake = await _pump(
      tester,
      const [],
      Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: ElevatedButton(
              onPressed: () => showAddMeasurementSheet(context, initialSite: MeasurementSite.waist),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(ChoiceChip, 'Chest'));
    await tester.pump();
    await tester.enterText(find.byType(TextField), '101,5');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(fake.added, hasLength(1));
    expect(fake.added.single.site, MeasurementSite.chest);
    expect(fake.added.single.valueCm, 101.5);
  });

  testWidgets('the sheet refuses an out-of-range value and shows the error', (tester) async {
    final fake = await _pump(
      tester,
      const [],
      Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: ElevatedButton(
              onPressed: () => showAddMeasurementSheet(context, initialSite: MeasurementSite.waist),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), '0');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(find.text('Enter a value between 1 and 300 cm'), findsOneWidget);
    expect(fake.added, isEmpty);
  });

  // LIF-124: with the keyboard up on a 411 dp phone the lower half of Save sat
  // behind it. The test keyboard is Android's usual ~300 dp tall.
  for (final (label, locale, scale) in [
    ('English', const Locale('en'), 1.0),
    ('Hungarian', const Locale('hu'), 1.0),
    ('Hungarian at 1.3', const Locale('hu'), 1.3),
    // Tall enough that the content cannot fit above the keyboard: the sheet
    // has to scroll Save into view by itself.
    ('Hungarian at 2.0', const Locale('hu'), 2.0),
  ]) {
    testWidgets('Save stays above the keyboard in the sheet ($label)', (tester) async {
      tester.view.physicalSize = const Size(411 * 2.625, 923 * 2.625);
      tester.view.devicePixelRatio = 2.625;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(ProviderScope(
        overrides: [bodyMeasurementControllerProvider.overrideWith(() => _FakeMeasurements(const []))],
        child: MaterialApp(
          theme: AppTheme.dark,
          locale: locale,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(scale)),
            child: child!,
          ),
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: ElevatedButton(
                  onPressed: () => showAddMeasurementSheet(context, initialSite: MeasurementSite.waist),
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        ),
      ));
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      tester.view.viewInsets = const FakeViewPadding(bottom: 300 * 2.625);
      addTearDown(tester.view.resetViewInsets);
      await tester.pumpAndSettle();

      final keyboardTop = 923.0 - 300;
      final save = tester.getRect(find.byType(FilledButton));
      expect(save.bottom, lessThanOrEqualTo(keyboardTop), reason: "Save runs into the keyboard");
    });
  }
}
