import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifey/core/theme/app_theme.dart';
import 'package:lifey/core/theme/app_tokens.dart';
import 'package:lifey/features/workouts/domain/hr_zone_breakdown.dart';
import 'package:lifey/features/workouts/domain/workout_session.dart';
import 'package:lifey/features/workouts/presentation/widgets/cardio_detail_hero.dart';
import 'package:lifey/features/workouts/presentation/widgets/hr_zone_panel.dart';
import 'package:lifey/l10n/app_localizations.dart';
import 'package:lifey/l10n/app_localizations_en.dart';

HrZoneBreakdown _breakdown(List<int> zones, {int? grossSeconds}) {
  final int gross = grossSeconds ?? zones.fold<int>(0, (a, b) => a + b);
  final startedAt = DateTime(2026, 9, 22, 7, 45);
  return HrZoneBreakdown.fromSession(WorkoutSession(
    clientId: 'c',
    exercises: const [],
    sets: const [],
    startedAt: startedAt,
    finishedAt: startedAt.add(Duration(seconds: gross)),
    sessionKind: 'CARDIO',
    activityType: 'RUNNING',
    movingSeconds: gross,
    cardio: CardioMetrics(
      hrZone1Seconds: zones[0],
      hrZone2Seconds: zones[1],
      hrZone3Seconds: zones[2],
      hrZone4Seconds: zones[3],
      hrZone5Seconds: zones[4],
    ),
  ))!;
}

Future<void> _pump(
  WidgetTester tester,
  Widget child, {
  Locale locale = const Locale('en'),
  double width = 411,
  double textScale = 1,
  ThemeData? theme,
}) async {
  tester.view.physicalSize = Size(width * 2.625, 1400 * 2.625);
  tester.view.devicePixelRatio = 2.625;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp(
    theme: theme ?? AppTheme.dark,
    locale: locale,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    builder: (context, c) => MediaQuery(
      data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(textScale)),
      child: c!,
    ),
    home: Scaffold(body: SingleChildScrollView(padding: const EdgeInsets.all(20), child: child)),
  ));
  await tester.pump();
}

