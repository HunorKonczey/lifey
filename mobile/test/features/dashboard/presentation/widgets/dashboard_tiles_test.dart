import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifey/core/format/lifey_format.dart';
import 'package:lifey/core/theme/app_theme.dart';
import 'package:lifey/features/dashboard/domain/daily_stats.dart';
import 'package:lifey/features/dashboard/presentation/widgets/dashboard_tiles.dart';
import 'package:lifey/features/settings/domain/user_settings.dart';
import 'package:lifey/features/weight/domain/weight_entry.dart';
import 'package:lifey/l10n/app_localizations.dart';
import 'package:lifey/shared/widgets/ds/delta_chip.dart';
import 'package:lifey/shared/widgets/ds/metric_bar.dart';
import 'package:lifey/shared/widgets/ds/sparkline.dart';

final _now = DateTime(2026, 9, 24, 9, 41);

WeightEntry _w(double kg, {int daysAgo = 0}) {
  final day = DateTime(_now.year, _now.month, _now.day - daysAgo);
  return WeightEntry(clientId: 'w$daysAgo', date: day, weight: kg, recordedAt: day);
}

DailyStats _stats({double water = 0.99, double? weight = 64.5}) => DailyStats(
      calories: 0,
      protein: 0,
      carbs: 0,
      fat: 0,
      workoutCount: 0,
      water: water,
      latestWeight: weight,
    );

const _base = UserSettings.defaults();

/// The canvas user: a 2.6 L water goal and no step goal of their own.
final _canvasUser = _base.copyWith(dailyWaterGoalLiters: 2.6);

