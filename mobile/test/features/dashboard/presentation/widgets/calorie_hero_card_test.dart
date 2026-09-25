import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifey/core/format/lifey_format.dart';
import 'package:lifey/core/theme/app_theme.dart';
import 'package:lifey/features/dashboard/domain/daily_stats.dart';
import 'package:lifey/features/dashboard/presentation/widgets/calorie_hero_card.dart';
import 'package:lifey/features/settings/domain/user_settings.dart';
import 'package:lifey/l10n/app_localizations.dart';
import 'package:lifey/shared/widgets/ds/metric_bar.dart';
import 'package:lifey/shared/widgets/ds/progress_ring.dart';
import 'package:lifey/shared/widgets/ds/tinted_chip.dart';

const _goals = UserSettings.defaults();

UserSettings _settings({int? kcal = 2360, int? protein = 129, int? carbs = 313, int? fat = 66}) =>
    _goals.copyWith(
      dailyCalorieGoal: kcal,
      dailyProteinGoal: protein,
      dailyCarbsGoal: carbs,
      dailyFatGoal: fat,
    );

DailyStats _stats({double kcal = 621, double protein = 29, double carbs = 88, double fat = 20}) => DailyStats(
      calories: kcal,
      protein: protein,
      carbs: carbs,
      fat: fat,
      workoutCount: 0,
      water: 0,
    );

