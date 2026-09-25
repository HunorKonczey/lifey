import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifey/core/theme/app_theme.dart';
import 'package:lifey/features/onboarding/presentation/onboarding_screen.dart';
import 'package:lifey/features/onboarding/presentation/widgets/option_card.dart';
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

/// Welcome → About you (gender + birth date) → Body (height, weight) → the
/// lifestyle step, in English.
Future<void> _toLifestyle(WidgetTester tester) async {
  await tester.tap(find.text('Get started'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Male'));
  await tester.tap(find.text('Date of birth').last);
  await tester.pumpAndSettle();
  await tester.tap(find.text('OK'));
  await tester.pumpAndSettle();
  await tester.tap(find.widgetWithText(FilledButton, 'Next'));
  await tester.pumpAndSettle();
  await tester.enterText(find.byType(TextField).at(0), '180');
  await tester.enterText(find.byType(TextField).at(1), '75');
  await tester.pumpAndSettle();
  await tester.tap(find.widgetWithText(FilledButton, 'Next'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('the lifestyle step is a single-column radio list with the goal tiles under it', (tester) async {
    await _pump(tester);
    await _toLifestyle(tester);

    expect(find.text('Step 4 of 5'), findsOneWidget);
    expect(find.text('How active are you?'), findsOneWidget);
    expect(find.byType(RadioOptionRow), findsNWidgets(5));
    // One column: every row spans the same width and they stack.
    final rows = tester.widgetList(find.byType(RadioOptionRow)).length;
    expect(rows, 5);
    final first = tester.getRect(find.byType(RadioOptionRow).first);
    final second = tester.getRect(find.byType(RadioOptionRow).at(1));
    expect(second.top, greaterThan(first.bottom));
    expect(second.width, first.width);
    expect(find.text('Exercise 3–5 days a week'), findsOneWidget);
    expect(find.text('PRIMARY GOAL'), findsOneWidget);
    expect(find.byType(OptionCard), findsNWidgets(3));
  });

  testWidgets('choosing an activity marks exactly one row, and Next needs a goal too', (tester) async {
    await _pump(tester);
    await _toLifestyle(tester);

    await tester.tap(find.text('Moderate'));
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.check_rounded), findsOneWidget);

    await tester.tap(find.text('Active'));
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.check_rounded), findsOneWidget); // moved, not added

    // Activity alone is not enough.
    await tester.ensureVisible(find.widgetWithText(FilledButton, 'Next'));
    await tester.tap(find.widgetWithText(FilledButton, 'Next'));
    await tester.pumpAndSettle();
    expect(find.text('Please choose an option for every field'), findsOneWidget);
  });

  testWidgets('long Hungarian answers wrap inside their card at 360 dp × 1.3', (tester) async {
    tester.view.physicalSize = const Size(360, 900) * 2;
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(textScaler: const TextScaler.linear(1.3)),
          child: child!,
        ),
        home: Scaffold(
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                for (final (t, d) in [
                  ('Ülő életmód', 'Kevés vagy semmi mozgás'),
                  ('Nagyon aktív', 'Kemény edzés és fizikai munka'),
                  ('Aktív', 'Kemény edzés heti 6–7 napon'),
                ])
                  RadioOptionRow(icon: Icons.bolt, title: t, description: d, selected: t == 'Aktív', onTap: () {}),
              ],
            ),
          ),
        ),
      ),
    );
    expect(tester.takeException(), isNull);
    // The description is drawn in full, not cut to two lines.
    final text = tester.widget<Text>(find.text('Kemény edzés és fizikai munka'));
    expect(text.maxLines, isNull);
  });
}
