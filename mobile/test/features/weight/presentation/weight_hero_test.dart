import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifey/core/theme/app_theme.dart';
import 'package:lifey/core/theme/app_tokens.dart';
import 'package:lifey/features/onboarding/data/user_details_repository.dart';
import 'package:lifey/features/onboarding/domain/user_details.dart';
import 'package:lifey/features/weight/application/weight_controller.dart';
import 'package:lifey/features/weight/application/weight_headline.dart';
import 'package:lifey/features/weight/domain/weight_entry.dart';
import 'package:lifey/features/weight/presentation/widgets/weight_goal_band.dart';
import 'package:lifey/features/weight/presentation/widgets/weight_hero_header.dart';
import 'package:lifey/l10n/app_localizations.dart';
import 'package:lifey/shared/widgets/ds/metric_bar.dart';

/// R4.1: the weight hero (64 px number, two change chips) and the goal band,
/// driven through the real providers — goal from `/user-details`, weigh-ins from
/// the local list.

class _FakeWeights extends WeightController {
  _FakeWeights(this._entries);

  final List<WeightEntry> _entries;

  @override
  Stream<List<WeightEntry>> build() => Stream.value(_entries);
}

final _today = DateTime.now();
DateTime _day(int daysAgo) => DateTime(_today.year, _today.month, _today.day).subtract(Duration(days: daysAgo));

WeightEntry _e(int daysAgo, double kg) => WeightEntry(
      clientId: 'w$daysAgo',
      date: _day(daysAgo),
      weight: kg,
      recordedAt: _day(daysAgo).add(const Duration(hours: 7, minutes: 2)),
    );

/// Newest first.
final _canvas = [_e(0, 64.5), _e(1, 64.6), _e(20, 65.4), _e(60, 67.9)];

UserDetails _details(double goal) => UserDetails(
      gender: Gender.female,
      birthDate: DateTime(1995, 5, 5),
      heightCm: 170,
      activityLevel: ActivityLevel.moderate,
      primaryGoal: PrimaryGoal.loseWeight,
      targetWeightKg: goal,
    );

Future<void> _pump(
  WidgetTester tester, {
  required List<WeightEntry> entries,
  double? goal,
  Locale locale = const Locale('en'),
  double width = 411,
  double textScale = 1,
  ThemeData? theme,
}) async {
  tester.view.physicalSize = Size(width * 2.625, 923 * 2.625);
  tester.view.devicePixelRatio = 2.625;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(ProviderScope(
    overrides: [
      weightControllerProvider.overrideWith(() => _FakeWeights(entries)),
      userDetailsProvider.overrideWith((ref) async => goal == null ? null : _details(goal)),
    ],
    child: MaterialApp(
      theme: theme ?? AppTheme.dark,
      locale: locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(textScale)),
        child: child!,
      ),
      home: Scaffold(
        body: Consumer(builder: (context, ref, _) {
          final headline = ref.watch(weightHeadlineProvider);
          if (headline == null) return const SizedBox.shrink();
          return SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(children: [
              WeightHeroHeader(headline: headline),
              const SizedBox(height: 16),
              WeightGoalBand(headline: headline),
            ]),
          );
        }),
      ),
    ),
  ));
  await tester.pumpAndSettle();
}