Future<void> _pump(
  WidgetTester tester,
  DailyStats stats,
  UserSettings settings, {
  Locale locale = const Locale('en'),
  double textScale = 1,
  double width = 411,
  ThemeData? theme,
  VoidCallback? onTap,
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
        body: Padding(
          padding: const EdgeInsets.all(20),
          child: CalorieHeroCard(stats: stats, settings: settings, onTap: onTap),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

double _ringProgress(WidgetTester tester) => tester.widget<ProgressRing>(find.byType(ProgressRing)).progress;

void main() {
  group('under the goal — the canvas numbers', () {
    testWidgets('shows what is LEFT as the hero number, with eaten and goal under the ring',
        (tester) async {
      await _pump(tester, _stats(), _settings());
      expect(find.text('1 739'), findsNothing, reason: 'EN groups with a comma');
      expect(find.text('1,739'), findsOneWidget);
      expect(find.text('kcal left'), findsOneWidget);
      // "Eaten 621 · Goal 2,360" is one paragraph with two bold numbers.
      expect(find.textContaining('Eaten 621 · Goal 2,360', findRichText: true), findsOneWidget);
      expect(_ringProgress(tester), closeTo(621 / 2360, 1e-9));
    });

    testWidgets('macro rows: value / goal g and a bar each, in macro colours', (tester) async {
      await _pump(tester, _stats(), _settings());
      expect(find.text('Protein'), findsOneWidget);
      expect(find.text('Carbs'), findsOneWidget);
      expect(find.text('Fat'), findsOneWidget);
      expect(find.textContaining('29 / 129 g', findRichText: true), findsOneWidget);
      expect(find.textContaining('88 / 313 g', findRichText: true), findsOneWidget);
      expect(find.textContaining('20 / 66 g', findRichText: true), findsOneWidget);
      final bars = tester.widgetList<MetricBar>(find.byType(MetricBar)).toList();
      expect(bars.map((b) => b.progress), [29 / 129, 88 / 313, 20 / 66]);
    });

    testWidgets('a protein-coloured chip says how much protein is missing', (tester) async {
      await _pump(tester, _stats(), _settings());
      expect(find.text('100 g to go'), findsOneWidget);
      expect(find.byType(TintedChip), findsOneWidget);
    });

    testWidgets('no chip once the protein goal is reached', (tester) async {
      await _pump(tester, _stats(protein: 140), _settings());
      expect(find.byType(TintedChip), findsNothing);
    });
  });

  group('over the goal', () {
    testWidgets('the number becomes the overage and the ring runs a second lap', (tester) async {
      await _pump(tester, _stats(kcal: 2572), _settings());
      expect(find.text('212'), findsOneWidget);
      expect(find.text('kcal over'), findsOneWidget);
      expect(find.text('kcal left'), findsNothing);
      expect(_ringProgress(tester), greaterThan(1));
    });

    testWidgets('exactly on the goal is "0 kcal left", not over', (tester) async {
      await _pump(tester, _stats(kcal: 2360), _settings());
      expect(find.text('0'), findsOneWidget);
      expect(find.text('kcal left'), findsOneWidget);
    });
  });

  group('without goals', () {
    testWidgets('no calorie goal: an empty ring, the eaten number, no "Eaten · Goal" line', (tester) async {
      await _pump(tester, _stats(), _settings(kcal: null));
      expect(find.text('621'), findsOneWidget);
      expect(find.text('kcal eaten'), findsOneWidget);
      expect(find.textContaining('Goal', findRichText: true), findsNothing);
      expect(_ringProgress(tester), 0);
    });

    testWidgets('a macro without a goal shows its value and no bar or chip', (tester) async {
      await _pump(tester, _stats(), _settings(protein: null));
      expect(find.textContaining('29 g', findRichText: true), findsOneWidget);
      expect(find.byType(MetricBar), findsNWidgets(2));
      expect(find.byType(TintedChip), findsNothing);
    });
  });

  testWidgets('screen readers get one sentence, not the animating digits', (tester) async {
    final handle = tester.ensureSemantics();
    await _pump(tester, _stats(), _settings());
    expect(find.bySemanticsLabel('1,739 kilocalories left'), findsOneWidget);
    handle.dispose();
  });

  testWidgets('tapping the card calls onTap', (tester) async {
    var taps = 0;
    await _pump(tester, _stats(), _settings(), onTap: () => taps++);
    await tester.tap(find.byType(CalorieHeroCard));
    expect(taps, 1);
  });

  group('Hungarian', () {
    testWidgets('canvas 1.3 copy: kcal maradt · Evett · Cél · még 100 g', (tester) async {
      await _pump(tester, _stats(), _settings(), locale: const Locale('hu'));
      // intl groups Hungarian thousands with a non-breaking space.
      final f = LifeyFormat('hu');
      expect(find.text(f.integer(1739)), findsOneWidget);
      expect(find.text('kcal maradt'), findsOneWidget);
      expect(find.textContaining('Evett 621 · Cél ${f.integer(2360)}', findRichText: true), findsOneWidget);
      expect(find.text('Fehérje'), findsOneWidget);
      expect(find.text('Szénhidrát'), findsOneWidget);
      expect(find.text('még 100 g'), findsOneWidget);
    });

    for (final width in [411.0, 360.0]) {
      for (final scale in [1.0, 1.3]) {
        for (final theme in {'dark': AppTheme.dark, 'light': AppTheme.light}.entries) {
          testWidgets('fits without overflow — ${theme.key}, ${width.round()} dp, ×$scale',
              (tester) async {
            await _pump(
              tester,
              _stats(),
              _settings(),
              locale: const Locale('hu'),
              textScale: scale,
              width: width,
              theme: theme.value,
            );
            expect(tester.takeException(), isNull);
            // Nothing is clipped with an ellipsis.
            for (final t in tester.widgetList<Text>(find.byType(Text))) {
              expect(t.overflow, isNot(TextOverflow.ellipsis));
            }
            expect(find.text('Szénhidrát'), findsOneWidget);
          });
        }
      }
    }

    testWidgets('at ×1.3 the value drops under the label instead of truncating', (tester) async {
      await _pump(tester, _stats(), _settings(), locale: const Locale('hu'), textScale: 1.3, width: 360);
      final label = tester.getTopLeft(find.text('Szénhidrát'));
      final value = tester.getTopLeft(find.textContaining('88 / 313 g', findRichText: true));
      expect(value.dy, greaterThan(label.dy), reason: 'wrapped below the label');
    });
  });
}
