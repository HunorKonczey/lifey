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

/// C4a.2, M27/M28 — the in-session "no GPS" status card + header chip.
/// Every fixture here is DISTANCE-family (RUNNING) except the one dedicated
/// "never renders for MACHINE/GAME" test — matches
/// `cardio_session_screen_distance_test.dart`'s own convention.

class _RecordingSessionController extends WorkoutSessionController {
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
  Future<void> updateLiveCardioMetrics(String clientId,
      {required DateTime startedAt, required CardioMetrics cardio}) async {}
}

class _MetricSettings extends SettingsController {
  @override
  Stream<UserSettings> build() => Stream.value(const UserSettings.defaults());
}

WorkoutSession _session({String activityType = 'RUNNING'}) {
  return WorkoutSession(
    clientId: 'live-1',
    exercises: const [],
    sets: const [],
    startedAt: DateTime.now().subtract(const Duration(minutes: 5)),
    sessionKind: 'CARDIO',
    activityType: activityType,
    movingSeconds: 120,
    movingSinceEpochMs: DateTime.now().millisecondsSinceEpoch,
  );
}

/// C4a.3: `CardioSessionScreen.initState` now unconditionally reads
/// `cardioTrackPointRepositoryProvider` (→ `appDatabaseProvider`) for every
/// DISTANCE-family session — see `_pump`'s override below and
/// `cardio_session_screen_test.dart`'s identical helper for why.
AppDatabase _testDatabase() {
  final db = AppDatabase(NativeDatabase.memory());
  addTearDown(db.close);
  return db;
}

Future<LocationServiceStub> _pump(
  WidgetTester tester, {
  LocationAvailability initial = LocationAvailability.initial,
  String activityType = 'RUNNING',
}) async {
  final location = LocationServiceStub(initial: initial);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        // See cardio_session_screen_machine_test.dart's own comment on this
        // override — InterstitialManager (67 Prompt 10) needs it here too.
        adsEnabledProvider.overrideWithValue(false),
        workoutSessionControllerProvider.overrideWith(_RecordingSessionController.new),
        settingsControllerProvider.overrideWith(_MetricSettings.new),
        locationServiceProvider.overrideWithValue(location),
        appDatabaseProvider.overrideWithValue(_testDatabase()),
      ],
      child: MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: CardioSessionScreen(session: _session(activityType: activityType)),
      ),
    ),
  );
  await tester.pump();
  return location;
}

void main() {
  testWidgets('canTrack (granted, precise, service enabled): neither card nor chip render',
      (tester) async {
    await _pump(
      tester,
      initial: const LocationAvailability(
        authorization: LocationAuthorization.granted,
        precise: true,
        serviceEnabled: true,
      ),
    );

    expect(find.text('Location is off'), findsNothing);
    expect(find.text('No GPS'), findsNothing);
  });

  testWidgets('notDetermined: shows "Location is off" + Allow, and the header chip',
      (tester) async {
    await _pump(tester); // LocationAvailability.initial == notDetermined

    expect(find.text('Location is off'), findsOneWidget);
    expect(
      find.text("The workout keeps running — we're tracking time and heart rate. No distance or route."),
      findsOneWidget,
    );
    expect(find.text('Allow'), findsOneWidget);
    expect(find.text('No GPS'), findsOneWidget);
  });

  testWidgets('tapping Allow calls requestPermission(), which updates the card reactively',
      (tester) async {
    final location = await _pump(tester);

    await tester.tap(find.text('Allow'));
    await tester.pumpAndSettle();

    expect((await location.currentAvailability()).authorization, LocationAuthorization.granted);
    expect(find.text('Location is off'), findsNothing);
    expect(find.text('No GPS'), findsNothing);
  });

  testWidgets('deniedForever: shows the permanently-denied card and Open Settings button',
      (tester) async {
    await _pump(
      tester,
      initial: const LocationAvailability(
        authorization: LocationAuthorization.deniedForever,
        precise: true,
        serviceEnabled: true,
      ),
    );

    expect(find.text('You permanently denied location'), findsOneWidget);
    expect(find.text('Open Settings'), findsOneWidget);
    // Not the "still askable" copy/button.
    expect(find.text('Location is off'), findsNothing);
    expect(find.text('Allow'), findsNothing);
  });

  testWidgets('device-wide Location Services off (but app permission granted): '
      'shows the off card with a "Turn on Location Services" button', (tester) async {
    await _pump(
      tester,
      initial: const LocationAvailability(
        authorization: LocationAuthorization.granted,
        precise: true,
        serviceEnabled: false,
      ),
    );

    expect(find.text('Location is off'), findsOneWidget);
    expect(find.text('Turn on Location Services'), findsOneWidget);
  });

  testWidgets('imprecise (iOS approximate): shows the precise-location card', (tester) async {
    await _pump(
      tester,
      initial: const LocationAvailability(
        authorization: LocationAuthorization.granted,
        precise: false,
        serviceEnabled: true,
      ),
    );

    expect(find.text('Precise location is off'), findsOneWidget);
    expect(find.text('Turn on precise location'), findsOneWidget);
    expect(find.text('No GPS'), findsOneWidget); // canTrack is still false
  });

  testWidgets('"Not now" dismisses the card but the header chip stays', (tester) async {
    await _pump(tester);

    await tester.tap(find.text('Not now'));
    await tester.pumpAndSettle();

    expect(find.text('Location is off'), findsNothing);
    expect(find.text('No GPS'), findsOneWidget);
  });

  testWidgets('never renders for MACHINE or GAME sessions', (tester) async {
    await _pump(tester, activityType: 'INDOOR_BIKE'); // MACHINE
    expect(find.text('Location is off'), findsNothing);
    expect(find.text('No GPS'), findsNothing);

    await _pump(tester, activityType: 'BASKETBALL'); // GAME
    expect(find.text('Location is off'), findsNothing);
    expect(find.text('No GPS'), findsNothing);
  });
}
