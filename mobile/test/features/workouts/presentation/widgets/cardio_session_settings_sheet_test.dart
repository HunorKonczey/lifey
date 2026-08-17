import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifey/features/settings/application/settings_controller.dart';
import 'package:lifey/features/settings/domain/user_settings.dart';
import 'package:lifey/features/workouts/presentation/widgets/cardio_session_settings_sheet.dart';
import 'package:lifey/l10n/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The DISTANCE family's in-session settings sheet: GPS auto-pause (C4a.5a,
/// docs/cardio/53 §4.3) and the per-kilometre cue (C6.6, docs/cardio/61 §2
/// M35). The preference stores have their own coverage; this file is the
/// sheet's UI — loading state, defaults, write-through, and the two things
/// M35 is emphatic about: the spoken row is *reserved*, not broken, and the
/// unit is *explained*, not set.

class _StubSettings extends SettingsController {
  _StubSettings(this.unitSystem);

  final UnitSystem unitSystem;

  @override
  Stream<UserSettings> build() =>
      Stream.value(const UserSettings.defaults().copyWith(unitSystem: unitSystem));
}

Future<void> _pumpTrigger(
  WidgetTester tester, {
  UnitSystem unitSystem = UnitSystem.metric,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        settingsControllerProvider.overrideWith(() => _StubSettings(unitSystem)),
      ],
      child: MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () => showCardioSessionSettingsSheet(context),
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

/// The sheet's switches in M35's order: auto-pause, vibration, sound.
SwitchListTile _switchAt(WidgetTester tester, int index) =>
    tester.widgetList<SwitchListTile>(find.byType(SwitchListTile)).elementAt(index);

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('shows a loading spinner before the async reads resolve, then the defaults',
      (tester) async {
    await _pumpTrigger(tester);

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.byType(SwitchListTile), findsNothing);

    await tester.pump(); // lets the SharedPreferences reads resolve

    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.byType(SwitchListTile), findsNWidgets(3));
    expect(_switchAt(tester, 0).value, isTrue, reason: 'auto-pause is on by default');
    expect(_switchAt(tester, 1).value, isTrue, reason: 'vibration is on by default');
    expect(_switchAt(tester, 2).value, isFalse, reason: 'sound is off by default');
  });

  testWidgets('shows the title, the auto-pause description and the cue section', (tester) async {
    await _pumpTrigger(tester);
    await tester.pump();

    expect(find.text('During the workout'), findsOneWidget);
    expect(
      find.text(
        'Pauses automatically after 15 seconds of no movement, and resumes as soon as you start '
        'moving again. Only works while GPS is tracking.',
      ),
      findsOneWidget,
    );
    expect(find.text('DISTANCE FEEDBACK'), findsOneWidget);
    expect(find.text('Two short taps'), findsOneWidget);
    expect(find.text('A short chime, over your music'), findsOneWidget);
  });

  testWidgets('starts pre-set from whatever was already stored', (tester) async {
    SharedPreferences.setMockInitialValues({
      'cardio.autoPauseEnabled': false,
      'cardio.kmCueVibration': false,
      'cardio.kmCueSound': true,
    });
    await _pumpTrigger(tester);
    await tester.pump();

    expect(_switchAt(tester, 0).value, isFalse);
    expect(_switchAt(tester, 1).value, isFalse);
    expect(_switchAt(tester, 2).value, isTrue);
  });

  testWidgets('tapping auto-pause flips it and persists the change', (tester) async {
    await _pumpTrigger(tester);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300)); // sheet slide-up

    await tester.tap(find.byType(SwitchListTile).first);
    await tester.pump();

    expect(_switchAt(tester, 0).value, isFalse);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool('cardio.autoPauseEnabled'), isFalse);
  });

  testWidgets('the two cue switches write through independently', (tester) async {
    await _pumpTrigger(tester);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    await tester.tap(find.byType(SwitchListTile).at(1)); // vibration off
    await tester.pump();
    await tester.tap(find.byType(SwitchListTile).at(2)); // sound on
    await tester.pump();

    expect(_switchAt(tester, 1).value, isFalse);
    expect(_switchAt(tester, 2).value, isTrue);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool('cardio.kmCueVibration'), isFalse);
    expect(prefs.getBool('cardio.kmCueSound'), isTrue);
    // Turning everything off is a valid state, not a fallback to something.
    expect(prefs.getBool('cardio.autoPauseEnabled'), isNull, reason: 'untouched');
  });

  testWidgets('the spoken row is reserved, not a switch the user can fail to turn on',
      (tester) async {
    await _pumpTrigger(tester);
    await tester.pump();

    expect(find.text('Spoken feedback'), findsOneWidget);
    expect(find.text('soon'), findsOneWidget);
    expect(find.text('"Kilometer 3, pace 5:12"'), findsOneWidget);
    // Three switches, not four: the not-yet-built feature carries no toggle
    // at all (M35 — a greyed-out switch would read as broken).
    expect(find.byType(SwitchListTile), findsNWidgets(3));
  });

  group('the unit is explained, never set here (M35)', () {
    testWidgets('a metric profile says kilometers', (tester) async {
      await _pumpTrigger(tester);
      await tester.pump();

      expect(
        find.text(
          'The unit comes from your profile: kilometers right now. Switch to miles and the cue '
          'fires every mile, and the splits switch too.',
        ),
        findsOneWidget,
      );
    });

    testWidgets('an imperial profile says miles', (tester) async {
      await _pumpTrigger(tester, unitSystem: UnitSystem.imperial);
      await tester.pump();

      expect(
        find.text(
          'The unit comes from your profile: miles right now. Switch to kilometers and the cue '
          'fires every kilometer, and the splits switch too.',
        ),
        findsOneWidget,
      );
    });
  });
}
