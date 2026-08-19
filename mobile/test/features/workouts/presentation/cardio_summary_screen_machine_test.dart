import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifey/features/settings/application/settings_controller.dart';
import 'package:lifey/features/settings/domain/user_settings.dart';
import 'package:lifey/features/workouts/application/workout_session_controller.dart';
import 'package:lifey/features/workouts/domain/cardio_interval_plan.dart';
import 'package:lifey/features/workouts/domain/workout_session.dart';
import 'package:lifey/features/workouts/presentation/cardio_summary_screen.dart';
import 'package:lifey/l10n/app_localizations.dart';

/// docs/cardio/60 C7.6 (M39) — the indoor-bike summary: total work derived
/// from power, the executed interval sections, and the calorie card that is
/// **one card with two sides**. The rule the card exists to make visible is
/// the one asserted hardest here: the machine's own calorie estimate is never
/// added to the active calories (docs/cardio/51 Q4).

class _MetricSettings extends SettingsController {
  @override
  Stream<UserSettings> build() => Stream.value(const UserSettings.defaults());
}

class _StubSessionController extends WorkoutSessionController {
  @override
  Stream<List<WorkoutSession>> build() => Stream.value(const []);

  @override
  Future<void> updateLiveCardioMetrics(String clientId,
      {required DateTime startedAt, required CardioMetrics cardio}) async {}
}

WorkoutSession _bikeSession({
  CardioMetrics? cardio,
  int movingSeconds = 1800,
  double? activeCalories,
  List<CardioSplit> splits = const [],
}) {
  final startedAt = DateTime(2026, 8, 19, 18);
  return WorkoutSession(
    clientId: 'ride-1',
    exercises: const [],
    sets: const [],
    startedAt: startedAt,
    finishedAt: startedAt.add(Duration(seconds: movingSeconds)),
    sessionKind: 'CARDIO',
    activityType: 'INDOOR_BIKE',
    movingSeconds: movingSeconds,
    activeCalories: activeCalories,
    cardio: cardio,
    splits: splits,
  );
}

List<CardioSplit> _executedSections(int count) => [
      for (var i = 0; i < count; i++)
        CardioSplit(
          splitIndex: i,
          splitType: CardioSplitType.interval,
          durationSeconds: i.isEven ? 240 : 180,
          intensity: i.isEven ? IntervalIntensity.hard : IntervalIntensity.easy,
          avgWatts: i.isEven ? 218 : 96,
        ),
    ];

Future<void> _pump(WidgetTester tester, WorkoutSession session) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        settingsControllerProvider.overrideWith(_MetricSettings.new),
        workoutSessionControllerProvider.overrideWith(_StubSessionController.new),
      ],
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

