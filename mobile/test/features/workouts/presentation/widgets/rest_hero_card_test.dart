import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifey/core/theme/app_theme.dart';
import 'package:lifey/features/workouts/presentation/widgets/rest_hero_card.dart';
import 'package:lifey/l10n/app_localizations.dart';
import 'package:lifey/shared/widgets/ds/metric_bar.dart';

final _last = DateTime(2026, 9, 24, 12);

RestState _at(int secondsAfter, {int target = 150, Duration adjustment = Duration.zero}) => RestState.at(
      now: _last.add(Duration(seconds: secondsAfter)),
      lastSetAt: _last,
      targetSeconds: target,
      adjustment: adjustment,
    );

Future<void> _pump(
  WidgetTester tester, {
  int elapsed = 62,
  int target = 150,
  bool enabled = true,
  Duration adjustment = Duration.zero,
  String? next = 'Next: Bench Press · set 2 · 47.5 kg × 8',
  VoidCallback? onAdd,
  VoidCallback? onSkip,
  Locale locale = const Locale('en'),
  double textScale = 1,
  double width = 411,
  bool disableAnimations = false,
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
        data: MediaQuery.of(context).copyWith(
          textScaler: TextScaler.linear(textScale),
          disableAnimations: disableAnimations,
        ),
        child: child!,
      ),
      home: Scaffold(
        body: Padding(
          padding: const EdgeInsets.all(20),
          child: RestHeroCard(
            lastSetAt: _last,
            now: _last.add(Duration(seconds: elapsed)),
            enabled: enabled,
            targetSeconds: enabled ? target : null,
            adjustment: adjustment,
            nextLine: next,
            onAddFifteen: onAdd ?? () {},
            onSkip: onSkip ?? () {},
          ),
        ),
      ),
    ),
  );
  await tester.pump();
}

void main() {
  group('RestState', () {
    test('counts down: 150 s target, 62 s in → 1:28 left, 59 % of the bar', () {
      final s = _at(62);
      expect(s.remaining, const Duration(seconds: 88));
      expect(s.remainingFraction, closeTo(88 / 150, 1e-9));
      expect(s.isOvertime, isFalse);
      expect(s.isFinalSeconds, isFalse);
    });

    test('the last five seconds — inclusive — are the final seconds', () {
      expect(_at(144).isFinalSeconds, isFalse); // 6 s left
      expect(_at(145).isFinalSeconds, isTrue); // 5 s left
      expect(_at(149).isFinalSeconds, isTrue);
    });

    test('reaching the target is overtime, and the overage counts up from zero', () {
      expect(_at(150).isOvertime, isTrue);
      expect(_at(150).overage, Duration.zero);
      expect(_at(162).overage, const Duration(seconds: 12));
      expect(_at(150).isFinalSeconds, isFalse);
      expect(_at(162).remaining, Duration.zero);
      expect(_at(162).remainingFraction, 0);
    });

    test('+15 s taps push the target out', () {
      final s = _at(150, adjustment: const Duration(seconds: 30));
      expect(s.isOvertime, isFalse);
      expect(s.remaining, const Duration(seconds: 30));
    });

    test('a zero target is immediately overtime with an empty bar', () {
      final s = _at(0, target: 0);
      expect(s.isOvertime, isTrue);
      expect(s.remainingFraction, 0);
    });
  });

  testWidgets('the canvas card: REST, 1:28, +15 s, Skip, a draining bar and the next set', (tester) async {
    await _pump(tester);

    expect(find.text('REST'), findsOneWidget);
    expect(find.text('1:28'), findsOneWidget);
    expect(find.text('+15 s'), findsOneWidget);
    expect(find.text('Skip'), findsOneWidget);
    expect(find.text('Next: Bench Press · set 2 · 47.5 kg × 8'), findsOneWidget);
    final bar = tester.widget<MetricBar>(find.byType(MetricBar));
    expect(bar.progress, closeTo(88 / 150, 1e-9));
    expect(tester.getSize(find.text('1:28')).height, greaterThan(40)); // the 44 px number
  });

  testWidgets('+15 s and Skip call their callbacks', (tester) async {
    var adds = 0;
    var skips = 0;
    await _pump(tester, onAdd: () => adds++, onSkip: () => skips++);

    await tester.tap(find.text('+15 s'));
    await tester.tap(find.text('Skip'));

    expect(adds, 1);
    expect(skips, 1);
  });

  testWidgets('the buttons are at least 48 dp tall', (tester) async {
    await _pump(tester);

    expect(tester.getSize(find.widgetWithText(InkWell, '+15 s')).height, greaterThanOrEqualTo(48));
    expect(tester.getSize(find.widgetWithText(InkWell, 'Skip')).height, greaterThanOrEqualTo(48));
  });

  testWidgets('the last five seconds change the number colour, and it pulses on odd seconds', (tester) async {
    await _pump(tester, elapsed: 147); // 3 s left
    final colour = tester.widget<Text>(find.text('0:03')).style!.color;
    await _pump(tester, elapsed: 62);
    final normal = tester.widget<Text>(find.text('1:28')).style!.color;

    expect(colour, isNot(normal));
    await _pump(tester, elapsed: 147);
    expect(tester.widget<AnimatedScale>(find.byType(AnimatedScale)).scale, greaterThan(1)); // 3 s: odd
    await _pump(tester, elapsed: 148);
    expect(tester.widget<AnimatedScale>(find.byType(AnimatedScale)).scale, 1); // 2 s: even
  });

  testWidgets('reduced motion: no pulse animation time', (tester) async {
    await _pump(tester, elapsed: 147, disableAnimations: true);

    expect(tester.widget<AnimatedScale>(find.byType(AnimatedScale)).duration, Duration.zero);
  });

  testWidgets('overtime counts up as "+0:12", keeps Skip and drops +15 s', (tester) async {
    await _pump(tester, elapsed: 162);

    expect(find.text('+0:12'), findsOneWidget);
    expect(find.text('Skip'), findsOneWidget);
    expect(find.text('+15 s'), findsNothing);
    expect(tester.widget<MetricBar>(find.byType(MetricBar)).progress, 0);
  });

  testWidgets('with the rest timer off: an elapsed count-up, no buttons, no bar', (tester) async {
    await _pump(tester, enabled: false, elapsed: 75);

    expect(find.text('1:15'), findsOneWidget);
    expect(find.text('Skip'), findsNothing);
    expect(find.text('+15 s'), findsNothing);
    expect(find.byType(MetricBar), findsNothing);
  });

  testWidgets('nothing left to do: no "Next" line', (tester) async {
    await _pump(tester, next: null);

    expect(find.textContaining('Next:'), findsNothing);
  });

  for (final width in [411.0, 360.0]) {
    testWidgets('no overflow at ${width.toInt()} dp, text x1.3, HU, long next line', (tester) async {
      await _pump(
        tester,
        locale: const Locale('hu'),
        textScale: 1.3,
        width: width,
        next: 'Következik: Ferde padon nyomás súlyzóval · 2. szett · 47,5 kg × 8',
      );

      expect(tester.takeException(), isNull);
      expect(find.text('Kihagyás'), findsOneWidget);
    });
  }
}
