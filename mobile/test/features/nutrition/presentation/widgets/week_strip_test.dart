import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifey/core/theme/app_theme.dart';
import 'package:lifey/features/nutrition/domain/meal_days.dart';
import 'package:lifey/features/nutrition/presentation/widgets/week_strip.dart';
import 'package:lifey/l10n/app_localizations.dart';
import 'package:lifey/shared/widgets/ds/progress_ring.dart';

final _now = DateTime(2026, 9, 24, 9);

Future<void> _pump(
  WidgetTester tester, {
  DateTime? selected,
  Map<DateTime, double> kcal = const {},
  int? goal = 2360,
  Locale locale = const Locale('en'),
  double textScale = 1,
  double width = 411,
  ValueChanged<DateTime>? onSelect,
}) async {
  tester.view.physicalSize = Size(width * 2.625, 923 * 2.625);
  tester.view.devicePixelRatio = 2.625;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.dark,
      locale: locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(textScale)),
        child: child!,
      ),
      home: Scaffold(
        body: Padding(
          padding: const EdgeInsets.all(20),
          child: WeekStrip(
            days: lastSevenDays(_now),
            selected: selected ?? DateTime(2026, 9, 24),
            kcalByDay: kcal,
            goal: goal,
            onSelect: onSelect ?? (_) {},
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('seven days Fri … Thu with their dates, today last', (tester) async {
    await _pump(tester);

    for (final label in ['Fri', 'Sat', 'Sun', 'Mon', 'Tue', 'Wed', 'Thu']) {
      expect(find.text(label), findsOneWidget, reason: label);
    }
    for (final date in ['18', '19', '20', '21', '22', '23', '24']) {
      expect(find.text(date), findsOneWidget, reason: date);
    }
    expect(find.byType(ProgressRing), findsNWidgets(7));
  });

  testWidgets('rings show each day\'s kcal over the goal', (tester) async {
    await _pump(tester, kcal: {DateTime(2026, 9, 23): 1180, DateTime(2026, 9, 24): 621});

    final rings = tester.widgetList<ProgressRing>(find.byType(ProgressRing)).toList();
    expect(rings[6].progress, closeTo(621 / 2360, 1e-9));
    expect(rings[5].progress, closeTo(0.5, 1e-9));
    expect(rings[0].progress, 0);
  });

  testWidgets('without a calorie goal the rings stay empty', (tester) async {
    await _pump(tester, goal: null, kcal: {DateTime(2026, 9, 24): 621});

    for (final ring in tester.widgetList<ProgressRing>(find.byType(ProgressRing))) {
      expect(ring.progress, 0);
    }
  });

  testWidgets('tapping a day selects it', (tester) async {
    DateTime? picked;
    await _pump(tester, onSelect: (d) => picked = d);

    await tester.tap(find.text('21'));

    expect(picked, DateTime(2026, 9, 21));
  });

  testWidgets('the selected day is announced as selected, with its kcal', (tester) async {
    await _pump(tester, kcal: {DateTime(2026, 9, 24): 621});

    expect(tester.getSemantics(find.bySemanticsLabel(RegExp('621 kcal'))), isSemantics(isSelected: true, isButton: true));
    expect(tester.getSemantics(find.bySemanticsLabel(RegExp('Wed'))), isSemantics(isSelected: false, isButton: true));
  });

  testWidgets('Hungarian weekday abbreviations', (tester) async {
    await _pump(tester, locale: const Locale('hu'));

    expect(find.text('P'), findsOneWidget); // péntek
    expect(find.text('Szo'), findsOneWidget);
    expect(find.text('V'), findsOneWidget);
    expect(find.text('H'), findsOneWidget);
    expect(find.text('K'), findsOneWidget);
    expect(find.text('Sze'), findsOneWidget);
    expect(find.text('Cs'), findsOneWidget);
  });

  for (final width in [411.0, 360.0]) {
    testWidgets('fits at ${width.toInt()} dp and 130 % text without overflow', (tester) async {
      await _pump(tester, width: width, textScale: 1.3, locale: const Locale('hu'));

      expect(tester.takeException(), isNull);
      expect(find.byType(ProgressRing), findsNWidgets(7));
    });
  }
}