void main() {
  group('hero header', () {
    testWidgets('overline with the time, the weight at 64 px, the two changes', (tester) async {
      await _pump(tester, entries: _canvas);

      expect(find.text('Current · today 07:02'), findsOneWidget);
      final rich = tester.widgetList<Text>(find.byType(Text)).firstWhere((t) => t.textSpan?.toPlainText() == '64.5 kg');
      expect((rich.textSpan! as TextSpan).style!.fontSize, 64);
      expect(find.text('0.1 today'), findsOneWidget); // ↓ 64.5 vs 64.6
      expect(find.byIcon(Icons.south_rounded), findsNWidgets(2));
      expect(find.text('3.4 in 30 d'), findsNothing); // 67.9 is 60 days old, not in the window
      expect(find.text('0.9 in 30 d'), findsOneWidget); // 65.4 → 64.5
    });

    Color? chipColor(WidgetTester tester, String text) {
      final chip = tester.widget<Container>(find.ancestor(of: find.text(text), matching: find.byType(Container)).first);
      return (chip.decoration as BoxDecoration).color;
    }

    int rgb(Color c) => c.toARGB32() & 0xFFFFFF;

    testWidgets('the 30-day change is the improvement green when it moved toward the goal', (tester) async {
      await _pump(tester, entries: _canvas, goal: 62);

      expect(rgb(chipColor(tester, '0.9 in 30 d')!), rgb(AppMetricColors.dark.improvement));
    });

    testWidgets('... and the calorie orange when it moved away from it', (tester) async {
      // a gain while the goal is to lose
      await _pump(tester, entries: [_e(0, 66), _e(20, 65), _e(60, 67.9)], goal: 62);

      expect(rgb(chipColor(tester, '1.0 in 30 d')!), rgb(AppMetricColors.dark.increase));
    });

    testWidgets('without a goal the changes keep the direction colours', (tester) async {
      await _pump(tester, entries: _canvas);

      expect(rgb(chipColor(tester, '0.9 in 30 d')!), rgb(AppMetricColors.dark.decrease));
    });

    testWidgets('a single entry: just the number, no chips', (tester) async {
      await _pump(tester, entries: [_e(0, 64.5)]);

      expect(find.text('Current · today 07:02'), findsOneWidget);
      expect(find.byIcon(Icons.south_rounded), findsNothing);
      expect(find.byIcon(Icons.north_rounded), findsNothing);
    });

    testWidgets('the latest entry is older: its date, and "since last"', (tester) async {
      await _pump(tester, entries: [_e(3, 64.2), _e(5, 64.6)]);

      expect(find.textContaining('Current · '), findsOneWidget);
      expect(find.textContaining('today'), findsNothing);
      expect(find.text('0.4 since last'), findsOneWidget);
    });
  });

  group('goal band', () {
    testWidgets('start, goal and what is left over a track at 58 %', (tester) async {
      await _pump(tester, entries: _canvas, goal: 62);

      expect(find.text('Start 67.9'), findsOneWidget);
      expect(find.textContaining('Goal '), findsOneWidget);
      expect(find.textContaining('62.0 kg'), findsOneWidget);
      expect(find.textContaining('2.5 kg to go'), findsOneWidget);
      expect(tester.widget<MetricBar>(find.byType(MetricBar)).progress, closeTo(3.4 / 5.9, 1e-6));
    });

    testWidgets('no goal: a "Set a goal weight" action instead of zeros', (tester) async {
      await _pump(tester, entries: _canvas);

      expect(find.text('Set a goal weight'), findsOneWidget);
      expect(find.byType(MetricBar), findsNothing);
      expect(find.textContaining('to go'), findsNothing);
    });

    testWidgets('reached: says so instead of counting down', (tester) async {
      await _pump(tester, entries: [_e(0, 61.8), _e(60, 67.9)], goal: 62);

      expect(find.textContaining('Goal reached'), findsOneWidget);
      expect(find.textContaining('to go'), findsNothing);
      expect(tester.widget<MetricBar>(find.byType(MetricBar)).progress, 1);
    });

    testWidgets('the projection line of docs/76 stays under the track', (tester) async {
      final steady = [for (var i = 0; i < 30; i++) _e(i, 90 - 0.1 * (29 - i))];
      await _pump(tester, entries: steady, goal: 82);

      expect(find.textContaining('At this rate, around'), findsOneWidget);
      expect(find.textContaining('kg/week'), findsOneWidget);
    });
  });

  for (final width in [411.0, 360.0]) {
    testWidgets('no overflow at ${width.toInt()} dp, text x1.3, HU, light', (tester) async {
      await _pump(tester,
          entries: _canvas, goal: 62, locale: const Locale('hu'), width: width, textScale: 1.3, theme: AppTheme.light);

      final error = tester.takeException();
      expect(error is FlutterError ? error.toStringDeep() : error, isNull);
      expect(find.textContaining('Kezdet 67,9'), findsOneWidget);
    });
  }
}