void main() {
  group('total work (M39 #1)', () {
    testWidgets('is derived from average power and moving time', (tester) async {
      // 168 W held for 30:00 = 302.4 kJ.
      await _pump(
        tester,
        _bikeSession(
          movingSeconds: 1800,
          cardio: const CardioMetrics(avgWatts: 168, maxWatts: 248),
        ),
      );

      expect(find.text('302'), findsOneWidget);
      expect(find.text('kJ total work'), findsOneWidget);
      expect(find.text('from the power'), findsOneWidget);
      expect(find.text('168'), findsOneWidget);
      expect(find.text('max 248 W'), findsOneWidget);
    });

    testWidgets('without watts the card is moving time, not a 0 kJ', (tester) async {
      await _pump(
        tester,
        _bikeSession(movingSeconds: 1800, cardio: const CardioMetrics(avgCadence: 82)),
      );

      // The frame's own "watt-adat nélkül" state.
      expect(find.text('kJ total work'), findsNothing);
      expect(find.text('0'), findsNothing);
      expect(find.text('MOVING TIME'), findsOneWidget);
      expect(find.text('30:00'), findsOneWidget);
      expect(find.text('82 rpm'), findsOneWidget);
    });

    testWidgets('moving time keeps a place when the work card takes the top slot',
        (tester) async {
      await _pump(
        tester,
        _bikeSession(movingSeconds: 1800, cardio: const CardioMetrics(avgWatts: 168)),
      );

      expect(find.text('kJ total work'), findsOneWidget);
      expect(find.text('30:00'), findsOneWidget);
    });
  });

  group('the calorie card (M39 #3)', () {
    testWidgets('shows both sides, and says which one counts', (tester) async {
      await _pump(
        tester,
        _bikeSession(
          activeCalories: 486,
          cardio: const CardioMetrics(deviceCalories: 612),
        ),
      );

      expect(find.text('ACTIVE'), findsOneWidget);
      expect(find.text('486'), findsOneWidget);
      expect(find.text('kcal · this is what counts towards your day'), findsOneWidget);
      expect(find.text('THE MACHINE READS'), findsOneWidget);
      expect(find.text('612'), findsOneWidget);
      expect(find.text('kcal · for reference, never added'), findsOneWidget);
      expect(
        find.textContaining('never enters your daily total'),
        findsOneWidget,
      );
    });

    testWidgets('the machine number is never added to the active one', (tester) async {
      await _pump(
        tester,
        _bikeSession(
          activeCalories: 486,
          cardio: const CardioMetrics(deviceCalories: 612),
        ),
      );

      // 486 + 612 = 1098 — the sum must appear nowhere on the screen, in any
      // shape. This is the whole point of the two-sided card (51 Q4).
      expect(find.text('1098'), findsNothing);
      expect(find.textContaining('1098'), findsNothing);
      expect(find.text('486'), findsOneWidget);
    });

    testWidgets('one card, not two: the sides sit inside a single container',
        (tester) async {
      await _pump(
        tester,
        _bikeSession(
          activeCalories: 486,
          cardio: const CardioMetrics(deviceCalories: 612),
        ),
      );

      // Two separate cards were rejected in design — they read as two equal
      // numbers. The divider between the halves is what makes them one card.
      expect(find.byType(VerticalDivider), findsOneWidget);
    });

    testWidgets('a machine that reported nothing still offers the field', (tester) async {
      await _pump(tester, _bikeSession(activeCalories: 486));

      expect(find.text('THE MACHINE READS'), findsOneWidget);
      expect(find.text('—'), findsWidgets);
    });
  });

  group('interval sections (M39 #2)', () {
    testWidgets('a ride that played a plan lists what was actually ridden',
        (tester) async {
      await _pump(
        tester,
        _bikeSession(
          cardio: const CardioMetrics(avgWatts: 168),
          splits: _executedSections(4),
        ),
      );

      expect(find.text('INTERVAL SECTIONS'), findsOneWidget);
      expect(find.text('4 sections'), findsOneWidget);
      expect(find.text('hard'), findsNWidgets(2));
      expect(find.text('easy'), findsNWidgets(2));
      expect(find.text('4:00'), findsNWidgets(2));
      expect(find.text('218 W'), findsNWidgets(2));
    });

    testWidgets('a long plan collapses to six rows with an expander', (tester) async {
      await _pump(
        tester,
        _bikeSession(cardio: const CardioMetrics(avgWatts: 168), splits: _executedSections(10)),
      );

      expect(find.text('10 sections'), findsOneWidget);
      expect(find.text('All 10 sections'), findsOneWidget);
      // Six rows shown: three hard, three easy.
      expect(find.text('hard'), findsNWidgets(3));

      await tester.ensureVisible(find.text('All 10 sections'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('All 10 sections'));
      await tester.pumpAndSettle();

      // Expanded: the expander is gone and the rows below the fold exist —
      // only the ones inside the scroll viewport are actually built, so this
      // counts what is on screen rather than all ten.
      expect(find.text('All 10 sections'), findsNothing);
      expect(find.text('hard'), findsAtLeastNWidgets(3));
    });

    testWidgets('a ride without a plan shows no section list at all', (tester) async {
      await _pump(tester, _bikeSession(cardio: const CardioMetrics(avgWatts: 168)));

      expect(find.text('INTERVAL SECTIONS'), findsNothing);
    });

    testWidgets('the km splits of a run never turn into interval sections', (tester) async {
      final run = WorkoutSession(
        clientId: 'run-1',
        exercises: const [],
        sets: const [],
        startedAt: DateTime(2026, 8, 19, 6),
        finishedAt: DateTime(2026, 8, 19, 6, 30),
        sessionKind: 'CARDIO',
        activityType: 'RUNNING',
        movingSeconds: 1800,
        cardio: const CardioMetrics(distanceMeters: 5000),
        splits: const [
          CardioSplit(splitIndex: 0, distanceMeters: 1000, durationSeconds: 300),
          CardioSplit(splitIndex: 1, distanceMeters: 1000, durationSeconds: 310),
        ],
      );

      await _pump(tester, run);

      expect(find.text('INTERVAL SECTIONS'), findsNothing);
      // ...and the run's own splits are untouched: they stay DISTANCE splits,
      // feeding the km list wherever that renders (it needs a recorded route,
      // which this fixture has none of).
      expect(run.splits.every((s) => s.splitType == CardioSplitType.distance), isTrue);
    });
  });
}
