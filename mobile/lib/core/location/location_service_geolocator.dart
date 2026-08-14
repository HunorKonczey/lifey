import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart' as geo;

import 'location_service.dart';

/// The real [LocationService], backed by the `geolocator` plugin
/// (docs/cardio/54-cardio-gps-route-plan.md D-C4.1). One class covers both
/// Android and iOS — unlike `MusicService`, `geolocator` already dispatches
/// to the right platform implementation internally, so there's no separate
/// `LocationServiceAndroid`/`LocationServiceIos` to write.
class GeolocatorLocationService implements LocationService {
  final _availabilityController = StreamController<LocationAvailability>.broadcast();

  @override
  Stream<LocationAvailability> get availability => Stream.multi((controller) {
        // Subscribes to live updates *before* the async initial-snapshot
        // fetch below resolves, so a concurrent refresh()/requestPermission()
        // that lands during that window still reaches this listener (see
        // LocationServiceStub.availability's doc for why `Stream.multi`
        // over `async*` here). The one edge case this doesn't fully close:
        // if such a concurrent update resolves *before* this initial fetch
        // does, the stale initial value could in principle arrive after it
        // — acceptable for now since nothing calls refresh() this early yet;
        // revisit if a real caller ever does.
        final sub = _availabilityController.stream.listen(
          controller.add,
          onError: controller.addError,
          onDone: controller.close,
        );
        controller.onCancel = sub.cancel;
        currentAvailability().then(controller.add);
      });

  @override
  Future<LocationAvailability> currentAvailability() async {
    final serviceEnabled = await geo.Geolocator.isLocationServiceEnabled();
    final permission = await geo.Geolocator.checkPermission();
    final accuracyStatus = await geo.Geolocator.getLocationAccuracy();
    return LocationAvailability(
      authorization: _toAuthorization(permission),
      // `unknown` is Android's answer (it has no reduced-accuracy concept,
      // see LocationAccuracyStatus's own doc) — only a real `reduced` means
      // "not precise enough to track" (§3.2).
      precise: accuracyStatus != geo.LocationAccuracyStatus.reduced,
      serviceEnabled: serviceEnabled,
    );
  }

  @override
  Future<LocationAvailability> requestPermission() async {
    // Only actually shows the system dialog while permission is still
    // `denied` (never asked, or askable-again) — `deniedForever`/`granted`
    // just return the OS's cached answer (§3.1: "a rendszer-dialógus
    // egyszer kérdez").
    await geo.Geolocator.requestPermission();
    final result = await currentAvailability();
    _availabilityController.add(result);
    return result;
  }

  @override
  Future<LocationAvailability> refresh() async {
    final result = await currentAvailability();
    _availabilityController.add(result);
    return result;
  }

  @override
  Stream<LocationFix> positionStream({
    required LocationTrackingProfile profile,
    String androidNotificationTitle = 'Lifey',
    String androidNotificationText = 'Recording your route',
  }) {
    return geo.Geolocator.getPositionStream(
      locationSettings: _settingsFor(
        profile,
        androidNotificationTitle: androidNotificationTitle,
        androidNotificationText: androidNotificationText,
      ),
    ).map(
      (p) => LocationFix(
        latitude: p.latitude,
        longitude: p.longitude,
        recordedAt: p.timestamp,
        altitude: p.altitude,
        accuracy: p.accuracy,
        speed: p.speed,
      ),
    );
  }

  @override
  Future<bool> openAppSettings() => geo.Geolocator.openAppSettings();

  @override
  Future<bool> openLocationSettings() => geo.Geolocator.openLocationSettings();

