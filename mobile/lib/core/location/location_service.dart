import 'dart:async';

/// App-level location permission, collapsed to what the UI needs to branch
/// on (docs/cardio/54-cardio-gps-route-plan.md §3.3) — mirrors geolocator's
/// own `LocationPermission` enum, minus the distinctions this app never
/// requests or shows differently: `always` is never asked for (§3.2 —
/// `whileInUse` is enough, since tracking only needs the foreground
/// service/background mode C4a.5 adds, not "always"), so it and
/// `whileInUse` both collapse to [granted]; `unableToDetermine` (web-only,
/// [LocationService] never targets web) collapses to [notDetermined].
enum LocationAuthorization {
  /// Never asked, or the OS hasn't answered yet.
  notDetermined,
  denied,

  /// The user must go to system Settings to change this — a plain
  /// re-request no longer shows the system dialog (§3.1's "asks once").
  deniedForever,
  granted,
}

/// Combined snapshot of everything the §3.3 state matrix branches on —
/// permission, precision, and the device-wide Location Services toggle are
/// three orthogonal things geolocator itself keeps separate, so this does
/// too rather than collapsing them into one enum.
class LocationAvailability {
  const LocationAvailability({
    required this.authorization,
    required this.precise,
    required this.serviceEnabled,
  });

  static const initial = LocationAvailability(
    authorization: LocationAuthorization.notDetermined,
    precise: true,
    serviceEnabled: true,
  );

  final LocationAuthorization authorization;

  /// iOS 14+ only (§3.2): false means the user granted only the
  /// *approximate* location option — the route is unusable at that
  /// precision, so the UI treats this the same as "no distance source".
  /// Always true on Android, which has no such distinction.
  final bool precise;

  /// The device-wide "Location Services" toggle — independent of this app's
  /// own [authorization]; can be off even when permission is [granted].
  final bool serviceEnabled;

  /// Whether [LocationService.positionStream] can be expected to actually
  /// produce fixes right now — the single condition the M10/M26-M28 UI
  /// (C4a.2) branches its "no distance source" messaging on.
  bool get canTrack =>
      authorization == LocationAuthorization.granted && precise && serviceEnabled;