void main() {
  group('HrZonePanel (canvas Lifey 3 › 3.3)', () {
    // 2:46 / 8:18 / 9:41 / 5:32 / 1:23 — the canvas's run
    final canvas = _breakdown(const [166, 498, 581, 332, 83]);

    testWidgets('title, verdict, five rows: "Z3 · Tempo · 9:41 · 35 %"', (tester) async {
      await _pump(tester, HrZonePanel(breakdown: canvas));

      expect(find.text('Heart rate zones'), findsOneWidget);
      for (final row in [
        ('Z1', 'Warm-up', '2:46', '10%'),
        ('Z2', 'Base', '8:18', '30%'),
        ('Z3', 'Tempo', '9:41', '35%'),
        ('Z4', 'Threshold', '5:32', '20%'),
        ('Z5', 'Maximum', '1:23', '5%'),
      ]) {
        expect(find.text(row.$1), findsOneWidget);
        expect(find.text(row.$2), findsOneWidget);
        expect(find.text(row.$3), findsOneWidget);
        expect(find.text(row.$4), findsOneWidget);
      }
    });

    testWidgets('the percentages on screen add up to 100 even when plain rounding would not', (tester) async {
      // thirds: 33.3 each would round to 33 + 33 + 33 = 99
      await _pump(tester, HrZonePanel(breakdown: _breakdown(const [100, 100, 100, 0, 0])));

      final shown = [
        for (final t in tester.widgetList<Text>(find.byType(Text)))
          if (RegExp(r'^\d+%$').hasMatch(t.data ?? '')) int.parse(t.data!.replaceAll('%', '')),
      ];
      expect(shown, hasLength(5));
      expect(shown.fold(0, (a, b) => a + b), 100);
    });

    testWidgets('the footnote is in the tertiary text colour', (tester) async {
      await _pump(tester, HrZonePanel(breakdown: canvas));

      final l10n = AppLocalizationsEn();
      final note = tester.widget<Text>(find.text(l10n.hrZoneSourceNote));
      final palette = AppPalette.dark;
      expect(note.style!.color, palette.text3);
    });

    testWidgets('zone codes take the zone colours, from the tokens', (tester) async {
      await _pump(tester, HrZonePanel(breakdown: canvas));

      const mc = AppMetricColors.dark;
      final expected = [mc.weight, mc.protein, mc.carbs, mc.calories, mc.heart];
      for (var z = 1; z <= 5; z++) {
        expect(tester.widget<Text>(find.text('Z$z')).style!.color, expected[z - 1]);
      }
    });

    testWidgets('partial data: the unmeasured remainder is called out', (tester) async {
      await _pump(tester, HrZonePanel(breakdown: _breakdown(const [100, 100, 100, 0, 0], grossSeconds: 600)));

      expect(find.byIcon(Icons.timelapse), findsOneWidget);
    });

    for (final width in [411.0, 360.0]) {
      for (final scale in [1.0, 1.3]) {
        testWidgets('no overflow at ${width.toInt()} dp, text x$scale, HU, light', (tester) async {
          await _pump(tester, HrZonePanel(breakdown: canvas),
              locale: const Locale('hu'), width: width, textScale: scale, theme: AppTheme.light);

          final error = tester.takeException();
          expect(error is FlutterError ? error.toStringDeep() : error, isNull);
        });
      }
    }
  });

  group('CardioDetailHero and CardioMetricStrip', () {
    testWidgets('a 52 px distance, the duration beside it', (tester) async {
      await _pump(tester, const CardioDetailHero(distance: '5.21 km', duration: '27:40', durationLabel: 'Duration'));

      final text = tester.widgetList<Text>(find.byType(Text)).firstWhere((t) => t.textSpan?.toPlainText() == '5.21 km');
      expect(((text.textSpan! as TextSpan).children!.first as TextSpan).style!.fontSize, 52);
      expect(find.text('27:40'), findsOneWidget);
      expect(find.text('Duration'), findsOneWidget);
      expect(tester.getCenter(find.text('27:40')).dx, greaterThan(tester.getCenter(find.text('5.21 km')).dx));
    });

    testWidgets('tapping the distance edits it; an edited one carries its tag', (tester) async {
      var taps = 0;
      await _pump(
        tester,
        CardioDetailHero(
          distance: '5.21 km',
          duration: '27:40',
          durationLabel: 'Duration',
          edited: true,
          editedLabel: 'Edited',
          onEditDistance: () => taps++,
        ),
      );

      expect(find.text('Edited'), findsOneWidget);
      await tester.tap(find.text('5.21 km'));
      expect(taps, 1);
    });

    testWidgets('the strip: uniform sentence-case labels under the numbers, colours on HR and calories', (tester) async {
      await _pump(
        tester,
        CardioMetricStrip(metrics: [
          const CardioStripMetric(label: 'PACE', value: '5:19 /km'),
          const CardioStripMetric(label: 'ELEVATION GAIN', value: '78 m'),
          CardioStripMetric(label: 'HEART RATE', value: '156 bpm', color: AppMetricColors.dark.heart),
          CardioStripMetric(label: 'Calories', value: '323 kcal', color: AppMetricColors.dark.calories),
        ]),
      );

      for (final label in ['Pace', 'Elevation gain', 'Heart rate', 'Calories']) {
        expect(find.text(label), findsOneWidget, reason: label);
      }
      // one style for every label
      final styles = {
        for (final label in ['Pace', 'Elevation gain', 'Heart rate', 'Calories'])
          tester.widget<Text>(find.text(label)).style!.fontSize
      };
      expect(styles, hasLength(1));
      final hr = tester.widgetList<Text>(find.byType(Text)).firstWhere((t) => t.textSpan?.toPlainText() == '156 bpm');
      expect(((hr.textSpan! as TextSpan).children!.first as TextSpan).style!.color, AppMetricColors.dark.heart);
    });

    testWidgets('a narrow phone lays the strip out two by two', (tester) async {
      await _pump(
        tester,
        const CardioMetricStrip(metrics: [
          CardioStripMetric(label: 'PACE', value: '5:19 /km'),
          CardioStripMetric(label: 'ELEVATION GAIN', value: '78 m'),
          CardioStripMetric(label: 'HEART RATE', value: '156 bpm'),
          CardioStripMetric(label: 'CALORIES', value: '323 kcal'),
        ]),
        width: 320,
      );

      expect(tester.getTopLeft(find.text('Pace')).dy, tester.getTopLeft(find.text('Elevation gain')).dy);
      expect(tester.getTopLeft(find.text('Heart rate')).dy, greaterThan(tester.getTopLeft(find.text('Pace')).dy));
    });

    for (final width in [411.0, 360.0]) {
      testWidgets('no overflow at ${width.toInt()} dp, text x1.3, HU', (tester) async {
        await _pump(
          tester,
          const Column(children: [
            CardioDetailHero(distance: '12,52 km', duration: '1:27:40', durationLabel: 'Időtartam', edited: true, editedLabel: 'Szerkesztve'),
            SizedBox(height: 16),
            CardioMetricStrip(metrics: [
              CardioStripMetric(label: 'TEMPÓ', value: '10:19 /km'),
              CardioStripMetric(label: 'EMELKEDÉS', value: '1 078 m'),
              CardioStripMetric(label: 'PULZUS', value: '156 bpm'),
              CardioStripMetric(label: 'KALÓRIA', value: '1 323 kcal'),
            ]),
          ]),
          locale: const Locale('hu'),
          width: width,
          textScale: 1.3,
        );

        final error = tester.takeException();
        expect(error is FlutterError ? error.toStringDeep() : error, isNull);
      });
    }
  });
}
