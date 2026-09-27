import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifey/core/entitlements/entitlement_providers.dart';
import 'package:lifey/core/local_db/app_database.dart';
import 'package:lifey/core/local_db/database_provider.dart';
import 'package:lifey/core/location/location_service.dart';
import 'package:lifey/core/location/location_service_geolocator.dart';
import 'package:lifey/features/settings/application/settings_controller.dart';
import 'package:lifey/features/settings/domain/user_settings.dart';
import 'package:lifey/features/workouts/application/workout_session_controller.dart';
import 'package:lifey/features/workouts/domain/workout_session.dart';
import 'package:lifey/features/workouts/presentation/cardio_session_screen.dart';
import 'package:lifey/l10n/app_localizations.dart';

/// C2.2: the DISTANCE family layout on `CardioSessionScreen` — the
/// dominant/secondary switch and the manual distance edit that stands in
/// for GPS until C4a. docs/cardio/59-cardio-implementation-plan.md C2.2 —
/// kész-ha: "A domináns szám a [57 §2] szabálya szerint vált; nincs
/// „0,00 km” nagy helyen."

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

class _ImperialSettings extends SettingsController {
  @override
  Stream<UserSettings> build() =>
      Stream.value(const UserSettings.defaults().copyWith(unitSystem: UnitSystem.imperial));
}

/// This file's fixtures are all DISTANCE-family — see `cardio_session_screen_test.dart`'s
/// identical helper for why every test here overrides `locationServiceProvider`
/// with a pre-granted stub: it keeps C4a.2's "no GPS" status card/chip out
/// of a layout these C2.2 tests were written against, and out of scope here.
LocationServiceStub _grantedLocationStub() => LocationServiceStub(
      initial: const LocationAvailability(
        authorization: LocationAuthorization.granted,
        precise: true,
        serviceEnabled: true,
      ),
    );

/// C4a.3: `CardioSessionScreen.initState` now unconditionally reads
/// `cardioTrackPointRepositoryProvider` (→ `appDatabaseProvider`) for every
/// DISTANCE-family session — see `_pump`'s override below and
/// `cardio_session_screen_test.dart`'s identical helper for why.
AppDatabase _testDatabase() {
  final db = AppDatabase(NativeDatabase.memory());
  addTearDown(db.close);
  return db;
}

WorkoutSession _distanceSession({
  double? distanceMeters,
  int movingSeconds = 0,
  int? movingSinceEpochMs,
  String activityType = 'RUNNING',
}) {
  return WorkoutSession(
    clientId: 'live-1',
    exercises: const [],
    sets: const [],
    startedAt: DateTime.now().subtract(const Duration(minutes: 30)),
    sessionKind: 'CARDIO',
    activityType: activityType,
    movingSeconds: movingSeconds,
    movingSinceEpochMs: movingSinceEpochMs,
    cardio: distanceMeters == null ? null : CardioMetrics(distanceMeters: distanceMeters),
  );
}