Future<void> _pump(
  WidgetTester tester, {
  DailyStats? stats,
  UserSettings? settings,
  int? steps = 6412,
  List<WeightEntry>? weights,
  Locale locale = const Locale('en'),
  double textScale = 1,
  double width = 411,
  ThemeData? theme,
  VoidCallback? onAddWater,
  VoidCallback? onWeightTap,
}) async {
  tester.view.physicalSize = Size(width * 2.625, 923 * 2.625);
  tester.view.devicePixelRatio = 2.625;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      theme: theme ?? AppTheme.dark,
      locale: locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(textScale)),
        child: child!,
      ),
      home: Scaffold(
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: DashboardTiles(
            stats: stats ?? _stats(),
            settings: settings ?? _canvasUser,
            todaySteps: steps,
            weights: weights ?? [_w(64.5), _w(64.6, daysAgo: 1)],
            onAddWater: onAddWater ?? () {},
            onWeightTap: onWeightTap ?? () {},
            now: _now,
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  group('the canvas numbers (EN)', () {
    testWidgets('water "0.99 / 2.6 L", steps "6,412 of 10,000" with no goal set, weight "64.5 kg"',
        (tester) async {
      await _pump(tester);
      expect(find.text('Water'), findsOneWidget);
      expect(find.textContaining('0.99', findRichText: true), findsOneWidget);
      expect(find.textContaining('/ 2.6 L', findRichText: true), findsOneWidget);
      expect(find.textContaining('6,412', findRichText: true), findsOneWidget);
      expect(find.textContaining('of 10,000', findRichText: true), findsOneWidget);
      expect(find.textContaining('64.5', findRichText: true), findsOneWidget);
      expect(find.text('Weight'), findsOneWidget);
    });

    testWidgets('bars: water 0.99 / 2.6, steps 6 412 / 10 000', (tester) async {
      await _pump(tester);
      final bars = tester.widgetList<MetricBar>(find.byType(MetricBar)).map((b) => b.progress).toList();
      expect(bars, [closeTo(0.99 / 2.6, 1e-9), closeTo(0.6412, 1e-9)]);
    });

    testWidgets('an own step goal replaces the default', (tester) async {
      await _pump(tester, settings: _canvasUser.copyWith(dailyStepGoal: 8000));
      expect(find.textContaining('of 8,000', findRichText: true), findsOneWidget);
    });

    testWidgets('steps beyond the goal are shown in full', (tester) async {
      await _pump(tester, steps: 12500);
      expect(find.textContaining('12,500', findRichText: true), findsOneWidget);
    });
  });

  group('water', () {
    testWidgets('the 48 dp + button opens the add sheet', (tester) async {
      var taps = 0;
      await _pump(tester, onAddWater: () => taps++);
      final button = find.byTooltip('Add water');
      final size = tester.getSize(button);
      expect(size.width, greaterThanOrEqualTo(48));
      expect(size.height, greaterThanOrEqualTo(48));
      await tester.tap(button);
      expect(taps, 1);
    });

    testWidgets('without a water goal it is just "0.99 L" with no bar', (tester) async {
      await _pump(tester, settings: _base);
      expect(find.textContaining('0.99 L', findRichText: true), findsOneWidget);
      expect(find.byType(MetricBar), findsOneWidget, reason: 'only the steps bar');
    });
  });

  group('steps', () {
    testWidgets('no step data: the tile is gone and the water tile is full width', (tester) async {
      await _pump(tester, steps: null);
      expect(find.text('Steps'), findsNothing);
      // Full width: the + button sits at the far right of the content area.
      expect(tester.getTopRight(find.byTooltip('Add water')).dx, greaterThan(411 - 40));
    });

    testWidgets('with step data the water tile is half width', (tester) async {
      await _pump(tester);
      expect(find.text('Steps'), findsOneWidget);
      expect(tester.getTopRight(find.byTooltip('Add water')).dx, lessThan(411 / 2 + 20));
    });
  });

  group('weight', () {
    testWidgets('a loss shows "↓ 0.1 kg" as a direction-coloured chip, never a green one', (tester) async {
      await _pump(tester);
      final chip = tester.widget<DeltaChip>(find.byType(DeltaChip));
      expect(chip.value, closeTo(-0.1, 1e-9));
      expect(chip.color, isNull, reason: 'colour follows the direction: decrease = weight blue');
      expect(find.textContaining('0.1 kg', findRichText: true), findsWidgets);
    });

    testWidgets('a gain is an upward chip', (tester) async {
      await _pump(tester, weights: [_w(64.9), _w(64.5, daysAgo: 1)]);
      expect(tester.widget<DeltaChip>(find.byType(DeltaChip)).value, closeTo(0.4, 1e-9));
    });

    testWidgets('no change: no chip', (tester) async {
      await _pump(tester, weights: [_w(64.5), _w(64.5, daysAgo: 1)]);
      expect(find.byType(DeltaChip), findsNothing);
    });

    testWidgets('a single entry: no chip and no trend line', (tester) async {
      await _pump(tester, weights: [_w(64.5)]);
      expect(find.byType(DeltaChip), findsNothing);
      expect(find.byType(Sparkline), findsNothing);
    });

    testWidgets('"Latest entry · today"', (tester) async {
      await _pump(tester);
      expect(find.text('Latest entry · today'), findsOneWidget);
    });

    testWidgets('"Latest entry · yesterday"', (tester) async {
      await _pump(tester, weights: [_w(64.5, daysAgo: 1), _w(64.6, daysAgo: 2)]);
      expect(find.text('Latest entry · yesterday'), findsOneWidget);
    });

    testWidgets('an older entry shows its date', (tester) async {
      await _pump(tester, weights: [_w(64.5, daysAgo: 2), _w(64.6, daysAgo: 3)]);
      expect(find.text('Latest entry · Sep 22'), findsOneWidget);
    });

    testWidgets('a trend line appears from two entries', (tester) async {
      await _pump(tester);
      expect(find.byType(Sparkline), findsOneWidget);
    });

    testWidgets('the sparkline shows at most the last 10 entries, oldest first', (tester) async {
      final entries = [for (var i = 0; i < 14; i++) _w(64 + i * 0.1, daysAgo: i)];
      await _pump(tester, weights: entries);
      final values = tester.widget<Sparkline>(find.byType(Sparkline)).values;
      expect(values.length, 10);
      expect(values.last, entries.first.weight);
      expect(values.first, entries[9].weight);
    });

    testWidgets('no entries at all: a dash and no subline', (tester) async {
      await _pump(tester, stats: _stats(weight: null), weights: const []);
      expect(find.textContaining('—', findRichText: true), findsOneWidget);
      expect(find.textContaining('Latest entry'), findsNothing);
    });

    testWidgets('tapping the tile goes to the weight screen', (tester) async {
      var taps = 0;
      await _pump(tester, onWeightTap: () => taps++);
      await tester.tap(find.text('Weight'));
      expect(taps, 1);
    });
  });

  test('latestWeightChange compares the two newest entries, newest first', () {
    expect(latestWeightChange([_w(64.5), _w(64.6, daysAgo: 1)]), closeTo(-0.1, 1e-9));
    expect(latestWeightChange([_w(64.5)]), isNull);
    expect(latestWeightChange(const []), isNull);
  });

  group('Hungarian', () {
    testWidgets('canvas 1.3 copy and decimal comma', (tester) async {
      await _pump(tester, locale: const Locale('hu'));
      final f = LifeyFormat('hu');
      expect(find.text('Víz'), findsOneWidget);
      expect(find.text('Lépések'), findsOneWidget);
      expect(find.text('Súly'), findsOneWidget);
      expect(find.textContaining('0,99', findRichText: true), findsOneWidget);
      expect(find.textContaining('/ 2,6 L', findRichText: true), findsOneWidget);
      expect(find.textContaining('/ ${f.integer(10000)}', findRichText: true), findsOneWidget);
      expect(find.textContaining('64,5', findRichText: true), findsOneWidget);
      expect(find.text('Legutóbbi bejegyzés · ma'), findsOneWidget);
    });

    for (final width in [411.0, 360.0]) {
      for (final scale in [1.0, 1.3]) {
        for (final theme in {'dark': AppTheme.dark, 'light': AppTheme.light}.entries) {
          testWidgets('fits without overflow or truncation — ${theme.key}, ${width.round()} dp, ×$scale',
              (tester) async {
            await _pump(tester, locale: const Locale('hu'), textScale: scale, width: width, theme: theme.value);
            expect(tester.takeException(), isNull);
            for (final t in tester.widgetList<Text>(find.byType(Text))) {
              expect(t.overflow, isNot(TextOverflow.ellipsis));
            }
            expect(find.text('Legutóbbi bejegyzés · ma'), findsOneWidget);
          });
        }
      }
    }
  });
}
