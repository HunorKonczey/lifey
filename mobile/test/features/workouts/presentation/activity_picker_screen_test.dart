import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifey/core/sync/sync_status_provider.dart';
import 'package:lifey/features/settings/application/settings_controller.dart';
import 'package:lifey/features/settings/domain/user_settings.dart';
import 'package:lifey/features/workouts/application/exercise_controller.dart';
import 'package:lifey/features/workouts/application/workout_session_controller.dart';
import 'package:lifey/features/workouts/application/workout_template_controller.dart';
import 'package:lifey/features/workouts/domain/exercise.dart';
import 'package:lifey/features/workouts/domain/workout_session.dart';
import 'package:lifey/features/workouts/domain/workout_template.dart';
import 'package:lifey/features/workouts/presentation/activity_picker_screen.dart';
import 'package:lifey/features/workouts/presentation/cardio_session_screen.dart';
import 'package:lifey/features/workouts/presentation/open_workout_screens.dart';
import 'package:lifey/l10n/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// C2.7 (M03): the full activity/template picker reached from the
/// quick-start sheet's "All workout types" row.
/// docs/cardio/59-cardio-implementation-plan.md C2.7.

class _RecordingSessionController extends WorkoutSessionController {
  final startCardioCalls = <String>[];

  @override
  Stream<List<WorkoutSession>> build() => Stream.value(const []);

  @override
  Future<String> startCardioSession({
    required DateTime startedAt,
    required String activityType,
    CardioMetrics? cardio,
  }) async {
    startCardioCalls.add(activityType);
    lastCardio = cardio;
    return 'new-session';
  }

  CardioMetrics? lastCardio;
}

class _FakeTemplates extends WorkoutTemplateController {
  List<WorkoutTemplate> templates = const [];

  @override
  Stream<List<WorkoutTemplate>> build() => Stream.value(templates);
}

class _FakeExercises extends ExerciseController {
  @override
  Stream<List<Exercise>> build() => Stream.value(const []);
}

class _FakeSettings extends SettingsController {
  @override
  Stream<UserSettings> build() => Stream.value(const UserSettings.defaults());
}

Future<_RecordingSessionController> _pump(WidgetTester tester, {List<WorkoutTemplate> templates = const []}) async {
  final controller = _RecordingSessionController();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        workoutSessionControllerProvider.overrideWith(() => controller),
        workoutTemplateControllerProvider.overrideWith(() => _FakeTemplates()..templates = templates),
        exerciseControllerProvider.overrideWith(_FakeExercises.new),
        settingsControllerProvider.overrideWith(_FakeSettings.new),
        syncStatusByClientIdProvider.overrideWithValue(const {}),
      ],
      child: const MaterialApp(
        locale: Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: ActivityPickerScreen(),
      ),
    ),
  );
  await tester.pump();
  return controller;
}

