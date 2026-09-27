import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifey/core/theme/app_theme.dart';
import 'package:lifey/l10n/app_localizations.dart';
import 'package:lifey/shared/widgets/confirm_delete_dialog.dart';

Future<void> _open(
  WidgetTester tester, {
  required ThemeData theme,
  Locale locale = const Locale('en'),
  double textScale = 1,
  void Function(bool)? onResult,
}) async {
  tester.view.physicalSize = const Size(360, 800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      theme: theme,
      locale: locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(textScale)),
        child: child!,
      ),
      home: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: ElevatedButton(
              onPressed: () async {
                final r = await showConfirmDeleteDialog(context, title: 'Delete this meal?', message: 'It cannot be brought back.');
                onResult?.call(r);
              },
              child: const Text('open'),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
}

void main() {
  for (final (mode, theme) in [('dark', AppTheme.dark), ('light', AppTheme.light)]) {
    testWidgets('follows the $mode theme instead of a hard-coded dark surface', (tester) async {
      await _open(tester, theme: theme);

      final dialog = tester.widget<Dialog>(find.byType(Dialog));
      final context = tester.element(find.byType(Dialog));
      expect(dialog.backgroundColor, isNull, reason: 'the dialog theme supplies the surface');
      final material = tester.widget<Material>(find.descendant(of: find.byType(Dialog), matching: find.byType(Material)).first);
      expect(material.color, Theme.of(context).dialogTheme.backgroundColor);
    });
  }

  testWidgets('Delete confirms, Cancel refuses', (tester) async {
    bool? result;
    await _open(tester, theme: AppTheme.dark, onResult: (r) => result = r);
    await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
    await tester.pumpAndSettle();
    expect(result, isTrue);

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(OutlinedButton, 'Cancel'));
    await tester.pumpAndSettle();
    expect(result, isFalse);
  });

  for (final (name, locale) in [('English', const Locale('en')), ('Hungarian', const Locale('hu'))]) {
    for (final (mode, theme) in [('dark', AppTheme.dark), ('light', AppTheme.light)]) {
      testWidgets('fits 360 dp at x 1.3 in $name, $mode, with the buttons stacked', (tester) async {
        await _open(tester, theme: theme, locale: locale, textScale: 1.3);
        expect(tester.takeException(), isNull);
        // Stacked: one button above the other, not side by side.
        final confirm = tester.getTopLeft(find.byType(FilledButton));
        final cancel = tester.getTopLeft(find.byType(OutlinedButton));
        expect(cancel.dy, greaterThan(confirm.dy));
        expect(cancel.dx, confirm.dx);
        expect(tester.getSize(find.byType(OutlinedButton)).width, tester.getSize(find.byType(FilledButton)).width);
      });
    }
  }
}
