import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifey/core/theme/app_theme.dart';
import 'package:lifey/features/workouts/presentation/widgets/cardio_live_cards.dart';
import 'package:lifey/l10n/app_localizations.dart';

Future<void> _pump(
  WidgetTester tester,
  Widget child, {
  Locale locale = const Locale('en'),
  double width = 411,
  double textScale = 1,
  ThemeData? theme,
}) async {
  tester.view.physicalSize = Size(width * 2.625, 800 * 2.625);
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
    home: Scaffold(
      body: Padding(padding: const EdgeInsets.all(20), child: child),
    ),
  ));
  await tester.pump();
}

void main() {
  group('LiveMetricCard', () {
    testWidgets('label in sentence case over a number with its unit', (tester) async {
      await _pump(tester, const LiveMetricCard(label: 'DISTANCE', value: '4.52 km'));

      expect(find.text('Distance'), findsOneWidget);
      expect(find.text('4.52 km'), findsOneWidget); // one text node, number + unit
    });

    testWidgets('the number is 40 px, the unit smaller', (tester) async {
      await _pump(tester, const LiveMetricCard(label: 'PACE', value: '5:24 /km'));

      final text = tester.widgetList<Text>(find.byType(Text)).firstWhere((t) => t.textSpan?.toPlainText() == '5:24 /km');
      final spans = (text.textSpan! as TextSpan).children!.cast<TextSpan>();
      expect(spans.first.style!.fontSize, 40);
      expect(spans.last.style!.fontSize, lessThan(40));
    });

    testWidgets('the empty tile is tappable and says so with an edit glyph', (tester) async {
      var taps = 0;
      await _pump(tester, LiveMetricCard(label: 'DISTANCE', value: '—', outlined: true, onTap: () => taps++));

      expect(find.byIcon(Icons.edit_rounded), findsOneWidget);
      await tester.tap(find.text('Distance'));
      expect(taps, 1);
    });

    testWidgets('a badge sits after the label', (tester) async {
      await _pump(tester, const LiveMetricCard(label: 'DISTANCE', value: '4.52 km', badge: 'ESTIMATED'));

      expect(find.text('ESTIMATED'), findsOneWidget);
    });
  });

  group('LiveHeartRateCard', () {
    testWidgets('reading, zone chip and five zone segments', (tester) async {
      await _pump(tester, const LiveHeartRateCard(bpm: 152, zone: 3));

      expect(find.text('152 bpm'), findsOneWidget);
      expect(find.text('Zone 3 · Tempo'), findsOneWidget);
      expect(find.byIcon(Icons.favorite_rounded), findsOneWidget);
      final segments = find.byWidgetPredicate(
        (w) => w is Container && w.constraints?.maxHeight == 8 && w.decoration is BoxDecoration,
      );
      expect(segments, findsNWidgets(5));
    });

    testWidgets('only the current zone is fully lit', (tester) async {
      await _pump(tester, const LiveHeartRateCard(bpm: 152, zone: 3));

      final alphas = [
        for (final w in tester.widgetList<Container>(find.byWidgetPredicate(
          (w) => w is Container && w.constraints?.maxHeight == 8,
        )))
          ((w.decoration as BoxDecoration).color!).a,
      ];
      expect(alphas, hasLength(5));
      expect(alphas[2], 1);
      expect([alphas[0], alphas[1], alphas[3], alphas[4]].every((a) => a < 0.5), isTrue);
    });

    testWidgets('without a zone it is just the reading', (tester) async {
      await _pump(tester, const LiveHeartRateCard(bpm: 152));

      expect(find.text('152 bpm'), findsOneWidget);
      expect(find.textContaining('Zone'), findsNothing);
    });

    testWidgets('Hungarian zone chip', (tester) async {
      await _pump(tester, const LiveHeartRateCard(bpm: 176, zone: 4), locale: const Locale('hu'));

      expect(find.text('4. zóna · Küszöb'), findsOneWidget);
    });

    for (final width in [411.0, 360.0]) {
      for (final scale in [1.0, 1.3]) {
        testWidgets('no overflow at ${width.toInt()} dp, text x$scale, HU, light', (tester) async {
          await _pump(
            tester,
            const Column(children: [
              LiveHeartRateCard(bpm: 188, zone: 5),
              SizedBox(height: 12),
              Row(children: [
                Expanded(child: LiveMetricCard(label: 'TÁVOLSÁG', value: '12,52 km', badge: 'BECSÜLT')),
                SizedBox(width: 12),
                Expanded(child: LiveMetricCard(label: 'TEMPÓ', value: '10:24 /km')),
              ]),
            ]),
            locale: const Locale('hu'),
            width: width,
            textScale: scale,
            theme: AppTheme.light,
          );

          final error = tester.takeException();
          expect(error is FlutterError ? error.toStringDeep() : error, isNull);
        });
      }
    }
  });
}
