import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifey/core/theme/app_theme.dart';
import 'package:lifey/features/auth/presentation/change_password_screen.dart';
import 'package:lifey/features/auth/presentation/forgot_password_screen.dart';
import 'package:lifey/features/auth/presentation/login_screen.dart';
import 'package:lifey/features/auth/presentation/register_screen.dart';
import 'package:lifey/l10n/app_localizations.dart';

Future<void> _pump(
  WidgetTester tester,
  Widget screen, {
  Locale locale = const Locale('en'),
  Size size = const Size(390, 844),
  double textScale = 1,
  ThemeData? theme,
  double keyboard = 0,
}) async {
  tester.view.physicalSize = size * 2;
  tester.view.devicePixelRatio = 2;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      child: MaterialApp(
        theme: theme ?? AppTheme.dark,
        locale: locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: TextScaler.linear(textScale),
            viewInsets: EdgeInsets.only(bottom: keyboard),
          ),
          child: child!,
        ),
        home: screen,
      ),
    ),
  );
  await tester.pump();
}

void main() {
  group('LoginScreen (canvas 6)', () {
    testWidgets('logo tile, welcome title, promise, icon fields and the primary sign-in', (tester) async {
      await _pump(tester, const LoginScreen());

      expect(find.text('L'), findsOneWidget);
      expect(find.text('Welcome back'), findsOneWidget);
      expect(find.textContaining('Your logs stay on this phone, even offline.'), findsOneWidget);
      expect(find.text('Email'), findsWidgets);
      expect(find.byIcon(Icons.mail_outline_rounded), findsOneWidget);
      expect(find.byIcon(Icons.lock_outline_rounded), findsOneWidget);
      expect(find.text('Forgot password?'), findsOneWidget);
      // "Sign in" is always the one filled button; Google is the outlined one.
      expect(find.widgetWithText(FilledButton, 'Sign in'), findsOneWidget);
      expect(find.widgetWithText(OutlinedButton, 'Continue with Google'), findsOneWidget);
      expect(find.text('or'), findsOneWidget);
      expect(find.textContaining('New to Lifey?', findRichText: true), findsOneWidget);
      expect(tester.getSize(find.widgetWithText(FilledButton, 'Sign in')).height, 56);
    });

    testWidgets('an empty submit names the missing fields', (tester) async {
      await _pump(tester, const LoginScreen());
      await tester.tap(find.widgetWithText(FilledButton, 'Sign in'));
      await tester.pump();

      expect(find.text('Required'), findsWidgets);
    });

    for (final (name, locale, scale, keyboard) in [
      ('Hungarian at 360 dp × 1.3', const Locale('hu'), 1.3, 0.0),
      ('English at 360 dp with the keyboard up', const Locale('en'), 1.0, 300.0),
      ('Hungarian at 360 dp × 1.3 with the keyboard up', const Locale('hu'), 1.3, 300.0),
    ]) {
      testWidgets('fits without overflow: $name', (tester) async {
        for (final theme in [AppTheme.dark, AppTheme.light]) {
          await _pump(
            tester,
            const LoginScreen(),
            locale: locale,
            size: const Size(360, 740),
            textScale: scale,
            keyboard: keyboard,
            theme: theme,
          );
          expect(tester.takeException(), isNull);
        }
      });
    }
  });

  group('RegisterScreen', () {
    testWidgets('every field has its label and icon; create account is the filled button', (tester) async {
      await _pump(tester, const RegisterScreen());

      expect(find.text('Create account'), findsWidgets);
      expect(find.byIcon(Icons.person_outline_rounded), findsNWidgets(2));
      expect(find.byIcon(Icons.mail_outline_rounded), findsOneWidget);
      expect(find.byIcon(Icons.lock_outline_rounded), findsNWidgets(2));
      expect(find.widgetWithText(FilledButton, 'Create account'), findsOneWidget);
      expect(find.byIcon(Icons.arrow_back_rounded), findsOneWidget);
    });

    testWidgets('fits a 360 dp phone at × 1.3 in Hungarian', (tester) async {
      await _pump(tester, const RegisterScreen(), locale: const Locale('hu'), size: const Size(360, 740), textScale: 1.3);
      expect(tester.takeException(), isNull);
    });
  });

  group('ForgotPasswordScreen', () {
    testWidgets('asks for the email first, with a way back', (tester) async {
      await _pump(tester, const ForgotPasswordScreen());

      expect(find.text('Reset your password'), findsOneWidget);
      expect(find.widgetWithText(FilledButton, 'Send reset code'), findsOneWidget);
      expect(find.text('Back to sign in'), findsOneWidget);
    });

    testWidgets('fits a 360 dp phone at × 1.3 in Hungarian', (tester) async {
      await _pump(tester, const ForgotPasswordScreen(), locale: const Locale('hu'), size: const Size(360, 740), textScale: 1.3);
      expect(tester.takeException(), isNull);
    });
  });

  group('ChangePasswordScreen', () {
    testWidgets('sits under the subpage header with three password fields', (tester) async {
      await _pump(tester, const ChangePasswordScreen());

      expect(find.byType(AppBar), findsNothing);
      expect(find.byIcon(Icons.lock_outline_rounded), findsNWidgets(3));
      expect(find.widgetWithText(FilledButton, 'Change password'), findsOneWidget);
    });

    testWidgets('fits a 360 dp phone at × 1.3 in Hungarian', (tester) async {
      await _pump(tester, const ChangePasswordScreen(), locale: const Locale('hu'), size: const Size(360, 740), textScale: 1.3);
      expect(tester.takeException(), isNull);
    });
  });
}
