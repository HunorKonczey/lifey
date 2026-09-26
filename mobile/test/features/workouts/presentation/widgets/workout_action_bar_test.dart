import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifey/core/theme/app_theme.dart';
import 'package:lifey/features/workouts/presentation/widgets/workout_action_bar.dart';
import 'package:lifey/l10n/app_localizations.dart';

Future<void> _pump(
  WidgetTester tester, {
  bool saving = false,
  VoidCallback? onFinish,
  Locale locale = const Locale('en'),
  double textScale = 1,
  double width = 411,
  double safeBottom = 24,
}) async {
  tester.view.physicalSize = Size(width * 2.625, 923 * 2.625);
  tester.view.devicePixelRatio = 2.625;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      child: MaterialApp(
        theme: AppTheme.dark,
        locale: locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: TextScaler.linear(textScale),
            padding: EdgeInsets.only(bottom: safeBottom),
            viewPadding: EdgeInsets.only(bottom: safeBottom),
          ),
          child: child!,
        ),
        home: Scaffold(
          body: Stack(
            children: [
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: WorkoutActionBar(saving: saving, onFinish: onFinish ?? () {}),
              ),
            ],
          ),
        ),
      ),
    ),
  );
  await tester.pump();
}

void main() {
  testWidgets('the music button and "Finish workout" with the flag icon, side by side', (tester) async {
    await _pump(tester);

    expect(find.text('Finish workout'), findsOneWidget);
    expect(find.byIcon(Icons.flag_rounded), findsOneWidget);
    expect(find.byIcon(Icons.check), findsNothing); // never confusable with a set's check
    final finish = tester.getRect(find.byType(FilledButton));
    final music = tester.getRect(find.byTooltip('Music'));
    expect(music.right, lessThan(finish.left));
    expect(music.size, const Size(60, 60));
    expect(finish.height, kWorkoutActionBarHeight);
  });

  testWidgets('the bar sits above the bottom safe area', (tester) async {
    await _pump(tester, safeBottom: 34);

    final finish = tester.getRect(find.byType(FilledButton));
    expect(finish.bottom, lessThanOrEqualTo(923 - 34));
    // ... with the 16 dp gap under it.
    expect(finish.bottom, closeTo(923 - 34 - 16, 0.5));
  });

  testWidgets('reservedHeight is what the list must leave under its last item', (tester) async {
    await _pump(tester, safeBottom: 34);

    final finish = tester.getRect(find.byType(FilledButton));
    // the reserved zone (bar + gap + safe area + a gap above) covers the bar
    expect(WorkoutActionBar.reservedHeight(34), greaterThanOrEqualTo(923 - finish.top));
  });

  testWidgets('Finish calls back; while saving it shows a spinner and does nothing', (tester) async {
    var finishes = 0;
    await _pump(tester, onFinish: () => finishes++);
    await tester.tap(find.text('Finish workout'));
    expect(finishes, 1);

    await _pump(tester, saving: true, onFinish: () => finishes++);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.byIcon(Icons.flag_rounded), findsNothing);
    await tester.tap(find.text('Finish workout'), warnIfMissed: false);
    expect(finishes, 1);
  });

  for (final width in [411.0, 360.0]) {
    testWidgets('no overflow at ${width.toInt()} dp, text x1.3, HU', (tester) async {
      await _pump(tester, locale: const Locale('hu'), textScale: 1.3, width: width);

      expect(tester.takeException(), isNull);
      expect(find.text('Edzés befejezése'), findsOneWidget);
    });
  }
}