Future<_RecordingSessionController> _pump(
  WidgetTester tester,
  WorkoutSession session, {
  bool imperial = false,
}) async {
  final controller = _RecordingSessionController();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        // See cardio_session_screen_machine_test.dart's own comment on this
        // override — InterstitialManager (67 Prompt 10) needs it here too.
        adsEnabledProvider.overrideWithValue(false),
        workoutSessionControllerProvider.overrideWith(() => controller),
        settingsControllerProvider
            .overrideWith(imperial ? _ImperialSettings.new : _MetricSettings.new),
        locationServiceProvider.overrideWithValue(_grantedLocationStub()),
        appDatabaseProvider.overrideWithValue(_testDatabase()),
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
  testWidgets('no distance recorded: the moving time is the hero, distance shows the placeholder',
      (tester) async {
    await _pump(tester, _distanceSession(movingSeconds: 754));

    expect(tester.takeException(), isNull);
    expect(find.text('MOVING TIME'), findsOneWidget);
    expect(find.text('12:34'), findsOneWidget);
    expect(find.text('Distance'), findsOneWidget);
    // The never-show-a-big-zero guarantee: no "0.00 km" anywhere, dominant or not.
    expect(find.textContaining('0.00 km'), findsNothing);
    expect(find.text('Pace'), findsOneWidget);
    expect(find.text('Heart rate'), findsNothing); // no reading, no heart-rate row
  });

  testWidgets('a recorded distance sits in its own card; the moving time stays the hero',
      (tester) async {
    await _pump(
      tester,
      _distanceSession(distanceMeters: 5000, movingSeconds: 1500), // 25:00 -> 5:00 /km
    );

    expect(find.text('Distance'), findsOneWidget);
    expect(find.text('5.00 km'), findsOneWidget);
    expect(find.text('MOVING TIME'), findsOneWidget);
    expect(find.text('25:00'), findsOneWidget);
    expect(find.text('Pace'), findsOneWidget);
    expect(find.text('5:00 /km'), findsOneWidget);
  });

  testWidgets(
      'a CYCLING session shows speed (km/h), not pace (docs/cardio/62-cardio-cycling-plan.md §2.2)',
      (tester) async {
    await _pump(
      tester,
      _distanceSession(
        distanceMeters: 5000,
        movingSeconds: 600, // 10:00 -> 30.0 km/h
        activityType: 'CYCLING',
      ),
    );

    expect(find.text('Speed'), findsOneWidget);
    expect(find.text('30.0 km/h'), findsOneWidget);
    expect(find.text('Pace'), findsNothing);
    expect(find.textContaining('/km'), findsNothing);
  });

  testWidgets('a zero distance is treated the same as no distance (still falls back)',
      (tester) async {
    await _pump(tester, _distanceSession(distanceMeters: 0, movingSeconds: 60));

    expect(find.text('MOVING TIME'), findsOneWidget);
    expect(find.textContaining('km'), findsNothing);
  });

  testWidgets('tapping the distance placeholder opens the edit dialog and saves in km',
      (tester) async {
    final controller = await _pump(tester, _distanceSession(movingSeconds: 60));

    await tester.tap(find.text('Distance'));
    await tester.pumpAndSettle();
    expect(find.text('Update distance'), findsOneWidget);

    await tester.enterText(find.byType(TextField), '4.20');
    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await tester.pumpAndSettle();

    expect(controller.updateLiveCardioMetricsCalls, hasLength(1));
    final cardio = controller.updateLiveCardioMetricsCalls.single['cardio'] as CardioMetrics;
    expect(cardio.distanceMeters, closeTo(4200, 0.01));
    expect(cardio.distanceSource, 'MANUAL');
    // The screen adopts the new value immediately without waiting for a re-pump from outside.
    expect(find.text('4.20 km'), findsOneWidget);
  });

  testWidgets('tapping the dominant distance number also opens the edit dialog', (tester) async {
    await _pump(tester, _distanceSession(distanceMeters: 5000, movingSeconds: 1500));

    await tester.tap(find.text('5.00 km'));
    await tester.pumpAndSettle();

    expect(find.text('Update distance'), findsOneWidget);
  });

  testWidgets('cancelling the edit dialog leaves the distance unchanged', (tester) async {
    final controller = await _pump(tester, _distanceSession(movingSeconds: 60));

    await tester.tap(find.text('Distance'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '4.20');
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(controller.updateLiveCardioMetricsCalls, isEmpty);
    expect(find.text('MOVING TIME'), findsOneWidget);
  });

  testWidgets('respects the imperial unit system: entry in miles converts to meters',
      (tester) async {
    final controller = await _pump(tester, _distanceSession(movingSeconds: 60), imperial: true);

    await tester.tap(find.text('Distance'));
    await tester.pumpAndSettle();
    expect(find.text('mi'), findsWidgets);

    await tester.enterText(find.byType(TextField), '1.00');
    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await tester.pumpAndSettle();

    final cardio = controller.updateLiveCardioMetricsCalls.single['cardio'] as CardioMetrics;
    expect(cardio.distanceMeters, closeTo(1609.344, 0.01));
  });

  group('the live layout (docs/redesign/77-mobile-redesign-plan.md R3.8)', () {
    double numberSize(WidgetTester tester, String value) {
      final text = tester.widgetList<Text>(find.byType(Text)).firstWhere(
            (t) => t.textSpan?.toPlainText() == value,
          );
      return ((text.textSpan! as TextSpan).children!.first as TextSpan).style!.fontSize!;
    }

    testWidgets('a 104 px moving-time hero over distance and pace cards with 40 px numbers', (tester) async {
      await _pump(tester, _distanceSession(distanceMeters: 5000, movingSeconds: 1500));

      expect(numberSize(tester, '25:00'), 104);
      expect(numberSize(tester, '5.00 km'), 40);
      expect(numberSize(tester, '5:00 /km'), 40);
      // the hero is centred over the two cards
      final hero = tester.getCenter(find.text('25:00'));
      expect(hero.dx, closeTo(tester.view.physicalSize.width / tester.view.devicePixelRatio / 2, 1));
      expect(tester.getTopLeft(find.text('Distance')).dy, greaterThan(tester.getBottomLeft(find.text('25:00')).dy));
      // side by side: same row
      expect(tester.getTopLeft(find.text('Pace')).dy, tester.getTopLeft(find.text('Distance')).dy);
    });

    testWidgets('the header names the activity and says whether auto-pause is on', (tester) async {
      await _pump(tester, _distanceSession(movingSeconds: 60));
      await tester.pump();

      expect(find.text('Running'), findsOneWidget);
      // no fix yet, so no GPS part — just whether auto-pause is on
      expect(find.text('Auto-pause on'), findsOneWidget);
      expect(find.byTooltip('Auto-pause settings'), findsOneWidget);
    });

    testWidgets('one big pause disc in the middle, no side circles while running', (tester) async {
      await _pump(tester, _distanceSession(movingSeconds: 60, movingSinceEpochMs: DateTime.now().millisecondsSinceEpoch));

      final pause = find.byTooltip('Pause');
      expect(pause, findsOneWidget);
      expect(tester.getSize(pause).width, greaterThanOrEqualTo(96));
      expect(find.byIcon(Icons.pause_rounded), findsOneWidget);
      expect(tester.getCenter(pause).dx, closeTo(tester.view.physicalSize.width / tester.view.devicePixelRatio / 2, 1));
    });

    testWidgets('slide to finish: a red stop knob on a pill track, a tap finishes nothing', (tester) async {
      await _pump(tester, _distanceSession(movingSeconds: 60));

      expect(find.byIcon(Icons.stop_rounded), findsOneWidget);
      expect(find.text('Slide to finish'), findsOneWidget);
      final bar = find.byKey(const Key('slideToFinishBar'));
      expect(tester.getSize(bar).height, 64);
      await tester.tap(bar);
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text('Slide to finish'), findsOneWidget);
    });
  });

  // A "GAME still shows the generic placeholder" cross-family check used to
  // live here — obsolete since C2.4 (GAME now has its own layout too; see
  // cardio_session_screen_game_test.dart). No family uses the C2.1 generic
  // body anymore, so there's nothing left to assert against from this file.
}
