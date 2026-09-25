import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifey/core/theme/app_theme.dart';
import 'package:lifey/core/theme/app_type.dart';
import 'package:lifey/shared/widgets/ds/metric_value.dart';

void main() {
  final text = AppTheme.dark.textTheme;

  group('type scale (D-R0.7)', () {
    test('design roles sit in their slots', () {
      // role: slot → (size, line height, weight)
      final expected = <String, (TextStyle?, double, double, FontWeight)>{
        'display-xl': (text.displayLarge, 72, 68, FontWeight.w800),
        'display': (text.displayMedium, 48, 48, FontWeight.w800),
        'headline': (text.headlineMedium, 30, 36, FontWeight.w800),
        'title': (text.titleLarge, 20, 26, FontWeight.w700),
        'title-s': (text.titleMedium, 16, 22, FontWeight.w700),
        'body': (text.bodyMedium, 15, 22, FontWeight.w500),
        'body-s': (text.bodySmall, 13, 18, FontWeight.w500),
        'label': (text.labelSmall, 12, 16, FontWeight.w700),
      };
      expected.forEach((role, e) {
        final (style, size, line, weight) = e;
        expect(style!.fontSize, size, reason: role);
        expect(style.fontSize! * style.height!, closeTo(line, 0.001), reason: role);
        expect(style.fontWeight, weight, reason: role);
        expect(style.fontFamily, AppType.fontFamily, reason: role);
      });
    });

    test('no slot falls back to a 400-weight Material default', () {
      final all = [
        text.displayLarge, text.displayMedium, text.displaySmall,
        text.headlineLarge, text.headlineMedium, text.headlineSmall,
        text.titleLarge, text.titleMedium, text.titleSmall,
        text.bodyLarge, text.bodyMedium, text.bodySmall,
        text.labelLarge, text.labelMedium, text.labelSmall,
      ];
      for (final s in all) {
        expect(s!.fontWeight!.value, greaterThanOrEqualTo(500));
      }
    });

    test('display styles are tabular and tracked tighter', () {
      for (final s in [text.displayLarge, text.displayMedium, text.displaySmall]) {
        expect(s!.fontFeatures, AppType.tabular);
        expect(s.letterSpacing, lessThan(0));
      }
    });

    test('the section label is caps tracking, labelSmall is not', () {
      expect(AppType.sectionLabel().letterSpacing, closeTo(0.96, 0.001));
      expect(text.labelSmall!.letterSpacing ?? 0, 0);
    });

    // Theme.of() localizes the text theme by merging Material's geometry
    // under it; an untracked slot left null picked up +0.25–0.5 px there
    // (R0 emulator review). Read through Theme.of, as widgets do.
    for (final (name, theme) in [('dark', AppTheme.dark), ('light', AppTheme.light)]) {
      testWidgets('untracked slots stay at 0 through Theme.of ($name)', (tester) async {
        late TextTheme resolved;
        await tester.pumpWidget(MaterialApp(
          theme: theme,
          home: Builder(builder: (context) {
            resolved = Theme.of(context).textTheme;
            return const SizedBox();
          }),
        ));
        final untracked = {
          'titleMedium': resolved.titleMedium, 'titleSmall': resolved.titleSmall,
          'bodyLarge': resolved.bodyLarge, 'bodyMedium': resolved.bodyMedium, 'bodySmall': resolved.bodySmall,
          'labelLarge': resolved.labelLarge, 'labelMedium': resolved.labelMedium, 'labelSmall': resolved.labelSmall,
        };
        untracked.forEach((slot, s) => expect(s!.letterSpacing, 0, reason: slot));
        expect(resolved.displayLarge!.letterSpacing, closeTo(-0.03 * 72, 0.001));
      });
    }
  });

  group('AppType.number', () {
    test('tabular, 800, −3 % tracking', () {
      final s = AppType.number(64);
      expect(s.fontFeatures, AppType.tabular);
      expect(s.fontWeight, FontWeight.w800);
      expect(s.letterSpacing, closeTo(-1.92, 0.001));
    });

    test('unit is ~42 % of the number', () {
      expect(AppType.unit(50).fontSize, closeTo(21, 0.001));
    });

    test('unit resets the tracking it would inherit from the number', () {
      // A child span of the number: without an explicit 0 it inherits
      // −3 % and the space before it all but disappears ("621/2 360kcal").
      expect(AppType.unit(28).letterSpacing, 0);
    });
  });

  group('MetricValue', () {
    Widget host(Widget child, {double scale = 1}) => MaterialApp(
          theme: AppTheme.dark,
          home: MediaQuery(
            data: MediaQueryData(textScaler: TextScaler.linear(scale)),
            child: Scaffold(body: Center(child: child)),
          ),
        );

    testWidgets('does not grow with dynamic type (D-R0.8)', (tester) async {
      await tester.pumpWidget(host(const MetricValue(value: '1 739', unit: 'kcal'), scale: 1.3));
      final paragraph = tester.widget<RichText>(find.byType(RichText).first);
      expect(paragraph.textScaler.scale(34), 34);
    });

    testWidgets('may still shrink below 100 %', (tester) async {
      await tester.pumpWidget(host(const MetricValue(value: '64.5', unit: 'kg'), scale: 0.85));
      final paragraph = tester.widget<RichText>(find.byType(RichText).first);
      expect(paragraph.textScaler.scale(34), closeTo(28.9, 0.01));
    });

    testWidgets('reads as one phrase to a screen reader', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(host(const MetricValue(value: '64.5', unit: 'kg')));
      expect(find.bySemanticsLabel('64.5 kg'), findsOneWidget);
      await tester.pumpWidget(host(const MetricValue(
        value: '1 739',
        unit: 'kcal',
        semanticsLabel: '1739 kilocalories left',
      )));
      expect(find.bySemanticsLabel('1739 kilocalories left'), findsOneWidget);
      handle.dispose();
    });

    testWidgets('unit uses the secondary text colour', (tester) async {
      await tester.pumpWidget(host(const MetricValue(value: '64.5', unit: 'kg', size: 50)));
      // Text.rich wraps the widget's span in one more span carrying the
      // DefaultTextStyle.
      final outer = tester.widget<RichText>(find.byType(RichText).first).text as TextSpan;
      final span = outer.children!.single as TextSpan;
      final unit = span.children!.last as TextSpan;
      expect(unit.style!.color, const Color(0xFFB6B5A5));
      expect(unit.style!.fontSize, closeTo(21, 0.001));
      expect(unit.style!.letterSpacing, 0);
    });
  });
}
