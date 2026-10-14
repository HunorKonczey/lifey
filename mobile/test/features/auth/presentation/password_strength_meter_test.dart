import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifey/core/theme/app_theme.dart';
import 'package:lifey/core/theme/app_tokens.dart';
import 'package:lifey/features/auth/presentation/register_screen.dart';
import 'package:lifey/features/auth/presentation/widgets/password_strength_meter.dart';
import 'package:lifey/l10n/app_localizations.dart';

/// The register form's strength meter (LIF-157): four segments and a word, following the password field.
void main() {
  Future<TextEditingController> pumpMeter(
    WidgetTester tester, {
    Locale locale = const Locale('en'),
    ThemeData? theme,
  }) async {
    final controller = TextEditingController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      MaterialApp(
        theme: theme ?? AppTheme.dark,
        locale: locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(body: Padding(padding: const EdgeInsets.all(16), child: PasswordStrengthMeter(controller: controller))),
      ),
    );
    return controller;
  }

  Color? segmentColor(WidgetTester tester, int i) {
    final box = tester.widget<DecoratedBox>(find.byKey(Key('password-strength-segment-$i')));
    return (box.decoration as BoxDecoration).color;
  }

  testWidgets('shows nothing while the password is empty', (tester) async {
    await pumpMeter(tester);

    expect(find.byKey(const Key('password-strength')), findsNothing);
  });

  testWidgets('says how strong it is as it is typed, one word per level', (tester) async {
    final controller = await pumpMeter(tester);

    controller.text = 'abc';
    await tester.pump();
    expect(find.text('Weak password'), findsOneWidget);

    controller.text = 'abcdefgh';
    await tester.pump();
    expect(find.text('Acceptable'), findsOneWidget);

    controller.text = 'Abcdefg1';
    await tester.pump();
    expect(find.text('Strong password'), findsOneWidget);

    controller.text = 'Abcdefg1!';
    await tester.pump();
    expect(find.text('Very strong password'), findsOneWidget);

    controller.clear();
    await tester.pump();
    expect(find.byKey(const Key('password-strength')), findsNothing);
  });

  testWidgets('fills as many of the four segments as the level, in that level\'s colour', (tester) async {
    final controller = await pumpMeter(tester);
    final context = tester.element(find.byType(PasswordStrengthMeter));
    final metrics = context.metricColors;
    final track = context.palette.control;

    controller.text = 'abc';
    await tester.pump();
    expect([for (var i = 1; i <= 4; i++) segmentColor(tester, i)], [metrics.heart, track, track, track]);

    controller.text = 'abcdefgh';
    await tester.pump();
    expect([for (var i = 1; i <= 4; i++) segmentColor(tester, i)], [metrics.calories, metrics.calories, track, track]);

    controller.text = 'Abcdefg1';
    await tester.pump();
    expect([for (var i = 1; i <= 4; i++) segmentColor(tester, i)], [metrics.positive, metrics.positive, metrics.positive, track]);

    controller.text = 'Abcdefg1!';
    await tester.pump();
    expect([for (var i = 1; i <= 4; i++) segmentColor(tester, i)], List.filled(4, metrics.positive));
  });

  testWidgets('speaks Hungarian', (tester) async {
    final controller = await pumpMeter(tester, locale: const Locale('hu'));

    controller.text = 'abc';
    await tester.pump();
    expect(find.text('Gyenge jelszó'), findsOneWidget);

    controller.text = 'Abcdefg1!';
    await tester.pump();
    expect(find.text('Nagyon erős jelszó'), findsOneWidget);
  });

  testWidgets('the word is announced as a live region', (tester) async {
    final controller = await pumpMeter(tester);
    controller.text = 'Abcdefg1';
    await tester.pump();

    final semantics = tester.getSemantics(find.text('Strong password'));

    expect(semantics.label, 'Strong password');
    expect(semantics.flagsCollection.isLiveRegion, isTrue);
  });

  testWidgets('works on the light theme too', (tester) async {
    final controller = await pumpMeter(tester, theme: AppTheme.light);
    controller.text = 'Abcdefg1!';
    await tester.pump();

    expect(find.text('Very strong password'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  group('on the register screen', () {
    Future<void> pumpRegister(WidgetTester tester, {Locale locale = const Locale('en'), Size size = const Size(390, 844), double textScale = 1}) async {
      tester.view.physicalSize = size * 2;
      tester.view.devicePixelRatio = 2;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            theme: AppTheme.dark,
            locale: locale,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(textScale)),
              child: child!,
            ),
            home: const RegisterScreen(),
          ),
        ),
      );
      await tester.pump();
    }

    Finder passwordField() => find.widgetWithText(TextFormField, 'Password');

    testWidgets('no meter until something is typed in the password field, then it follows it', (tester) async {
      await pumpRegister(tester);
      expect(find.byKey(const Key('password-strength')), findsNothing);

      await tester.enterText(passwordField(), 'abc');
      await tester.pump();
      expect(find.text('Weak password'), findsOneWidget);

      await tester.enterText(passwordField(), 'Correct-Horse-9');
      await tester.pump();
      expect(find.text('Very strong password'), findsOneWidget);
    });

    testWidgets('typing in the confirmation field does not move it', (tester) async {
      await pumpRegister(tester);
      await tester.enterText(passwordField(), 'abcdefgh');
      await tester.pump();

      await tester.enterText(find.widgetWithText(TextFormField, 'Confirm password'), 'Abcdefg1!');
      await tester.pump();

      expect(find.text('Acceptable'), findsOneWidget);
    });

    testWidgets('the 8-character rule is still the only one that blocks: a weak but long enough password passes validation', (tester) async {
      await pumpRegister(tester);
      await tester.enterText(passwordField(), 'abcdefgh');
      await tester.pump();

      expect(find.text('Must be at least 8 characters'), findsNothing);
    });

    testWidgets('fits a 360 dp phone at × 1.3 in Hungarian with the longest word showing', (tester) async {
      await pumpRegister(tester, locale: const Locale('hu'), size: const Size(360, 740), textScale: 1.3);
      await tester.enterText(find.byType(TextFormField).at(3), 'Abcdefg1!');
      await tester.pump();

      expect(find.text('Nagyon erős jelszó'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
