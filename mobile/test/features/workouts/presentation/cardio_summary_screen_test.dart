import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifey/features/settings/application/settings_controller.dart';
import 'package:lifey/features/settings/domain/user_settings.dart';
import 'package:lifey/features/workouts/domain/workout_session.dart';
import 'package:lifey/features/workouts/presentation/cardio_summary_screen.dart';
import 'package:lifey/l10n/app_localizations.dart';

/// C1.9: `CardioSummaryScreen` — read-only view of a saved cardio session.
/// docs/cardio/59-cardio-implementation-plan.md C1.9 — kész-ha: "GAME mezők
/// a családhoz kötöttek" (GAME fields are family-bound) and "a mentett edzés
/// megnyitható és olvasható" (a saved workout can be opened and read).

class _MetricSettings extends SettingsController {
  @override
  Stream<UserSettings> build() => Stream.value(const UserSettings.defaults());
}

Future<void> _pump(WidgetTester tester, WorkoutSession session) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [settingsControllerProvider.overrideWith(_MetricSettings.new)],
      child: MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: CardioSummaryScreen(session: session),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

WorkoutSession _session({
  required String activityType,
  CardioMetrics? cardio,
  int? movingSeconds,
  int? rpe,
  String? feedbackNote,
}) {
  final startedAt = DateTime(2026, 8, 10, 7);
  return WorkoutSession(
    clientId: 'c1',
    exercises: const [],
    sets: const [],
    startedAt: startedAt,
    finishedAt: startedAt.add(Duration(seconds: movingSeconds ?? 0)),
    sessionKind: 'CARDIO',
    activityType: activityType,
    movingSeconds: movingSeconds,
    cardio: cardio,
    rpe: rpe,
    feedbackNote: feedbackNote,
  );
}

void main() {
  testWidgets('DISTANCE with a recorded distance shows distance as primary, pace as secondary',
      (tester) async {
    await _pump(
      tester,
      _session(
        activityType: 'RUNNING',
        cardio: const CardioMetrics(distanceMeters: 5000, elevationGainMeters: 42),
        movingSeconds: 1500, // 25:00 -> 5:00 /km
      ),
    );

    expect(tester.takeException(), isNull);
    expect(find.text('DISTANCE'), findsOneWidget);
    expect(find.text('5.00 km'), findsOneWidget);
    expect(find.text('PACE'), findsOneWidget);
    expect(find.text('5:00 /km'), findsOneWidget);
    expect(find.text('ELEVATION GAIN'), findsOneWidget);
    expect(find.text('42 m'), findsOneWidget);
  });

  testWidgets('DISTANCE without a recorded distance falls back to duration as primary',
      (tester) async {
    await _pump(tester, _session(activityType: 'WALKING', movingSeconds: 1800));

    expect(find.text('DURATION'), findsOneWidget);
    expect(find.text('30:00'), findsOneWidget);
    expect(find.text('PACE'), findsNothing);
  });

  testWidgets('MACHINE always shows moving time as primary, never distance', (tester) async {
    await _pump(
      tester,
      _session(
        activityType: 'INDOOR_BIKE',
        cardio: const CardioMetrics(
          distanceMeters: 18400,
          avgWatts: 164,
          avgCadence: 81,
          resistanceLevel: 6,
          deviceCalories: 420,
        ),
        movingSeconds: 2538,
      ),
    );

    expect(find.text('MOVING TIME'), findsOneWidget);
    expect(find.text('42:18'), findsOneWidget);
    expect(find.text('DISTANCE'), findsOneWidget); // secondary tile, not primary
    expect(find.text('18.40 km'), findsOneWidget);
    expect(find.text('164 W'), findsOneWidget);
    expect(find.text('81 rpm'), findsOneWidget);
    expect(find.text('6'), findsOneWidget);
    expect(find.text('420 kcal'), findsOneWidget);
  });

  testWidgets('GAME shows playing time as primary and its own fields as secondary',
      (tester) async {
    await _pump(
      tester,
      _session(
        activityType: 'BASKETBALL',
        cardio: const CardioMetrics(intensity: 4, venue: 'INDOOR', scorePoints: 18),
        movingSeconds: 3120,
      ),
    );

    expect(find.text('PLAYING TIME'), findsOneWidget);
    expect(find.text('52:00'), findsOneWidget);
    expect(find.text('VENUE'), findsOneWidget);
    expect(find.text('Indoor'), findsOneWidget);
    expect(find.text('INTENSITY'), findsOneWidget);
    expect(find.text('4/5'), findsOneWidget);
    expect(find.text('SCORE'), findsOneWidget);
    expect(find.text('18'), findsOneWidget);
  });

  testWidgets('an unrated session shows no feedback card', (tester) async {
    await _pump(tester, _session(activityType: 'RUNNING', movingSeconds: 600));

    expect(find.text('How hard was it?'), findsNothing);
  });

  testWidgets('a rated session shows the RPE value and note', (tester) async {
    await _pump(
      tester,
      _session(
        activityType: 'RUNNING',
        movingSeconds: 600,
        rpe: 7,
        feedbackNote: 'Felt great',
      ),
    );

    expect(find.text('How hard was it?'), findsOneWidget);
    expect(find.text('7'), findsOneWidget);
    expect(find.text('Felt great'), findsOneWidget);
  });
}
