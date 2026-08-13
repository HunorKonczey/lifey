import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifey/features/settings/application/settings_controller.dart';
import 'package:lifey/features/settings/domain/user_settings.dart';
import 'package:lifey/features/workouts/application/workout_session_controller.dart';
import 'package:lifey/features/workouts/domain/workout_session.dart';
import 'package:lifey/features/workouts/presentation/cardio_session_screen.dart';
import 'package:lifey/l10n/app_localizations.dart';

/// C2.3: the MACHINE family layout on `CardioSessionScreen`.
/// docs/cardio/59-cardio-implementation-plan.md C2.3 — kész-ha:
/// "Kadencia/teljesítmény/ellenállás bevihető menet közben."
///
/// The merge-not-replace behavior of `_updateCardioMetrics` is the load-
/// bearing regression here: editing one field must never blank out the
/// others already entered this session — see "editing cadence doesn't
/// clobber an already-set distance or power" below.

class _RecordingSessionController extends WorkoutSessionController {
  final updateLiveCardioMetricsCalls = <Map<String, Object?>>[];

  @override
  Stream<List<WorkoutSession>> build() => Stream.value(const []);

  @override
  Future<void> pauseCardioSession(String clientId,
          {required DateTime startedAt, required int movingSeconds}) async {}

  @override
  Future<void> resumeCardioSession(String clientId,
          {required DateTime startedAt, required DateTime resumedAt}) async {}

  @override
  Future<void> finishCardioSession(String clientId,
          {required DateTime startedAt,
          required DateTime finishedAt,
          required int movingSeconds,
          Value<CardioMetrics?> cardio = const Value.absent(),
          Value<List<CardioSplit>> splits = const Value.absent()}) async {}

  @override
  Future<void> updateLiveCardioMetrics(
    String clientId, {
    required DateTime startedAt,
    required CardioMetrics cardio,
  }) async {
    updateLiveCardioMetricsCalls.add({'clientId': clientId, 'cardio': cardio});
  }
}

class _MetricSettings extends SettingsController {
  @override
  Stream<UserSettings> build() => Stream.value(const UserSettings.defaults());
}

WorkoutSession _machineSession({
  double? distanceMeters,
  double? avgCadence,
  double? avgWatts,
  int? resistanceLevel,
  int movingSeconds = 0,
}) {
  final hasCardio =
      distanceMeters != null || avgCadence != null || avgWatts != null || resistanceLevel != null;
  return WorkoutSession(
    clientId: 'live-1',
    exercises: const [],
    sets: const [],
    startedAt: DateTime.now().subtract(const Duration(minutes: 30)),
    sessionKind: 'CARDIO',
    activityType: 'INDOOR_BIKE',
    movingSeconds: movingSeconds,
    cardio: !hasCardio
        ? null
        : CardioMetrics(
            distanceMeters: distanceMeters,
            avgCadence: avgCadence,
            avgWatts: avgWatts,
            resistanceLevel: resistanceLevel,
          ),
  );
}

Future<_RecordingSessionController> _pump(WidgetTester tester, WorkoutSession session) async {
  final controller = _RecordingSessionController();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        workoutSessionControllerProvider.overrideWith(() => controller),
        settingsControllerProvider.overrideWith(_MetricSettings.new),
      ],
      child: MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: CardioSessionScreen(session: session),
      ),
    ),
  );
  await tester.pump();
  return controller;
}

void main() {
  testWidgets('moving time is dominant with nothing entered; the three tiles show placeholders',
      (tester) async {
    await _pump(tester, _machineSession(movingSeconds: 2538));

    expect(tester.takeException(), isNull);
    expect(find.text('MOVING TIME'), findsOneWidget);
    expect(find.text('42:18'), findsOneWidget);
    expect(find.text('DISTANCE'), findsOneWidget);
    expect(find.text('CADENCE'), findsOneWidget);
    expect(find.text('AVG POWER'), findsOneWidget);
    expect(find.text('RESISTANCE'), findsOneWidget);
    expect(find.text('0'), findsOneWidget); // resistance starts at 0
  });

  testWidgets('a recorded distance does NOT become dominant — MACHINE never switches',
      (tester) async {
    await _pump(tester, _machineSession(distanceMeters: 18400, movingSeconds: 2538));

    // Still moving time up top, exactly like the empty case.
    expect(find.text('MOVING TIME'), findsOneWidget);
    expect(find.text('42:18'), findsOneWidget);
    expect(find.text('18.40 km'), findsOneWidget); // distance is a secondary tile
  });

  testWidgets('the dominant moving-time block is not tappable (nothing to override)',
      (tester) async {
    await _pump(tester, _machineSession(movingSeconds: 60));

    // No AlertDialog opens from tapping the big number — only the three
    // metric tiles and the resistance stepper are interactive on this layout.
    await tester.tap(find.text('1:00'));
    await tester.pump();
    expect(find.byType(AlertDialog), findsNothing);
  });

  testWidgets('editing cadence does not clobber an already-set distance or power', (tester) async {
    final controller = await _pump(
      tester,
      _machineSession(distanceMeters: 10000, avgWatts: 150, movingSeconds: 60),
    );

    await tester.tap(find.text('CADENCE'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '85');
    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await tester.pumpAndSettle();

    expect(controller.updateLiveCardioMetricsCalls, hasLength(1));
    final cardio = controller.updateLiveCardioMetricsCalls.single['cardio'] as CardioMetrics;
    expect(cardio.avgCadence, 85);
    expect(cardio.distanceMeters, 10000); // preserved, not wiped
    expect(cardio.avgWatts, 150); // preserved, not wiped

    // The screen reflects all three afterwards, not just the one just edited.
    expect(find.text('10.00 km'), findsOneWidget);
    expect(find.text('85 rpm'), findsOneWidget);
    expect(find.text('150 W'), findsOneWidget);
  });

  testWidgets('editing power in turn preserves the cadence just set', (tester) async {
    final controller = await _pump(tester, _machineSession(avgCadence: 85, movingSeconds: 60));

    await tester.tap(find.text('AVG POWER'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '172');
    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await tester.pumpAndSettle();

    final cardio = controller.updateLiveCardioMetricsCalls.single['cardio'] as CardioMetrics;
    expect(cardio.avgWatts, 172);
    expect(cardio.avgCadence, 85);
  });

  testWidgets('the resistance stepper increments, persists, and preserves the other fields',
      (tester) async {
    final controller =
        await _pump(tester, _machineSession(avgWatts: 150, resistanceLevel: 4, movingSeconds: 60));

    await tester.tap(find.widgetWithIcon(IconButton, Icons.add));
    await tester.pumpAndSettle();

    expect(controller.updateLiveCardioMetricsCalls, hasLength(1));
    final cardio = controller.updateLiveCardioMetricsCalls.single['cardio'] as CardioMetrics;
    expect(cardio.resistanceLevel, 5);
    expect(cardio.avgWatts, 150);
    expect(find.text('5'), findsOneWidget);
  });

  testWidgets('the resistance stepper cannot go below zero', (tester) async {
    final controller = await _pump(tester, _machineSession(movingSeconds: 60));

    final minusButton =
        tester.widget<IconButton>(find.widgetWithIcon(IconButton, Icons.remove));
    expect(minusButton.onPressed, isNull);
    expect(controller.updateLiveCardioMetricsCalls, isEmpty);
  });
}
