import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifey/core/theme/app_theme.dart';
import 'package:lifey/core/theme/app_tokens.dart';
import 'package:lifey/features/onboarding/data/user_details_repository.dart';
import 'package:lifey/features/weight/application/weight_controller.dart';
import 'package:lifey/features/weight/application/weight_range.dart';
import 'package:lifey/features/weight/domain/weight_entry.dart';
import 'package:lifey/features/weight/presentation/weight_screen.dart';
import 'package:lifey/l10n/app_localizations.dart';
import 'package:lifey/shared/widgets/charts/time_series_chart.dart';
import 'package:lifey/shared/widgets/ds/delta_chip.dart';
import 'package:lifey/shared/widgets/ds/lifey_segmented.dart';
import 'package:lifey/shared/widgets/shell_fab.dart';

/// R4.1–R4.3 on the whole screen: header, hero card, range switcher, chart with
/// its average, history rows with signed changes.

class _FakeWeights extends WeightController {
  _FakeWeights(this._entries);

  final List<WeightEntry> _entries;

  @override
  Stream<List<WeightEntry>> build() => Stream.value(_entries);
}

final _now = DateTime.now();
DateTime _day(int daysAgo) => DateTime(_now.year, _now.month, _now.day).subtract(Duration(days: daysAgo));

WeightEntry _e(int daysAgo, double kg) => WeightEntry(
      clientId: 'w$daysAgo',
      date: _day(daysAgo),
      weight: kg,
      recordedAt: _day(daysAgo).add(const Duration(hours: 7, minutes: 2)),
    );

Future<ProviderContainer> _pump(
  WidgetTester tester,
  List<WeightEntry> entries, {
  Locale locale = const Locale('en'),
  double width = 411,
  double textScale = 1,
  ThemeData? theme,
}) async {
  tester.view.physicalSize = Size(width * 2.625, 1400 * 2.625);
  tester.view.devicePixelRatio = 2.625;
  addTearDown(tester.view.reset);
  final container = ProviderContainer(overrides: [
    weightControllerProvider.overrideWith(() => _FakeWeights(entries)),
    userDetailsProvider.overrideWith((ref) async => null),
  ]);
  addTearDown(container.dispose);
  await tester.pumpWidget(UncontrolledProviderScope(
    container: container,
    child: MaterialApp(
      theme: theme ?? AppTheme.dark,
      locale: locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(textScale)),
        child: child!,
      ),
      home: const WeightScreen(),
    ),
  ));
  await tester.pumpAndSettle();
  return container;
}

void main() {
  final canvas = [_e(0, 64.5), _e(1, 64.6), _e(4, 64.9), _e(20, 65.4), _e(29, 65.9)];

  testWidgets('title, hero, range switcher, chart with the average, history', (tester) async {
    await _pump(tester, canvas);

    expect(find.text('Weight'), findsOneWidget);
    expect(find.text('64.5 kg'), findsWidgets); // hero and the first history row
    for (final range in ['7 d', '30 d', '90 d', 'All']) {
      expect(find.text(range), findsOneWidget, reason: range);
    }
    expect(tester.widget<LifeySegmented<WeightRange>>(find.byType(LifeySegmented<WeightRange>)).selected, WeightRange.month);
    final chart = tester.widget<TimeSeriesChart>(find.byType(TimeSeriesChart));
    expect(chart.trendStyle, TrendStyle.dotted);
    expect(chart.legend, isNotNull);
    expect(find.text('Daily'), findsOneWidget);
    expect(find.text('7-day average'), findsOneWidget);
    expect(find.text('HISTORY'), findsOneWidget);
  });

  testWidgets('"+ Log" is the shell action', (tester) async {
    final container = await _pump(tester, canvas);

    final fab = container.read(shellFabProvider);
    expect(fab, isNotNull);
    expect(fab!.label, 'Log');
    expect(fab.extended, isTrue);
  });

  testWidgets('history rows: date, weight and a signed change; the oldest has none', (tester) async {
    await _pump(tester, canvas);

    expect(find.text('Today'), findsOneWidget);
    expect(find.text('Yesterday'), findsOneWidget);
    // 64.5 vs 64.6 → −0.1 with a real minus sign, 64.6 vs 64.9 → −0.3
    expect(find.text('−0.1'), findsOneWidget);
    expect(find.text('−0.3'), findsOneWidget);
    // 5 entries → 4 chips (the hero has two arrow chips of its own)
    expect(find.byType(DeltaChip), findsNWidgets(4 + 2));
  });

  testWidgets('a gain reads with a plus sign, in the increase colour', (tester) async {
    await _pump(tester, [_e(0, 65.0), _e(1, 64.4)]);

    expect(find.text('+0.6'), findsOneWidget);
    final chip = tester.widget<Container>(find.ancestor(of: find.text('+0.6'), matching: find.byType(Container)).first);
    expect(((chip.decoration as BoxDecoration).color!.toARGB32()) & 0xFFFFFF,
        AppMetricColors.dark.increase.toARGB32() & 0xFFFFFF);
  });

  testWidgets('no change has no sign', (tester) async {
    await _pump(tester, [_e(0, 65.0), _e(1, 65.0)]);

    expect(find.text('0.0'), findsOneWidget);
    expect(find.text('+0.0'), findsNothing);
    expect(find.text('−0.0'), findsNothing);
  });

  testWidgets('a single entry: one point, no average line, nothing to compare', (tester) async {
    await _pump(tester, [_e(0, 64.5)]);

    final chart = tester.widget<TimeSeriesChart>(find.byType(TimeSeriesChart));
    expect(chart.points, hasLength(1));
    expect(chart.trendValues?.any((v) => v != null) ?? false, isFalse);
    expect(find.text('7-day average'), findsNothing); // no trend, no legend entry for it
    expect(find.byType(DeltaChip), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('no entries: the empty state', (tester) async {
    await _pump(tester, const []);

    expect(find.text('Weight'), findsOneWidget);
    expect(find.byType(TimeSeriesChart), findsNothing);
    expect(find.byIcon(Icons.monitor_weight_outlined), findsOneWidget);
  });

  testWidgets('switching the range redraws the chart', (tester) async {
    await _pump(tester, canvas);
    final before = tester.widget<TimeSeriesChart>(find.byType(TimeSeriesChart)).points.length;

    await tester.tap(find.text('7 d'));
    await tester.pumpAndSettle();

    final after = tester.widget<TimeSeriesChart>(find.byType(TimeSeriesChart)).points.length;
    expect(after, lessThan(before));
  });

  for (final width in [411.0, 360.0]) {
    for (final theme in [AppTheme.dark, AppTheme.light]) {
      testWidgets('no overflow at ${width.toInt()} dp, text x1.3, HU, ${theme == AppTheme.dark ? 'dark' : 'light'}', (tester) async {
        await _pump(tester, canvas, locale: const Locale('hu'), width: width, textScale: 1.3, theme: theme);

        final error = tester.takeException();
        expect(error is FlutterError ? error.toStringDeep() : error, isNull);
        expect(find.text('Súly'), findsOneWidget);
      });
    }
  }

  test('the direction colours are the design tokens', () {
    // decrease = weight blue, increase = calorie orange (canvas 4.1 history)
    expect(AppMetricColors.dark.decrease, AppMetricColors.dark.weight);
    expect(AppMetricColors.dark.increase, AppMetricColors.dark.calories);
  });
}