void main() {
  setUp(resetOpenWorkoutScreens);
  tearDown(resetOpenWorkoutScreens);

  testWidgets('lists all seven cardio types with their modality subtitle', (tester) async {
    await _pump(tester);

    expect(find.text('Running'), findsOneWidget);
    expect(find.text('Walking'), findsOneWidget);
    expect(find.text('Hiking'), findsOneWidget);
    expect(find.text('Indoor bike'), findsOneWidget);
    expect(find.text('Basketball'), findsOneWidget);
    expect(find.text('Football'), findsOneWidget);
    expect(find.text('Other'), findsOneWidget);
    // DISTANCE family (running/walking/hiking) shares one subtitle.
    expect(find.text('Distance · pace · GPS'), findsNWidgets(3));
    expect(find.text('Cadence · power'), findsOneWidget); // MACHINE
    expect(find.text('Playing time · heart-rate zones'), findsNWidgets(3)); // GAME ×3
  });

  testWidgets('the strength-templates section is hidden when there are no templates',
      (tester) async {
    await _pump(tester);

    expect(find.text('STRENGTH TEMPLATES'), findsNothing);
  });

  testWidgets('lists every saved template with its exercise count, no freeform row',
      (tester) async {
    await _pump(tester, templates: [
      const WorkoutTemplate(
        clientId: 't1',
        name: 'Push day',
        exercises: [TemplateExercise(exerciseClientId: 'e1'), TemplateExercise(exerciseClientId: 'e2')],
      ),
      const WorkoutTemplate(clientId: 't2', name: 'Pull day', exercises: []),
    ]);

    expect(find.text('STRENGTH TEMPLATES'), findsOneWidget);
    expect(find.text('Push day'), findsOneWidget);
    expect(find.text('2 exercises'), findsOneWidget);
    expect(find.text('Pull day'), findsOneWidget);
    expect(find.text('0 exercises'), findsOneWidget);
    // M03 deliberately omits an "Empty workout" row — see the class doc.
    expect(find.text('Empty workout'), findsNothing);
  });

  testWidgets('tapping a DISTANCE row starts that activity immediately', (tester) async {
    // The GPS explainer already seen, so the DISTANCE path goes straight
    // through — that gate is C4a.2's, not this test's subject.
    SharedPreferences.setMockInitialValues({'location.gpsExplainerSeen': true});
    final controller = await _pump(tester);

    await tester.tap(find.text('Running'));
    await tester.pumpAndSettle();

    expect(controller.startCardioCalls, ['RUNNING']);
    expect(find.byType(CardioSessionScreen), findsOneWidget);
    expect(find.byType(ActivityPickerScreen), findsNothing);
  });

  testWidgets('a GAME row asks for format and venue first (C9.3, M45)', (tester) async {
    // Until C9.3 a match started on the tap. It now goes through M45's setup
    // sheet — which is *pre-filled*, so the start is still one more tap away,
    // not a form to fill in.
    SharedPreferences.setMockInitialValues({});
    final controller = await _pump(tester);

    await tester.tap(find.text('Basketball'));
    await tester.pumpAndSettle();

    expect(find.text('Before the match'), findsOneWidget);
    expect(controller.startCardioCalls, isEmpty, reason: 'nothing started yet');
    // 2x2, because four of these do not fit one row in Hungarian.
    expect(find.text('5v5'), findsOneWidget);
    expect(find.text('Small-sided'), findsOneWidget);
    expect(find.text('Practice'), findsOneWidget);
    expect(find.text('Match'), findsOneWidget);

    await tester.tap(find.text('Start'));
    await tester.pumpAndSettle();

    expect(controller.startCardioCalls, ['BASKETBALL']);
    // Defaults carried through, untouched: the sheet never blocks the start.
    expect(controller.lastCardio?.venue, 'INDOOR');
    expect(controller.lastCardio?.gameFormat, '5V5');
    expect(find.byType(CardioSessionScreen), findsOneWidget);
  });

  testWidgets('the chosen format and venue reach the new session', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final controller = await _pump(tester);

    await tester.tap(find.text('Basketball'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Small-sided'));
    await tester.pump();
    await tester.tap(find.text('Outdoor'));
    await tester.pump();
    await tester.tap(find.text('Start'));
    await tester.pumpAndSettle();

    expect(controller.lastCardio?.gameFormat, 'SMALL_SIDED');
    expect(controller.lastCardio?.venue, 'OUTDOOR');
    // Remembered for the next match — that is what keeps the sheet a single
    // tap for someone who plays the same game every week.
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('cardio.gameFormat'), 'SMALL_SIDED');
    expect(prefs.getString('cardio.gameVenue'), 'OUTDOOR');
  });

  testWidgets('the last match\'s answers come back pre-selected', (tester) async {
    SharedPreferences.setMockInitialValues({
      'cardio.gameFormat': 'PRACTICE',
      'cardio.gameVenue': 'OUTDOOR',
    });
    final controller = await _pump(tester);

    await tester.tap(find.text('Basketball'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Start'));
    await tester.pumpAndSettle();

    expect(controller.lastCardio?.gameFormat, 'PRACTICE');
    expect(controller.lastCardio?.venue, 'OUTDOOR');
  });

  testWidgets('dismissing the setup sheet starts nothing', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final controller = await _pump(tester);

    await tester.tap(find.text('Basketball'));
    await tester.pumpAndSettle();
    Navigator.of(tester.element(find.text('Before the match')), rootNavigator: true).pop();
    await tester.pumpAndSettle();

    expect(controller.startCardioCalls, isEmpty);
    expect(find.byType(CardioSessionScreen), findsNothing);
  });

  testWidgets('the close button pops the screen', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          workoutSessionControllerProvider.overrideWith(_RecordingSessionController.new),
          workoutTemplateControllerProvider.overrideWith(() => _FakeTemplates()),
          exerciseControllerProvider.overrideWith(_FakeExercises.new),
          settingsControllerProvider.overrideWith(_FakeSettings.new),
          syncStatusByClientIdProvider.overrideWithValue(const {}),
        ],
        child: MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: ElevatedButton(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const ActivityPickerScreen()),
                  ),
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.byType(ActivityPickerScreen), findsOneWidget);

    await tester.tap(find.byIcon(Icons.close));
    await tester.pumpAndSettle();

    expect(find.byType(ActivityPickerScreen), findsNothing);
  });

  group('outdoor GPS opt-in (C9.4, M45)', () {
    testWidgets('indoors there is no GPS row at all', (tester) async {
      // Not a switched-off toggle: in a hall there is nothing to record, so
      // the row does not exist ("nem letiltva, hanem nem létezik").
      SharedPreferences.setMockInitialValues({});
      await _pump(tester);

      await tester.tap(find.text('Basketball'));
      await tester.pumpAndSettle();

      expect(find.text('Indoor'), findsOneWidget); // the venue pair is there
      expect(find.text('Turn on GPS'), findsNothing);
      expect(find.textContaining('Not pace'), findsNothing);
    });

    testWidgets('switching to outdoor reveals the row and the promise', (tester) async {
      SharedPreferences.setMockInitialValues({});
      await _pump(tester);

      await tester.tap(find.text('Basketball'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Outdoor'));
      await tester.pumpAndSettle();

      expect(find.text('Turn on GPS'), findsOneWidget);
      expect(find.text('Uses more battery'), findsOneWidget);
      // The one place the app says a match has no pace.
      expect(
        find.text(
          "You get distance and a route. Not pace: min/km isn't a meaningful number in a match.",
        ),
        findsOneWidget,
      );
    });

    testWidgets('the opt-in is off by default and remembered once set', (tester) async {
      SharedPreferences.setMockInitialValues({});
      await _pump(tester);

      await tester.tap(find.text('Basketball'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Outdoor'));
      await tester.pumpAndSettle();
      expect(tester.widget<SwitchListTile>(find.byType(SwitchListTile)).value, isFalse);

      await tester.tap(find.byType(SwitchListTile));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Start'));
      await tester.pumpAndSettle();

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool('cardio.gameGps'), isTrue);
      expect(prefs.getString('cardio.gameVenue'), 'OUTDOOR');
    });

    testWidgets('going back indoors hides the row again', (tester) async {
      SharedPreferences.setMockInitialValues({
        'cardio.gameVenue': 'OUTDOOR',
        'cardio.gameGps': true,
      });
      await _pump(tester);

      await tester.tap(find.text('Basketball'));
      await tester.pumpAndSettle();
      expect(find.text('Turn on GPS'), findsOneWidget);

      await tester.tap(find.text('Indoor'));
      await tester.pumpAndSettle();

      expect(find.text('Turn on GPS'), findsNothing);
    });
  });
}
