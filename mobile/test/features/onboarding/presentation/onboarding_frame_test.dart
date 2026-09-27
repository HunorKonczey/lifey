import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifey/core/theme/app_theme.dart';
import 'package:lifey/features/onboarding/presentation/onboarding_screen.dart';
import 'package:lifey/features/settings/application/settings_controller.dart';
import 'package:lifey/features/settings/domain/user_settings.dart';
import 'package:lifey/l10n/app_localizations.dart';

class _FakeSettings extends SettingsController {
  @override
  Stream<UserSettings> build() => Stream.value(const UserSettings.defaults());
}

Future<void> _pump(
  WidgetTester tester, {
  Locale locale = const Locale('en'),
  Size size = const Size(390, 844),
  double textScale = 1,
  ThemeData? theme,
}) async {
  tester.view.physicalSize = size * 2;
  tester.view.devicePixelRatio = 2;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [settingsControllerProvider.overrideWith(_FakeSettings.new)],
      child: MaterialApp(
        theme: theme ?? AppTheme.dark,
        locale: locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(textScale)),
          child: child!,
        ),
        home: const OnboardingScreen(),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  // The desktop test host has no health store, so the wizard has five steps.
  const total = 5;

  testWidgets('the welcome step says "Step 1 of N" and offers Skip and one primary button', (tester) async {
    await _pump(tester);

    expect(find.text('Step 1 of $total'), findsOneWidget);
    expect(find.text('Skip'), findsOneWidget);
    expect(find.text("Let's personalize your plan"), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Get started'), findsOneWidget);
    expect(find.text('Back'), findsNothing);
    // One progress segment per step.
    expect(find.byType(AnimatedContainer), findsNWidgets(total));
  });

  testWidgets('every step shows its number; Back returns and Next is refused without an answer', (tester) async {
    await _pump(tester);

    await tester.tap(find.text('Get started'));
    await tester.pumpAndSettle();
    expect(find.text('Step 2 of $total'), findsOneWidget);
    expect(find.text('About you'), findsOneWidget);
    expect(find.widgetWithText(OutlinedButton, 'Back'), findsOneWidget);

    await tester.tap(find.widgetWithText(FilledButton, 'Next'));
    await tester.pumpAndSettle();
    expect(find.text('Step 2 of $total'), findsOneWidget); // still here
    expect(find.text('Please choose an option for every field'), findsOneWidget);

    await tester.tap(find.text('Back'));
    await tester.pumpAndSettle();
    expect(find.text('Step 1 of $total'), findsOneWidget);
  });

  for (final (name, locale, scale, start) in [
    ('English at 360 dp × 1.3', const Locale('en'), 1.3, 'Get started'),
    ('Hungarian at 360 dp × 1.3', const Locale('hu'), 1.3, 'Kezdjük'),
  ]) {
    for (final (mode, theme) in [('dark', AppTheme.dark), ('light', AppTheme.light)]) {
      testWidgets('fits without overflow: $name, $mode', (tester) async {
        await _pump(tester, locale: locale, size: const Size(360, 740), textScale: scale, theme: theme);
        expect(tester.takeException(), isNull);
        await tester.tap(find.widgetWithText(FilledButton, start));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      });
    }
  }
}