  /// docs/cardio/54-cardio-gps-route-plan.md §4.1 — running/hiking want the
  /// tightest fix (`best`, default 5 m distance filter); walking/outdoor
  /// GAME tolerate `high` + a 10 m filter, fewer points for less battery.
  ///
  /// `allowBackgroundLocationUpdates: true` (C4a.5b, §4.4) keeps fixes
  /// arriving once the app backgrounds/the screen locks, under `whileInUse`
  /// alone — no `NSLocationAlwaysUsageDescription`/"Always" prompt needed
  /// (§3.2's explicit choice): iOS keeps delivering updates to a
  /// when-in-use app that was *already* tracking before backgrounding, as
  /// long as `UIBackgroundModes: location` is declared (added to
  /// `Info.plist` alongside this). `showBackgroundLocationIndicator: true`
  /// surfaces the OS's own blue/pill background-location indicator; the
  /// Live Activity (C2.10b) is the primary "we're still measuring" signal,
  /// this is a secondary, OS-level one. `pauseLocationUpdatesAutomatically`
  /// stays `false`, same as before this step — the app already tracks a
  /// "no motion" state itself via C4a.5a's `AutoPauseDetector`, so
  /// geolocator's own automatic-pause heuristic would just double up on it
  /// with a coarser, less-tunable signal.
  ///
  /// On Android, [androidNotificationTitle]/[androidNotificationText]
  /// (C4a.5a, §4.4) enable `geolocator`'s own foreground service — required
  /// for fixes to keep arriving once the app backgrounds/the screen locks,
  /// under `whileInUse` permission alone (no "always"/background location).
  /// `setOngoing: true` mirrors the app's own workout notification, even
  /// though Android pins a genuine foreground-service notification
  /// regardless of that flag — this just keeps the two visually consistent.
  geo.LocationSettings _settingsFor(
    LocationTrackingProfile profile, {
    String androidNotificationTitle = 'Lifey',
    String androidNotificationText = 'Recording your route',
  }) {
    final accuracy = profile == LocationTrackingProfile.precise
        ? geo.LocationAccuracy.best
        : geo.LocationAccuracy.high;
    final distanceFilter = profile == LocationTrackingProfile.precise ? 5 : 10;

    if (Platform.isAndroid) {
      return geo.AndroidSettings(
        accuracy: accuracy,
        distanceFilter: distanceFilter,
        foregroundNotificationConfig: geo.ForegroundNotificationConfig(
          notificationTitle: androidNotificationTitle,
          notificationText: androidNotificationText,
          // Fixed, not localized — this is core/, decoupled from l10n (same
          // as the rest of this file), and a notification *channel* name is
          // low-visibility system chrome (Settings > Apps > Lifey >
          // Notifications), not user-facing copy worth threading a third
          // parameter through the whole call chain for.
          notificationChannelName: 'Lifey location tracking',
          setOngoing: true,
        ),
      );
    }
    if (Platform.isIOS) {
      return geo.AppleSettings(
        accuracy: accuracy,
        distanceFilter: distanceFilter,
        allowBackgroundLocationUpdates: true,
        pauseLocationUpdatesAutomatically: false,
        showBackgroundLocationIndicator: true,
      );
    }
    return geo.LocationSettings(accuracy: accuracy, distanceFilter: distanceFilter);
  }

  LocationAuthorization _toAuthorization(geo.LocationPermission permission) {
    return switch (permission) {
      geo.LocationPermission.always ||
      geo.LocationPermission.whileInUse =>
        LocationAuthorization.granted,
      geo.LocationPermission.denied => LocationAuthorization.denied,
      geo.LocationPermission.deniedForever => LocationAuthorization.deniedForever,
      geo.LocationPermission.unableToDetermine => LocationAuthorization.notDetermined,
    };
  }
}

/// [GeolocatorLocationService] on Android/iOS, [LocationServiceStub]
/// everywhere else — every `flutter test` run resolves to the stub for
/// free, since the test binding reports neither platform (docs/cardio/59
/// C4a.1: "Teszt-implementáció nélkül is fordul minden platformon").
final locationServiceProvider = Provider<LocationService>((ref) {
  if (Platform.isAndroid || Platform.isIOS) return GeolocatorLocationService();
  return LocationServiceStub();
});
