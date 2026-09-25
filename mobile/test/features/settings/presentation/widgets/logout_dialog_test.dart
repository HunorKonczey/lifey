import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifey/core/sync/logout_preflight.dart';
import 'package:lifey/core/theme/app_theme.dart';
import 'package:lifey/features/settings/presentation/widgets/logout_dialog.dart';
import 'package:lifey/l10n/app_localizations.dart';

Widget _app({
  required ValueChanged<bool> onResult,
  Locale locale = const Locale('en'),
  double textScale = 1,
  ThemeData? theme,
  LogoutPlan plan = const LogoutPlan(unsynced: 0, online: true),
}) =>
    MaterialApp(
      theme: theme ?? AppTheme.dark,
      locale: locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(textScale)),
        child: child!,
      ),
      home: Scaffold(
        body: Builder(
          builder: (context) => Center(
            child: TextButton(
              onPressed: () async => onResult(await showLogoutDialog(context, plan: plan)),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );

Future<void> _open(WidgetTester tester) async {
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('says what happens to the local data, in English', (tester) async {
    await tester.pumpWidget(_app(onResult: (_) {}));
    await _open(tester);
    expect(find.text('Log out of Lifey?'), findsOneWidget);
    expect(find.text('Everything is saved to your account. Your data on this phone is removed.'), findsOneWidget);
  });

  testWidgets('online with queued changes: they are uploaded first (R5.6)', (tester) async {
    await tester.pumpWidget(_app(onResult: (_) {}, plan: const LogoutPlan(unsynced: 3, online: true)));
    await _open(tester);
    expect(find.text('3 unsynced changes will be uploaded first. Your data on this phone is removed.'), findsOneWidget);
  });

  testWidgets('one queued change reads in the singular', (tester) async {
    await tester.pumpWidget(_app(onResult: (_) {}, plan: const LogoutPlan(unsynced: 1, online: true)));
    await _open(tester);
    expect(find.textContaining('1 unsynced change will be uploaded first.'), findsOneWidget);
  });

  testWidgets('offline with queued changes: the warning says how many will be lost', (tester) async {
    await tester.pumpWidget(_app(onResult: (_) {}, plan: const LogoutPlan(unsynced: 4, online: false)));
    await _open(tester);
    expect(find.textContaining("4 changes couldn't be uploaded and will be lost."), findsOneWidget);
    expect(find.textContaining("You're offline."), findsOneWidget);
  });

  testWidgets('Cancel resolves false and leaves the session alone', (tester) async {
    bool? result;
    await tester.pumpWidget(_app(onResult: (r) => result = r));
    await _open(tester);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(result, isFalse);
    expect(find.byType(LogoutDialog), findsNothing);
  });

  testWidgets('Log out resolves true', (tester) async {
    bool? result;
    await tester.pumpWidget(_app(onResult: (r) => result = r));
    await _open(tester);
    await tester.tap(find.widgetWithText(FilledButton, 'Log out'));
    await tester.pumpAndSettle();
    expect(result, isTrue);
  });

  testWidgets('tapping the barrier dismisses as "do not log out"', (tester) async {
    bool? result;
    await tester.pumpWidget(_app(onResult: (r) => result = r));
    await _open(tester);
    await tester.tapAt(const Offset(4, 4));
    await tester.pumpAndSettle();
    expect(result, isFalse);
  });

  for (final scale in [1.0, 1.3]) {
    for (final theme in {'dark': AppTheme.dark, 'light': AppTheme.light}.entries) {
      testWidgets('Hungarian fits without overflow (${theme.key}, ×$scale)', (tester) async {
        tester.view.physicalSize = const Size(411 * 2.625, 923 * 2.625);
        tester.view.devicePixelRatio = 2.625;
        addTearDown(tester.view.reset);
        await tester.pumpWidget(_app(
          onResult: (_) {},
          locale: const Locale('hu'),
          textScale: scale,
          theme: theme.value,
        ));
        await _open(tester);
        expect(find.text('Kijelentkezel a Lifey-ból?'), findsOneWidget);
        expect(find.text('Mégse'), findsOneWidget);
        expect(find.text('Kijelentkezés'), findsOneWidget);
        expect(tester.takeException(), isNull);
        // Both buttons stay reachable: ≥ 48 dp tall.
        expect(tester.getSize(find.widgetWithText(FilledButton, 'Kijelentkezés')).height, greaterThanOrEqualTo(48));
      });
    }
  }
}