  LocationAvailability copyWith({
    LocationAuthorization? authorization,
    bool? precise,
    bool? serviceEnabled,
  }) {
    return LocationAvailability(
      authorization: authorization ?? this.authorization,
      precise: precise ?? this.precise,
      serviceEnabled: serviceEnabled ?? this.serviceEnabled,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is LocationAvailability &&
      other.authorization == authorization &&
      other.precise == precise &&
      other.serviceEnabled == serviceEnabled;

  @override
  int get hashCode => Object.hash(authorization, precise, serviceEnabled);

  @override
  String toString() =>
      'LocationAvailability(authorization: $authorization, precise: $precise, serviceEnabled: $serviceEnabled)';
}

/// One GPS fix — the fields `CardioTrackPoints` (C4a.3) persists and
/// `track_filter.dart` (C4a.4) filters. A domain type of our own, decoupled
/// from geolocator's `Position`, so the rest of the app never imports the
/// plugin directly (same reasoning as `HealthWorkout`/`MusicPlaybackState`
/// wrapping their respective plugins).
class LocationFix {
  const LocationFix({
    required this.latitude,
    required this.longitude,
    required this.recordedAt,
    this.altitude,
    this.accuracy,
    this.speed,
  });

  final double latitude;
  final double longitude;
  final DateTime recordedAt;

  /// Meters. Null when the device can't report it — geolocator itself
  /// defaults to `0.0` in that case, which `track_filter.dart` can't tell
  /// apart from a genuine sea-level reading, so implementations should only
  /// pass a real null through, never coerce a `0.0` sentinel into one.
  final double? altitude;

  /// Estimated horizontal accuracy radius, meters — smaller is better.
  final double? accuracy;

  /// Ground speed, meters/second.
  final double? speed;
}

/// The accuracy/power tradeoff to request while tracking — the
/// "aktivitás-függő beállítások" docs/cardio/54-cardio-gps-route-plan.md
/// §4.1 calls for: running/hiking want the tightest fix, walking and
/// outdoor GAME sessions tolerate a coarser, more battery-friendly one.
/// Deliberately just these two — the mapping from a specific `ActivityType`
/// to a profile is a `features/workouts` concern (this is `core/`, and
/// stays decoupled from feature-level types, same as `core/health`).
enum LocationTrackingProfile {
  precise,
  relaxed,
}

/// Platform-neutral facade over the device's location capability — mirrors
/// `MusicService`'s shape (methods + a state stream, injected via a
/// Riverpod provider) so callers stay thin. `geolocator` itself already
/// covers Android/iOS with one implementation (unlike music, there's no
/// per-platform bridge to write), so there's exactly one real
/// implementation, [GeolocatorLocationService] — see
/// `location_service_geolocator.dart`.
abstract class LocationService {
  /// Emits an [LocationAvailability] whenever it might have changed.
  /// Neither platform pushes a native "the user changed this in Settings"
  /// event, so besides [requestPermission] pushing its own result, this only
  /// updates when [refresh] is called — callers must call it on app resume
  /// and after sending the user to system Settings (the "Engedélyezés" /
  /// "Kapcsold be a helymeghatározást" links, §3.3), or a change made there
  /// won't be reflected until some other trigger happens to call it.
  Stream<LocationAvailability> get availability;

  /// One-shot read of the current [LocationAvailability] without
  /// subscribing to [availability].
  Future<LocationAvailability> currentAvailability();

  /// Shows the system permission dialog — but only the *first* time; once
  /// [LocationAuthorization.denied] or [LocationAuthorization.deniedForever]
  /// is reached, this just re-reads the OS's cached answer without prompting
  /// again (§3.1: "a rendszer-dialógus egyszer kérdez"). Requests
  /// `whileInUse` only, never `always` (§3.2). Pushes the result onto
  /// [availability] as well as returning it.
  Future<LocationAvailability> requestPermission();

  /// Re-checks permission, precision, and the device Location Services
  /// toggle without showing any dialog, and pushes the result onto
  /// [availability] — see that getter's doc for when callers must call this.
  Future<LocationAvailability> refresh();

  /// A stream of fixes at [profile]'s accuracy/power tradeoff. Callers own
  /// the subscription's lifetime — cancelling it stops tracking. Callers
  /// should check [LocationAvailability.canTrack] first; an implementation
  /// is free to simply not emit (rather than throw) when it can't track.
  ///
  /// [androidNotificationTitle]/[androidNotificationText] are Android-only
  /// (C4a.5a, docs/cardio/54-cardio-gps-route-plan.md §4.4): Android
  /// requires a visible foreground-service notification to keep delivering
  /// fixes once the app backgrounds/the screen locks, and `geolocator`'s own
  /// foreground service always shows its own, separate system notification
  /// for that — there's no public API to make it reuse/update the app's own
  /// rich, live-ticking ongoing workout notification (C2.9/C2.10a), only a
  /// static title/text set once per subscription. The defaults exist so
  /// every implementation/caller isn't forced to pass real copy (tests,
  /// iOS/the stub, which both ignore these entirely); the real
  /// `CardioSessionScreen` call site always supplies localized text.
  Stream<LocationFix> positionStream({
    required LocationTrackingProfile profile,
    String androidNotificationTitle = 'Lifey',
    String androidNotificationText = 'Recording your route',
  });

  /// Opens the app's own OS Settings page (the [LocationAuthorization.denied]
  /// / [LocationAuthorization.deniedForever] "Engedélyezés" link, §3.3).
  /// Returns whether the settings screen was actually opened.
  Future<bool> openAppSettings();

  /// Opens the device-level Location Services settings page (§3.3's
  /// "Kapcsold be a helymeghatározást" branch). Returns whether it opened.
  Future<bool> openLocationSettings();
}

/// No native bridge, but a fully working, test-controllable state machine —
/// the `MusicServiceStub` counterpart for location. Used automatically on
/// every platform besides Android/iOS (see `locationServiceProvider` in
/// location_service_geolocator.dart), which is exactly what every `flutter
/// test` run resolves to, so widget/unit tests get this for free without an
/// explicit provider override — matching how `music_controller_test.dart`
/// already relies on `MusicServiceStub` the same way.
class LocationServiceStub implements LocationService {
  LocationServiceStub({LocationAvailability initial = LocationAvailability.initial})
      : _current = initial;

  // `sync: true` — see MusicServiceStub's identical comment: without it, an
  // emission fired from inside an already-awaited call (e.g.
  // `requestPermission()`) could still be undelivered by the time that
  // `await` resolves in the caller, so a caller reading `currentAvailability()`
  // right after wouldn't yet reflect it. Nothing here re-enters `_emit` from
  // within a listener callback on this same stream, so sync delivery is safe.
  final _availabilityController = StreamController<LocationAvailability>.broadcast(sync: true);
  final _positionController = StreamController<LocationFix>.broadcast(sync: true);
  LocationAvailability _current;

  void _emit(LocationAvailability next) {
    _current = next;
    _availabilityController.add(next);
  }

  @override
  Stream<LocationAvailability> get availability => Stream.multi((controller) {
        // `Stream.multi`'s onListen runs synchronously at listen() time, so
        // the replay below is delivered before this method returns — unlike
        // an `async*` generator (yield _current; yield* ...), which needs at
        // least one microtask to reach its `yield*` line, creating a window
        // where an emission fired right after `.listen()` (in the same
        // synchronous scope, e.g. `service.availability.listen(...);
        // service.refresh();`) could be lost. Confirmed the hard way: an
        // earlier `async*` version of this getter dropped exactly that case
        // in `location_service_test.dart`.
        controller.add(_current);
        final sub = _availabilityController.stream.listen(
          controller.add,
          onError: controller.addError,
          onDone: controller.close,
        );
        controller.onCancel = sub.cancel;
      });

  @override
  Future<LocationAvailability> currentAvailability() async => _current;

  @override
  Future<LocationAvailability> requestPermission() async {
    if (_current.authorization == LocationAuthorization.notDetermined ||
        _current.authorization == LocationAuthorization.denied) {
      _emit(_current.copyWith(authorization: LocationAuthorization.granted));
    }
    return _current;
  }

  @override
  Future<LocationAvailability> refresh() async {
    // Re-emits even when nothing changed, matching
    // GeolocatorLocationService.refresh()'s contract — a caller relying on
    // refresh() always producing an event (not just changes) behaves the
    // same against both implementations.
    _emit(_current);
    return _current;
  }

  @override
  Stream<LocationFix> positionStream({
    required LocationTrackingProfile profile,
    String androidNotificationTitle = 'Lifey',
    String androidNotificationText = 'Recording your route',
  }) =>
      _positionController.stream;

  @override
  Future<bool> openAppSettings() async => true;

  @override
  Future<bool> openLocationSettings() async => true;

  /// Test-only: sets the availability a test wants — e.g. to simulate the
  /// user granting/denying in system Settings before the test calls
  /// [refresh], or to start a scenario already [LocationAuthorization.denied].
  void emitAvailability(LocationAvailability next) => _emit(next);

  /// Test-only: pushes a synthetic fix to [positionStream]'s active
  /// subscribers — feeds `track_filter.dart` or an active-session controller
  /// a scripted route without any real device.
  void emitFix(LocationFix fix) => _positionController.add(fix);
}
