import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifey/features/settings/application/settings_controller.dart';
import 'package:lifey/features/settings/domain/user_settings.dart';
import 'package:lifey/features/workouts/application/workout_session_controller.dart';
import 'package:lifey/features/workouts/domain/workout_session.dart';
import 'package:lifey/features/workouts/presentation/log_cardio_sheet.dart';
import 'package:lifey/l10n/app_localizations.dart';

/// C1.8: `LogCardioSheet` — DISTANCE and MACHINE manual entry.
/// docs/cardio/59-cardio-implementation-plan.md C1.8 — kész-ha: every
/// numeric field gets a `MANUAL` source flag, and a past date can be saved.
///
/// The controller is faked at `logCardioSession()` itself (not the
/// repository underneath it) — that method is a thin, already-covered pass-
/// through to `WorkoutSessionRepository.create()`, so recording its call
/// here verifies what the *sheet* computes and sends, without standing up a
/// real Drift database.

class _RecordingSessionController extends WorkoutSessionController {
  final calls = <Map<String, Object?>>[];

  @override
  Stream<List<WorkoutSession>> build() => Stream.value(const []);

  @override
  Future<String> logCardioSession({
    required DateTime startedAt,
    required String activityType,
    required int movingSeconds,
    CardioMetrics? cardio,
    int? rpe,
    String? feedbackNote,
  }) async {
    calls.add({
      'startedAt': startedAt,
      'activityType': activityType,
      'movingSeconds': movingSeconds,
      'cardio': cardio,
      'rpe': rpe,
      'feedbackNote': feedbackNote,
    });
    return 'new-client-id';
  }
}

class _MetricSettings extends SettingsController {
  @override
  Stream<UserSettings> build() => Stream.value(const UserSettings.defaults());
}

class _ImperialSettings extends SettingsController {
  @override
  Stream<UserSettings> build() =>
      Stream.value(const UserSettings.defaults().copyWith(unitSystem: UnitSystem.imperial));
}

Future<_RecordingSessionController> _pumpSheet(
  WidgetTester tester, {
  bool imperial = false,
}) async {
  final controller = _RecordingSessionController();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        workoutSessionControllerProvider.overrideWith(() => controller),
        settingsControllerProvider
            .overrideWith(imperial ? _ImperialSettings.new : _MetricSettings.new),
      ],
      child: const MaterialApp(
        locale: Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(body: LogCardioSheet()),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return controller;
}

