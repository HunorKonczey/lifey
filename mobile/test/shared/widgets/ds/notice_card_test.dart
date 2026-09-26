import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifey/core/theme/app_theme.dart';
import 'package:lifey/core/theme/app_tokens.dart';
import 'package:lifey/features/workouts/domain/workout_template.dart';
import 'package:lifey/features/workouts/presentation/widgets/recommended_workout_card.dart';
import 'package:lifey/l10n/app_localizations.dart';
import 'package:lifey/shared/widgets/ds/list_group.dart';
import 'package:lifey/shared/widgets/ds/notice_card.dart';

Widget _app(
  Widget child, {
  ThemeData? theme,
  Locale locale = const Locale('en'),
  double textScale = 1,
  double width = 411,
}) =>
    MaterialApp(
      theme: theme ?? AppTheme.dark,
      locale: locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      builder: (context, mq) => MediaQuery(
        data: MediaQuery.of(context).copyWith(
          textScaler: TextScaler.linear(textScale),
          size: Size(width, 923),
        ),
        child: mq!,
      ),
      home: Scaffold(body: Padding(padding: const EdgeInsets.all(20), child: SingleChildScrollView(child: child))),
    );

void main() {
  testWidgets('icon holder, title, body and a 48 dp action under the text', (tester) async {
    var acted = 0;
    await tester.pumpWidget(_app(NoticeCard(
      icon: Icons.eco_rounded,
      title: 'Finish your profile',
      body: 'A few questions.',
      actionLabel: 'Set up',
      onAction: () => acted++,
    )));
    expect(find.text('Finish your profile'), findsOneWidget);
    expect(find.text('A few questions.'), findsOneWidget);
    expect(tester.getSize(find.byType(ListIconHolder)), const Size(44, 44));
    final action = find.widgetWithText(TextButton, 'Set up');
    expect(tester.getSize(action).height, greaterThanOrEqualTo(48));
    // Under the body text, not beside it.
    expect(tester.getTopLeft(action).dy, greaterThan(tester.getBottomLeft(find.text('A few questions.')).dy - 1));
    await tester.tap(action);
    expect(acted, 1);
  });

  testWidgets('the close button is a 48 dp target with a tooltip and dismisses', (tester) async {
    var dismissed = 0;
    await tester.pumpWidget(_app(NoticeCard(
      icon: Icons.info_outline_rounded,
      title: 'Notice',
      onDismiss: () => dismissed++,
      dismissTooltip: 'Dismiss',
    )));
    final close = find.byTooltip('Dismiss');
    expect(tester.getSize(close).width, greaterThanOrEqualTo(48));
    expect(tester.getSize(close).height, greaterThanOrEqualTo(48));
    await tester.tap(close);
    expect(dismissed, 1);
  });

  testWidgets('the surface is tinted with the accent — olive by default, clay when given', (tester) async {
    Color? surface() => tester
        .widgetList<DecoratedBox>(find.descendant(of: find.byType(NoticeCard), matching: find.byType(DecoratedBox)))
        .map((d) => d.decoration)
        .whereType<BoxDecoration>()
        .map((d) => d.color)
        .firstWhere((c) => c != null, orElse: () => null);

    await tester.pumpWidget(_app(const NoticeCard(icon: Icons.eco_rounded, title: 'Olive')));
    expect(surface(), Color.alphaBlend(AppTheme.dark.colorScheme.primary.withValues(alpha: 0.12), AppPalette.dark.card));

    await tester.pumpWidget(
        _app(NoticeCard(icon: Icons.info_outline_rounded, title: 'Clay', accent: AppPalette.dark.role)));
    expect(surface(), Color.alphaBlend(AppPalette.dark.role.withValues(alpha: 0.12), AppPalette.dark.card));
  });

  testWidgets('a tappable card with an overline and a trailing widget (the recommended workout)', (tester) async {
    var taps = 0;
    await tester.pumpWidget(_app(RecommendedWorkoutCard(
      template: const WorkoutTemplate(clientId: 't', name: 'Push day', exercises: []),
      onTap: () => taps++,
    )));
    expect(find.text('Recommended workout'), findsOneWidget);
    expect(find.text('Push day'), findsOneWidget);
    expect(find.byIcon(Icons.play_circle_fill_rounded), findsOneWidget);
    await tester.tap(find.text('Push day'));
    expect(taps, 1);
  });

  for (final width in [411.0, 360.0]) {
    for (final scale in [1.0, 1.3]) {
      for (final theme in {'dark': AppTheme.dark, 'light': AppTheme.light}.entries) {
        testWidgets('Hungarian fits without overflow — ${theme.key}, ${width.round()} dp, ×$scale', (tester) async {
          tester.view.physicalSize = Size(width * 2.625, 923 * 2.625);
          tester.view.devicePixelRatio = 2.625;
          addTearDown(tester.view.reset);
          await tester.pumpWidget(_app(
            NoticeCard(
              icon: Icons.eco_rounded,
              title: 'Fejezd be a profilodat, hogy a célok a te adataidra épüljenek',
              body: 'Pár kérdés, és a napi kalória- és makrócélok a te számaidból indulnak ki.',
              actionLabel: 'Beállítás megnyitása',
              onAction: () {},
              onDismiss: () {},
              dismissTooltip: 'Elrejtés',
            ),
            theme: theme.value,
            locale: const Locale('hu'),
            textScale: scale,
            width: width,
          ));
          expect(tester.takeException(), isNull);
        });
      }
    }
  }
}
