import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifey/features/workouts/presentation/widgets/auto_pause_settings_sheet.dart';
import 'package:lifey/l10n/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// C4a.5a — the "Kikapcsolható" half of GPS auto-pause
/// (docs/cardio/53-cardio-mobile-plan.md §4.3). `AutoPausePreferences`
/// itself is covered by its own unit tests; this file is the sheet's UI —
/// loading state, default, and that the switch actually writes through.

Future<void> _pumpTrigger(WidgetTester tester) async {
  await tester.pumpWidget(
    ProviderScope(
      child: MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () => showAutoPauseSettingsSheet(context),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('open'));
  await tester.pump(); // one frame — deliberately not settled, see the spinner test below
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('shows a loading spinner before the async read resolves, then the switch on by default',
      (tester) async {
    await _pumpTrigger(tester);

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.byType(SwitchListTile), findsNothing);

    await tester.pump(); // lets the SharedPreferences read resolve

    expect(find.byType(CircularProgressIndicator), findsNothing);
    final switchTile = tester.widget<SwitchListTile>(find.byType(SwitchListTile));
    expect(switchTile.value, isTrue);
  });

  testWidgets('shows the title and description', (tester) async {
    await _pumpTrigger(tester);
    await tester.pump();

    expect(find.text('Auto-pause'), findsOneWidget);
    expect(
      find.text(
        'Pauses automatically after 15 seconds of no movement, and resumes as soon as you start '
        'moving again. Only works while GPS is tracking.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('starts pre-set to off when the preference was already disabled', (tester) async {
    SharedPreferences.setMockInitialValues({'cardio.autoPauseEnabled': false});
    await _pumpTrigger(tester);
    await tester.pump();

    final switchTile = tester.widget<SwitchListTile>(find.byType(SwitchListTile));
    expect(switchTile.value, isFalse);
  });

  testWidgets('tapping the switch flips it and persists the change', (tester) async {
    await _pumpTrigger(tester);
    await tester.pump(); // lets the SharedPreferences read resolve
    await tester.pump(const Duration(milliseconds: 300)); // lets the sheet's slide-up animation finish

    await tester.tap(find.byType(SwitchListTile));
    await tester.pump();

    expect(tester.widget<SwitchListTile>(find.byType(SwitchListTile)).value, isFalse);

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool('cardio.autoPauseEnabled'), isFalse);
  });
}