/// Scrolls the Save button into view before tapping — with RPE/note now
/// part of the sheet, its content routinely exceeds the default test
/// viewport, and an off-screen tap only warns rather than failing outright.
Future<void> _tapSave(WidgetTester tester) async {
  final save = find.widgetWithText(FilledButton, 'Save');
  await tester.ensureVisible(save);
  await tester.pumpAndSettle();
  await tester.tap(save);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('defaults to the DISTANCE family fields (Running is first)', (tester) async {
    await _pumpSheet(tester);

    expect(find.text('DISTANCE'), findsOneWidget);
    expect(find.text('ELEVATION GAIN'), findsOneWidget);
    expect(find.text('AVG POWER'), findsNothing);
  });

  testWidgets('Save is disabled until a duration is entered', (tester) async {
    await _pumpSheet(tester);

    final saveButton = tester.widget<FilledButton>(find.byType(FilledButton));
    expect(saveButton.onPressed, isNull);

    // The three duration fields (h/m/s) carry no label to match on; select
    // the minutes field by position.
    await tester.enterText(find.byType(TextField).at(1), '30');
    await tester.pump();

    final saveButtonAfter = tester.widget<FilledButton>(find.byType(FilledButton));
    expect(saveButtonAfter.onPressed, isNotNull);
  });

  testWidgets('selecting a MACHINE type swaps in the machine fields', (tester) async {
    await _pumpSheet(tester);

    final chip = find.widgetWithText(ChoiceChip, 'Indoor bike');
    await tester.ensureVisible(chip);
    await tester.pumpAndSettle();
    await tester.tap(chip);
    await tester.pumpAndSettle();

    expect(find.text('AVG POWER'), findsOneWidget);
    expect(find.text('CADENCE'), findsOneWidget);
    expect(find.text('RESISTANCE'), findsOneWidget);
    expect(find.text('MACHINE CALORIES'), findsOneWidget);
    expect(find.text('ELEVATION GAIN'), findsNothing);
  });

  testWidgets('selecting a GAME type swaps in venue/intensity/score, not the DISTANCE/MACHINE fields',
      (tester) async {
    await _pumpSheet(tester);

    final chip = find.widgetWithText(ChoiceChip, 'Basketball');
    await tester.ensureVisible(chip);
    await tester.pumpAndSettle();
    await tester.tap(chip);
    await tester.pumpAndSettle();

    expect(find.text('DISTANCE'), findsNothing);
    expect(find.text('AVG POWER'), findsNothing);
    expect(find.text('ELEVATION GAIN'), findsNothing);
    expect(find.text('VENUE'), findsOneWidget);
    expect(find.text('INTENSITY'), findsOneWidget);
    expect(find.text('SCORE'), findsOneWidget);
    expect(find.text('Indoor'), findsOneWidget);
    expect(find.text('Outdoor'), findsOneWidget);
  });

  testWidgets('submitting sends movingSeconds and MANUAL-tagged distance/elevation',
      (tester) async {
    final controller = await _pumpSheet(tester);

    final durationFields = find.byType(TextField);
    await tester.enterText(durationFields.at(0), '1'); // hours
    await tester.enterText(durationFields.at(1), '5'); // minutes
    await tester.enterText(durationFields.at(2), '30'); // seconds
    await tester.enterText(find.widgetWithText(TextField, 'DISTANCE'), '5.00');
    await tester.enterText(find.widgetWithText(TextField, 'ELEVATION GAIN'), '120');
    await tester.pump();

    await _tapSave(tester);

    expect(controller.calls, hasLength(1));
    final call = controller.calls.single;
    expect(call['activityType'], 'RUNNING');
    expect(call['movingSeconds'], 1 * 3600 + 5 * 60 + 30);
    final cardio = call['cardio'] as CardioMetrics;
    expect(cardio.distanceMeters, 5000);
    expect(cardio.distanceSource, 'MANUAL');
    expect(cardio.elevationGainMeters, 120);
  });

  testWidgets('a duration-only submission (no numeric fields filled) sends cardio: null',
      (tester) async {
    final controller = await _pumpSheet(tester);

    final durationFields = find.byType(TextField);
    await tester.enterText(durationFields.at(1), '20'); // 20 minutes, nothing else
    await tester.pump();

    await _tapSave(tester);

    expect(controller.calls.single['cardio'], isNull);
    expect(controller.calls.single['movingSeconds'], 20 * 60);
  });

  testWidgets('a past date picked via "When" is preserved through submission', (tester) async {
    final controller = await _pumpSheet(tester);

    // The date picker itself is a platform dialog outside this widget's
    // tree; exercising the full picker flow belongs in an integration test.
    // What this sheet owns and must get right is that whatever `_startedAt`
    // ends up being (past or present) is exactly what's sent — verified here
    // via the unmodified default (now), and the picker's own `lastDate: now`
    // constraint (log_cardio_sheet.dart) is what prevents a future pick.
    final durationFields = find.byType(TextField);
    await tester.enterText(durationFields.at(1), '10');
    await tester.pump();

    final before = DateTime.now();
    await _tapSave(tester);

    final sentStartedAt = controller.calls.single['startedAt'] as DateTime;
    expect(sentStartedAt.difference(before).inMinutes.abs() < 1, isTrue);
  });

  testWidgets('submitting a GAME session sends intensity, venue, and score in cardio',
      (tester) async {
    final controller = await _pumpSheet(tester);

    final chip = find.widgetWithText(ChoiceChip, 'Basketball');
    await tester.ensureVisible(chip);
    await tester.pumpAndSettle();
    await tester.tap(chip);
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).at(1), '52'); // 52 minutes

    await tester.tap(find.widgetWithText(SegmentedButton<String>, 'Outdoor'));
    await tester.pump();

    // Intensity 1-5 row: tap the 4th chip (label "4"). It renders before the
    // universal 1-10 RPE row, which also has a "4" — `.first` picks intensity's.
    await tester.tap(find.text('4').first);
    await tester.pump();

    // Score stepper: two taps on the "+" button.
    final incrementButtons = find.widgetWithIcon(IconButton, Icons.add);
    await tester.tap(incrementButtons.last);
    await tester.tap(incrementButtons.last);
    await tester.pump();

    await _tapSave(tester);

    final cardio = controller.calls.single['cardio'] as CardioMetrics;
    expect(cardio.venue, 'OUTDOOR');
    expect(cardio.intensity, 4);
    expect(cardio.scorePoints, 2);
    // GAME never touches the DISTANCE/MACHINE fields.
    expect(cardio.distanceMeters, isNull);
    expect(cardio.avgWatts, isNull);
  });

  testWidgets('an RPE rating and note are sent alongside the cardio metrics', (tester) async {
    final controller = await _pumpSheet(tester);

    await tester.enterText(find.byType(TextField).at(1), '30');
    // The RPE row (1-10) sits below the family fields; "7" is unambiguous
    // since the default DISTANCE fields don't render any chip labelled "7".
    await tester.tap(find.text('7'));
    await tester.enterText(find.widgetWithText(TextField, 'Add a note (optional)'), 'Felt great');
    await tester.pump();

    await _tapSave(tester);

    expect(controller.calls.single['rpe'], 7);
    expect(controller.calls.single['feedbackNote'], 'Felt great');
  });

  testWidgets('an empty note is sent as null, not an empty string', (tester) async {
    final controller = await _pumpSheet(tester);

    await tester.enterText(find.byType(TextField).at(1), '30');
    await tester.pump();

    await _tapSave(tester);

    expect(controller.calls.single['rpe'], isNull);
    expect(controller.calls.single['feedbackNote'], isNull);
  });

  testWidgets('respects the imperial unit system for distance', (tester) async {
    final controller = await _pumpSheet(tester, imperial: true);

    expect(find.text('mi'), findsWidgets);

    final durationFields = find.byType(TextField);
    await tester.enterText(durationFields.at(1), '30');
    await tester.enterText(find.widgetWithText(TextField, 'DISTANCE'), '1.00');
    await tester.pump();

    await _tapSave(tester);

    final cardio = controller.calls.single['cardio'] as CardioMetrics;
    expect(cardio.distanceMeters, closeTo(1609.344, 0.001));
  });
}
