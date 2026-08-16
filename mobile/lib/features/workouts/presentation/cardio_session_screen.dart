import 'dart:async';
import 'dart:math' as math;

import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/format/cardio_formatter.dart';
import '../../../core/health/health_controller.dart';
import '../../../core/health/health_service.dart';
import '../../../core/location/location_service.dart';
import '../../../core/location/location_service_geolocator.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/watch/watch_workout_service.dart';
import '../../../core/workout_session_notifier/workout_session_notifier_service.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/widgets/activity_chip.dart';
import '../../../shared/widgets/app_snackbar.dart';
import '../../settings/application/settings_controller.dart';
import '../../settings/domain/user_settings.dart';
import '../application/auto_pause_preferences.dart';
import '../application/workout_session_controller.dart';
import '../data/cardio_track_point_repository.dart';
import '../domain/activity_type.dart';
import '../domain/auto_pause_detector.dart';
import '../domain/cardio_personal_record.dart';
import '../domain/cardio_splits_calculator.dart';
import '../domain/route_encoder.dart';
import '../domain/track_filter.dart';
import '../domain/workout_session.dart';
import 'cardio_summary_screen.dart';
import 'widgets/auto_pause_settings_sheet.dart';
import 'widgets/prompt_number_dialog.dart';
import 'widgets/route_painter.dart';
import 'workouts_screen.dart';

/// The live cardio screen — skeleton (docs/cardio/59-cardio-implementation-plan.md
/// C2.1) plus all three family layouts: DISTANCE (C2.2), MACHINE (C2.3), and
/// GAME (C2.4), plus pause-reason visuals and slide-to-finish (C2.5).
///
/// `IDLE` never actually renders here: the screen is always constructed with
/// an already-started [session] (`startCardioSession` runs before the push —
/// today only reachable from tests, since the real entry point is C2.7's
/// quick-start flow). `ENDING` is the slide-to-finish bar built in C2.5
/// (see [_SlideToFinishBar]) — finishing never reacts to a plain tap.
///
/// ## Auto-pause hook (C2.5)
///
/// [autoPause] exists for [C4a.5](../../../../docs/cardio/59-cardio-implementation-plan.md)'s
/// GPS-driven background tracker to call later — nothing calls it yet, since
/// GPS doesn't exist until C4a. It's public (hence this State class being
/// public, not `_`-prefixed, the same shape as `FormState`/`ScaffoldState`)
/// so that future GPS code can reach it via a `GlobalKey<CardioSessionScreenState>`
/// without this screen needing to know anything about location services.
/// [pause]/[resume] are public for the same reason — a manual pause and an
/// auto-pause both freeze the same underlying moving-time checkpoint (see
/// [_PauseReason]), only the *reason*, and therefore the on-screen card,
/// differs (docs/cardio/57-cardio-design-prompt.md DD-6, M08 vs M09).
/// Resuming — whether the user taps or GPS detects motion again — is the
/// same call either way, so there's no separate `autoResume`.
///
/// ## GAME's two independent clocks (C2.4)
///
/// Every other family has one pause concept. GAME has two, and they don't
/// move together — a benched player keeps their heart rate and gross time
/// running, only playing time (`movingSeconds`, the one field that actually
/// gets synced) stops:
///
/// - [_manuallyPaused] — "Meccs szünet": a real, whole-session pause. Freezes
///   *both* playing time and gross time. This is the same concept C2.1 built
///   for every family (`_pause`/`_resume`); GAME just also gates the second
///   clock through it.
/// - [_onCourt] — GAME only: on the bench, playing time freezes but gross
///   time keeps going, exactly like a normal wall-clock stopwatch would.
///
/// `movingSeconds` therefore accrues exactly when **not manually paused AND
/// (not GAME, or on court)** — computed inline at each transition (`_pause`/
/// `_resume`/`_setOnCourt`), not as a standing getter: whether a transition
/// is *about to* satisfy that condition can't be read off current state mid-
/// transition. Gross time accrues whenever **not manually paused**, on-court
/// state notwithstanding.
///
/// Neither `_onCourt` nor gross time has a domain/Drift field to persist
/// into — the backend has no matching concept, and the domain model already
/// treats `movingSeconds` as *the* cardio duration ([56 D-C3.3], streak
/// thresholds, `effectiveDuration`). Both are therefore **local-only,
/// lost on an app kill**: reopening a killed GAME session can't tell whether
/// it was benched or manually paused when it froze, and conservatively
/// assumes the safer of the two — a full pause (see `initState`'s
/// `wasFrozen` handling). `movingSeconds` itself is unaffected by any of
/// this — it's exactly the same durable, epoch-checkpointed field C2.1 built,
/// just fed by two gates instead of one.
class CardioSessionScreen extends ConsumerStatefulWidget {
  const CardioSessionScreen({super.key, required this.session});

  final WorkoutSession session;

  @override
  ConsumerState<CardioSessionScreen> createState() => CardioSessionScreenState();
}

/// A manual pause and a system-triggered auto-pause freeze the exact same
/// moving-time checkpoint — [_manuallyPaused] alone can't tell them apart.
/// This is the orthogonal bit that decides which card the screen shows (M08
/// vs M09) — see the [CardioSessionScreenState] class doc. Never meaningful
/// for GAME: auto-pause is a DISTANCE-only, GPS-driven concept
/// (docs/cardio/53-cardio-mobile-plan.md §4.3).
enum _PauseReason { none, manual, auto }

/// The header GPS chip's four mutually-exclusive states (C4a.2's original
/// "off" plus C4a.4's "weak"/"healthy") — see [CardioSessionScreenState._gpsChipState].
enum _GpsChipState { none, off, weak, healthy }

class CardioSessionScreenState extends ConsumerState<CardioSessionScreen>
    with WidgetsBindingObserver {
  late final String _clientId;
  late final DateTime _startedAt;
  late final String _activityType;
  late int _movingSeconds;
  int? _movingSinceEpochMs;
  DateTime? _finishedAt;

  /// True whenever `movingSeconds` is frozen because of a whole-session
  /// pause (as opposed to, for GAME, just being benched) — see the class doc.
  late bool _manuallyPaused;

  /// Why [_manuallyPaused] is currently true — drives which pause card
  /// renders (M08 vs M09). Local-only, like [_onCourt] below: nothing
  /// persists it, so a reload can't distinguish a manual pause from an
  /// auto-pause either — same "assume the safer reading" call as
  /// [_manuallyPaused] itself (see `initState`).
  _PauseReason _pauseReason = _PauseReason.none;

  /// Wall-clock moment the current pause began — only meaningful while
  /// [_manuallyPaused] is true. Drives the "X ago" text on the pause card;
  /// unlike [_movingSinceEpochMs] this never gets sent anywhere, it's purely
  /// for that one line of display.
  int? _pauseStartedAtMs;

  /// GAME only; meaningless (left `true`) for every other family.
  bool _onCourt = true;

  /// GAME only, local-only (see class doc) — never synced, never read back
  /// from [WorkoutSession]. `_grossSeconds` is the total accrued *before*
  /// `_grossSinceEpochMs`, same epoch-checkpoint shape as moving-seconds.
  int _grossSeconds = 0;
  int? _grossSinceEpochMs;

  // No automatic source exists for any of these yet (GPS is C4a, a BLE
  // trainer/power-meter pairing isn't planned at all) — every one only ever
  // changes via this screen's own edit dialogs/stepper. Tracked individually
  // (rather than as a single CardioMetrics) so each edit can merge against
  // whatever the others currently hold — see [_updateCardioMetrics].
  double? _distanceMeters;
  double? _avgCadence;
  double? _avgWatts;
  int? _resistanceLevel;

  // DISTANCE only — the M27/M28 "no GPS" status card (C4a.2). Null until the
  // first `LocationService.availability` event arrives, which is fine: the
  // card only ever renders once there's a real answer, never on a guess.
  LocationAvailability? _locationAvailability;
  StreamSubscription<LocationAvailability>? _locationSub;

  /// "Nem kell most" — hides the card for the rest of *this* session only;
  /// the header's [_GpsOffChip] stays regardless (M27's own design note:
  /// measurement quality is always visible). Never persisted.
  bool _locationCardDismissed = false;
  bool _locationActionBusy = false;

  // DISTANCE only, live GPS recording (C4a.3) — active exactly while
  // running (not paused, not finished) and tracking is actually possible
  // (see [_syncPositionTracking]). Writes go straight to
  // `CardioTrackPoints`, immediately, one at a time; the closing pipeline
  // (polyline simplification, splits, C4a.6) still happens later, but the
  // *live* running distance/weak-signal state below (C4a.4) is derived from
  // the exact same fixes as they arrive.
  StreamSubscription<LocationFix>? _positionSub;

  /// Lets the watch's own End button drive the same finish flow as the
  /// in-app slide-to-finish bar (docs/40-watch-app-plan.md §8.2 decision
  /// (b)) — mirrors `LogSessionScreen`'s identical `_watchEventsSubscription`/
  /// `_onWatchEvent` exactly, just missing until now: this screen pushed
  /// `startWorkout`/`updateState` to the watch (C5.2) and answered the
  /// watch's own `WatchWorkoutSummary` via `WorkoutResumePrompt` (C5.7a), but
  /// never listened for `WatchEndRequested` itself — so ending a
  /// phone-mastered cardio session from the watch left the phone's own
  /// session running indefinitely (only the watch side actually closed).
  /// See [_onWatchEvent].
  StreamSubscription<Object>? _watchEventsSubscription;

  /// Next sequence number to assign — seeded once from the DB
  /// ([_seedTrackPointSeqAndSync]) so a session reopened after an app kill
  /// resumes numbering correctly instead of colliding with points already
  /// on disk. Incremented purely in-memory afterwards: a single live
  /// subscription is the only writer, so there's no race to guard against
  /// beyond that one seed read.
  int _nextTrackPointSeq = 0;

  /// Guards [_syncPositionTracking] from starting a subscription before
  /// [_nextTrackPointSeq] has actually been seeded — the availability
  /// listener can fire (and would otherwise try to start tracking) while
  /// that one-time DB read is still in flight.
  bool _trackPointSeqSeeded = false;

  /// §4.2's gates + running distance/elevation, replayed from every
  /// existing `CardioTrackPoints` row on open ([_seedTrackPointSeqAndSync])
  /// and then fed one fix at a time as they arrive ([_onPositionFix]) — one
  /// accumulator per session, so a resumed session continues the same
  /// running total instead of restarting from zero. `null` until seeding
  /// completes, same lifetime as [_trackPointSeqSeeded].
  TrackFilterAccumulator? _trackFilter;

  /// Whether GPS has contributed any distance yet this session (C4a.4) —
  /// once true, it's the authoritative distance source for the rest of the
  /// session: the dominant metric's manual-edit affordance disables, and
  /// `CardioMetrics.distanceSource` persists as `'MEASURED'` rather than
  /// `'MANUAL'` from here on (see [_editDistance], [_updateCardioMetrics],
  /// `_finish`). Always `false` for MACHINE/GAME, whose [_trackFilter]
  /// never exists.
  bool get _hasGpsDistance => (_trackFilter?.distanceMeters ?? 0) > 0;

  /// M10's "gyenge jel" state — true whenever GPS tracking is active but no
  /// fix has passed the accuracy gate in the last [_weakSignalThreshold].
  /// Driven by [_weakSignalTimer] (armed/disarmed in [_armWeakSignalTimer]/
  /// [_disarmWeakSignalTimer]) rather than polled from a wall-clock
  /// comparison, so it's exact and immediately testable via `tester.pump`
  /// instead of racing real elapsed time.
  bool _weakSignal = false;
  Timer? _weakSignalTimer;

  /// How long GPS tracking can go without a single accuracy-gate-passing
  /// fix before the UI calls it "weak" (M10). Deliberately much shorter
  /// than §4.3's 60 s route-gap threshold, which is a separate, later
  /// concern (marking a dashed segment on the drawn route, C4a.6) — this one
  /// is just "something looks off right now", so it should fire well before
  /// that. Not activity-specific: a lost signal is a lost signal regardless
  /// of what's being tracked.
  static const _weakSignalThreshold = Duration(seconds: 15);

  /// GPS-driven auto-pause (C4a.5a, docs/cardio/53-cardio-mobile-plan.md
  /// §4.3) — `null` for MACHINE/GAME, created once in `initState` for
  /// DISTANCE. Owns its own countdown; this screen only reacts to its two
  /// callbacks (see `initState`) and feeds it every fix, running or not
  /// (see `_onPositionFix` and `_syncPositionTracking`'s widened
  /// `shouldTrack` — an auto-paused session must keep listening in order to
  /// ever detect the motion that resumes it).
  AutoPauseDetector? _autoPauseDetector;

  /// Seeded once from [AutoPausePreferences] in `initState` (Q-D3: on by
  /// default) and refreshed once after [showAutoPauseSettingsSheet] closes
  /// — cached rather than re-read from `shared_preferences` on every fix,
  /// since [_onPositionFix] fires far more often than the setting could
  /// plausibly change.
  bool _autoPauseEnabled = true;

  Timer? _ticker;
  bool _busy = false;

  // Phone-displayed heart rate (DISTANCE/GAME's tertiary tile) — mirrors
  // `LogSessionScreen`'s identical fields/`_pollHeartRate` exactly, just
  // missing here until now: this screen showed a hardcoded '—' regardless of
  // activity type, since no source ever fed it. Two sources, same as there:
  // the watch's own live push ([WatchLiveMetrics], far more frequent) and a
  // periodic Health-store poll ([_pollHeartRate], covers a session with no
  // watch or one that fell behind on live pushes) — [_measuringOnWatch] is
  // what keeps the slower poll from clobbering a fresher live-pushed value
  // just because the Health store hasn't caught up yet.
  static const _kHrPollInterval = Duration(seconds: 5);
  static const _kHrFreshWindow = Duration(minutes: 2);
  int? _currentHeartRate;
  DateTime? _lastHrSampleAt;
  bool _showHeartRate = false;
  bool _measuringOnWatch = false;
  Timer? _hrTicker;

  /// Live progress (0..1) of an in-flight slide-to-finish drag — `0` when
  /// nothing is being dragged. A shared controller (not plain state) because
  /// two independent widgets need to read *and* write it: [_SlideToFinishBar]
  /// drives it from the raw pointer gesture, and [_FinishConfirmationOverlay]
  /// (drawn separately, higher in this screen's [Stack]) both renders it and
  /// resets it to `0` from its Cancel row — routing that through `setState`
  /// round-trips on every dragged pixel would be needless rebuild churn.
  final ValueNotifier<double> _finishProgress = ValueNotifier<double>(0);

  // Live Activity / ongoing notification bridge (C2.9) — same three-flag
  // shape as `LogSessionScreen`'s own `_startSessionNotifier`/
  // `_updateSessionNotifier`: `_startingSessionNotifier` guards against a
  // second `start()` racing the first while one is in flight,
  // `_sessionNotifierStarted`/`_sessionNotifierUnavailable` remember the
  // outcome so a later `update()` isn't wasted retrying a refusal that
  // won't change (Live Activities off, notification permission denied).
  bool _startingSessionNotifier = false;
  bool _sessionNotifierStarted = false;
  bool _sessionNotifierUnavailable = false;

  /// Watch-mirror bridge (C5.2, docs/cardio/55-cardio-watch-plan.md §5/W-2)
  /// — mirrors `LogSessionScreen`'s own `_watchStartPushed`: sent once per
  /// screen, independent of whether the Live Activity/notification above
  /// ever actually came up (that's [_sessionNotifierStarted]'s job, not
  /// this one's). Cardio has no watch-mastered case yet (no native watch
  /// build can start one, C5.4+/C5.7) so — unlike `LogSessionScreen` — there
  /// is no `_watchMastered` skip to make here.
  bool _watchStartPushed = false;

  /// "Edzés indítása az órán" Settings kapcsoló — same flag, same
  /// call-site gating rationale as `LogSessionScreen._watchEnabled`.
  bool get _watchEnabled =>
      ref.read(settingsControllerProvider).value?.watchWorkoutEnabled ?? true;

  @override
  void initState() {
    super.initState();
    _watchEventsSubscription =
        ref.read(watchWorkoutServiceProvider).events.listen(_onWatchEvent);
    final s = widget.session;
    _clientId = s.clientId;
    _startedAt = s.startedAt!;
    _activityType = s.activityType!;
    _movingSeconds = s.movingSeconds ?? 0;
    _movingSinceEpochMs = s.movingSinceEpochMs;
    _finishedAt = s.finishedAt;
    _distanceMeters = s.cardio?.distanceMeters;
    _avgCadence = s.cardio?.avgCadence;
    _avgWatts = s.cardio?.avgWatts;
    _resistanceLevel = s.cardio?.resistanceLevel;

    // A frozen `movingSinceEpochMs` on a not-yet-finished session means
    // *some* pause was active when this was last persisted — manual pause
    // and bench both freeze the same field (see class doc), so a reload
    // can't tell which. Defaulting to "manually paused" is the safe
    // reading: it surfaces a Resume button rather than silently assuming
    // the player is still on court.
    final wasFrozen = _finishedAt == null && _movingSinceEpochMs == null;
    _manuallyPaused = wasFrozen;
    if (wasFrozen) {
      // No persisted pause-reason or pause-start-time either (both are
      // local-only, see the field docs) — "just paused, right now" is the
      // least-wrong guess, same spirit as the GAME gross-time fallback right
      // below: it undercounts the true pause duration, but that's far less
      // misleading than fabricating a specific elapsed time.
      _pauseReason = _PauseReason.manual;
      _pauseStartedAtMs = DateTime.now().millisecondsSinceEpoch;
    }
    if (_family == ActivityFamily.game && _finishedAt == null) {
      if (wasFrozen) {
        // No persisted gross checkpoint to resume from (see class doc) — the
        // least-wrong estimate is "assume gross has been running since the
        // session started", i.e. every second since [_startedAt] counts,
        // same as if no pause had ever happened. That overcounts by however
        // long any actual pause lasted, but undercounting to 0 would be far
        // worse for a session that's been live for an hour.
        _grossSeconds = DateTime.now().difference(_startedAt).inSeconds;
      } else {
        _grossSinceEpochMs = _startedAt.millisecondsSinceEpoch;
      }
    }
    // Runs whenever the session isn't finished, paused or not — while
    // paused it only drives the pause card's live "X ago" text, since
    // `_liveMovingSeconds`/`_liveGrossSeconds` are frozen (no `*SinceEpochMs`
    // set) and simply return their static counts either way.
    if (_finishedAt == null) {
      _startTicker();
      _hrTicker = Timer.periodic(_kHrPollInterval, (_) => _pollHeartRate());
      _pollHeartRate(); // don't wait a full interval for the first read
    }

    // Deferred a frame, same as `LogSessionScreen` — this can run during
    // `initState`, before ancestor InheritedWidgets are guaranteed ready
    // for `AppLocalizations.of(context)`.
    if (_finishedAt == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) unawaited(_startSessionNotifier());
      });
    }

    // GPS status visibility (C4a.2) — DISTANCE only (52/54: MACHINE/GAME
    // never track location). `WidgetsBindingObserver` re-checks on app
    // resume, the one moment a permission change made in system Settings
    // (the card's own "Beállítások" action) could otherwise go unnoticed —
    // see `LocationService.availability`'s doc for why nothing pushes that
    // change on its own.
    if (_family == ActivityFamily.distance) {
      WidgetsBinding.instance.addObserver(this);
      _locationSub = ref.read(locationServiceProvider).availability.listen((a) {
        if (mounted) {
          setState(() => _locationAvailability = a);
          _syncPositionTracking();
        }
      });
      // Async on purpose (initState itself can't await) — see
      // [_trackPointSeqSeeded]'s doc for why [_syncPositionTracking] is safe
      // to call reactively before this resolves.
      unawaited(_seedTrackPointSeqAndSync());

      // C4a.5a — auto-pause. Created unconditionally here (cheap, no I/O);
      // [_autoPauseEnabled] gates whether [onSustainedStop] actually acts on
      // it, seeded right after.
      _autoPauseDetector = AutoPauseDetector(
        accuracyThresholdMeters: trackFilterProfileFor(_activityType).accuracyThresholdMeters,
        onSustainedStop: () {
          if (_autoPauseEnabled && !_manuallyPaused) unawaited(autoPause());
        },
        onMotion: () {
          if (_manuallyPaused && _pauseReason == _PauseReason.auto) unawaited(resume());
        },
      );
      unawaited(_seedAutoPauseEnabled());
    }
  }

  /// One-time DB read so [_nextTrackPointSeq] and [_trackFilter] resume
  /// correctly after an app kill mid-session (C4a.3/C4a.4) — replaying every
  /// existing point through a fresh [TrackFilterAccumulator] rebuilds the
  /// exact same running distance/elevation/reference-point state a live
  /// session would have reached, since it's the same pure gates fed the same
  /// points in the same order. A brand-new session just replays zero rows.
  Future<void> _seedTrackPointSeqAndSync() async {
    final points = await ref.read(cardioTrackPointRepositoryProvider).pointsForSession(_clientId);
    if (!mounted) return;
    _nextTrackPointSeq = points.length;
    final filter = TrackFilterAccumulator(trackFilterProfileFor(_activityType));
    for (final p in points) {
      filter.addFix(LocationFix(
        latitude: p.latitude,
        longitude: p.longitude,
        recordedAt: p.recordedAt,
        altitude: p.altitude,
        accuracy: p.accuracy,
        speed: p.speed,
      ));
    }
    _trackFilter = filter;
    if (filter.distanceMeters > 0) _distanceMeters = filter.distanceMeters;
    _trackPointSeqSeeded = true;
    _syncPositionTracking();
  }

  /// One-time read of [AutoPausePreferences] (C4a.5a) — see
  /// [_autoPauseEnabled]'s own doc for why it's cached rather than re-read
  /// per fix.
  Future<void> _seedAutoPauseEnabled() async {
    final enabled = await ref.read(autoPausePreferencesProvider).isEnabled();
    if (mounted) _autoPauseEnabled = enabled;
  }

  /// Opens [AutoPauseSettingsSheet] and refreshes [_autoPauseEnabled] from
  /// whatever the user left it as — the sheet writes straight through
  /// [AutoPausePreferences] itself, so this is just picking the new value
  /// back up for the in-flight [_autoPauseDetector] to actually honor.
  Future<void> _openAutoPauseSettings() async {
    await showAutoPauseSettingsSheet(context);
    if (mounted) unawaited(_seedAutoPauseEnabled());
  }

  /// Starts/stops the raw GPS point recording subscription to match current
  /// conditions — called whenever any of them could have changed:
  /// [_locationAvailability] updates, [_seedTrackPointSeqAndSync] finishes,
  /// and every [_pauseAs]/[resume] transition (both flip [_isRunning]).
  /// Idempotent either way — safe to call from all of those unconditionally.
  ///
  /// [shouldTrack] includes [_PauseReason.auto] alongside [_isRunning]
  /// (C4a.5a) — a manual pause has no reason to keep listening, but an
  /// auto-paused session must, or it could never detect the motion that
  /// resumes it. [_onPositionFix] is what actually tells the two apart
  /// (recording/distance only while truly running; auto-pause detection
  /// either way).
  void _syncPositionTracking() {
    final shouldTrack = _trackPointSeqSeeded &&
        _family == ActivityFamily.distance &&
        (_locationAvailability?.canTrack ?? false) &&
        (_isRunning || _pauseReason == _PauseReason.auto);
    if (shouldTrack && _positionSub == null) {
      final l10n = AppLocalizations.of(context)!;
      _positionSub = ref
          .read(locationServiceProvider)
          .positionStream(
            profile: locationTrackingProfileFor(_activityType),
            androidNotificationTitle: activityTypeLabel(l10n, _activityType),
            androidNotificationText: l10n.gpsForegroundNotificationText,
          )
          .listen(_onPositionFix);
      // Tracking just (re)started — give it [_weakSignalThreshold] to
      // produce a first/next fix before calling it weak.
      _armWeakSignalTimer();
    } else if (!shouldTrack && _positionSub != null) {
      _positionSub!.cancel();
      _positionSub = null;
      // Not tracking on purpose (finished, manually paused, GPS lost, family
      // change) — there's no signal to expect right now, so nothing should
      // read as "weak", and no stale countdown should carry over to next time.
      _disarmWeakSignalTimer();
      _autoPauseDetector?.reset();
    }
  }

  /// Writes [fix] to `CardioTrackPoints` and updates the running
  /// distance/weak-signal state (C4a.3/C4a.4) **only while truly running**
  /// — during an auto-pause, [_syncPositionTracking] keeps the subscription
  /// open purely so [_autoPauseDetector] can watch for resumed motion, not
  /// to keep recording a session that's currently frozen. The detector
  /// itself, on the other hand, always sees every fix — it's the one thing
  /// that needs to know about a fix arriving *during* the pause it caused.
  void _onPositionFix(LocationFix fix) {
    if (_isRunning) {
      final seq = _nextTrackPointSeq++;
      unawaited(ref.read(cardioTrackPointRepositoryProvider).addPoint(_clientId, seq, fix));

      final filter = _trackFilter;
      if (filter != null && filter.addFix(fix)) {
        _armWeakSignalTimer();
        if (mounted && filter.distanceMeters > 0) {
          setState(() => _distanceMeters = filter.distanceMeters);
        }
      }
    }
    _autoPauseDetector?.addFix(fix);
  }

  /// (Re)starts the countdown to [_weakSignal] — cancels any timer already
  /// running (a fresh fix resets the clock) and, if the UI was showing
  /// "weak", clears it immediately rather than waiting for the next tick.
  void _armWeakSignalTimer() {
    _weakSignalTimer?.cancel();
    if (_weakSignal && mounted) setState(() => _weakSignal = false);
    _weakSignalTimer = Timer(_weakSignalThreshold, () {
      if (mounted) setState(() => _weakSignal = true);
    });
  }

  /// Stops expecting a signal — used when tracking itself stops (pause, GPS
  /// lost), where "weak" would be a misleading label for "not trying".
  void _disarmWeakSignalTimer() {
    _weakSignalTimer?.cancel();
    _weakSignalTimer = null;
    if (_weakSignal && mounted) setState(() => _weakSignal = false);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _family == ActivityFamily.distance) {
      unawaited(ref.read(locationServiceProvider).refresh());
    }
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _hrTicker?.cancel();
    _finishProgress.dispose();
    _watchEventsSubscription?.cancel();
    _locationSub?.cancel();
    _positionSub?.cancel();
    _weakSignalTimer?.cancel();
    _autoPauseDetector?.dispose();
    if (_family == ActivityFamily.distance) WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  ActivityFamily get _family => activityFamilyOf(_activityType);

  bool get _isRunning => _finishedAt == null && !_manuallyPaused;
  bool get _isFinished => _finishedAt != null;

  /// Resolves the header chip's state in the same priority order the
  /// existing C4a.2 card already uses ("off" first — a permission/service
  /// problem outranks a signal-quality one), then adds the two new C4a.4
  /// states — [_GpsChipState.none] while tracking simply isn't expected
  /// right now (paused, or not DISTANCE), never a false "weak" reading.
  _GpsChipState get _gpsChipState {
    if (_family != ActivityFamily.distance) return _GpsChipState.none;
    final availability = _locationAvailability;
    if (availability == null) return _GpsChipState.none;
    if (!availability.canTrack) return _GpsChipState.off;
    if (!_isRunning) return _GpsChipState.none;
    return _weakSignal ? _GpsChipState.weak : _GpsChipState.healthy;
  }

  /// The number this screen actually displays — folds in the still-ticking
  /// interval while running. Mirrors `WorkoutSession.liveMovingSeconds`
  /// exactly (this screen tracks the fields locally rather than re-reading
  /// the domain object on every frame, so it's re-derived here instead of
  /// constructing a throwaway [WorkoutSession] each tick).
  int get _liveMovingSeconds {
    final since = _movingSinceEpochMs;
    if (since == null) return _movingSeconds;
    final runningSince = DateTime.fromMillisecondsSinceEpoch(since);
    return _movingSeconds + DateTime.now().difference(runningSince).inSeconds;
  }

  /// GAME only — same shape as [_liveMovingSeconds], independent checkpoint.
  int get _liveGrossSeconds {
    final since = _grossSinceEpochMs;
    if (since == null) return _grossSeconds;
    final runningSince = DateTime.fromMillisecondsSinceEpoch(since);
    return _grossSeconds + DateTime.now().difference(runningSince).inSeconds;
  }

  /// How long the current whole-session pause has lasted so far — `null`
  /// while running/finished. Feeds the "X ago" line on the pause card; ticks
  /// live because [_startTicker] keeps running through a pause (see its call
  /// site in `initState`).
  Duration? get _pausedDuration {
    final since = _pauseStartedAtMs;
    if (since == null || !_manuallyPaused) return null;
    return DateTime.now().difference(DateTime.fromMillisecondsSinceEpoch(since));
  }

  void _startTicker() {
    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  /// Polls the platform health store for the latest heart-rate sample —
  /// identical to `LogSessionScreen._pollHeartRate`, see its doc comment for
  /// the freshness-window/no-op reasoning. No-ops when finished, or when the
  /// user hasn't enabled the health connection.
  Future<void> _pollHeartRate() async {
    if (!mounted || _isFinished) return;
    final enabled = ref.read(healthControllerProvider).value ?? false;
    if (!enabled) return;

    final sample =
        await ref.read(healthServiceProvider).latestHeartRate(within: _kHrFreshWindow);
    if (!mounted) return;

    if (sample == null) {
      if (_showHeartRate && !_measuringOnWatch) setState(() => _showHeartRate = false);
      return;
    }

    if (_lastHrSampleAt != null && !sample.timestamp.isAfter(_lastHrSampleAt!)) {
      return;
    }
    _lastHrSampleAt = sample.timestamp;

    setState(() {
      _currentHeartRate = sample.bpm.round();
      _showHeartRate = true;
    });
  }

  void _showError(AppLocalizations l10n) {
    if (!mounted) return;
    AppSnackbar.showError(context, title: l10n.couldNotUpdateWorkoutMessage);
  }

  /// Runs [content]'s recovery action (request permission / open app
  /// settings / open device location settings — see [_locationCardContent])
  /// against the real [LocationService]. Never touches [_locationAvailability]
  /// directly: the action itself pushes the new state onto
  /// `LocationService.availability`, which the [_locationSub] subscription
  /// already reacts to — this only owns the button's busy spinner.
  Future<void> _handleLocationCardAction(_LocationCardContent content) async {
    if (_locationActionBusy) return;
    setState(() => _locationActionBusy = true);
    try {
      await content.onAction(ref.read(locationServiceProvider));
    } finally {
      if (mounted) setState(() => _locationActionBusy = false);
    }
  }

  /// The Live Activity / ongoing notification's cardio payload
  /// (docs/cardio/59-cardio-implementation-plan.md C2.9, D-C2.3) — the same
  /// dominant + up-to-two-secondary shape each family's body already shows
  /// on screen, pre-formatted so neither native side re-implements
  /// [CardioFormatter]. Re-derives rather than reads from the body widgets
  /// (which build their own `Text`s) since there's no shared data object
  /// between "what's on screen" and "what's in the payload" — same
  /// resigned-to-a-little-duplication trade `_finish()`'s closing
  /// `CardioMetrics` already makes.
  CardioLiveMetrics _cardioLiveMetrics(AppLocalizations l10n, UnitSystem unitSystem) {
    final movingDuration = Duration(seconds: _liveMovingSeconds);
    switch (_family) {
      case ActivityFamily.distance:
        final hasDistance = (_distanceMeters ?? 0) > 0;
        return CardioLiveMetrics(
          primaryLabel: hasDistance ? l10n.distanceFieldLabel : l10n.movingTimeLabel,
          primaryValue: hasDistance
              ? CardioFormatter.distance(_distanceMeters!, unitSystem)
              : CardioFormatter.duration(movingDuration),
          secondaryLabel: hasDistance ? l10n.movingTimeLabel : l10n.distanceFieldLabel,
          secondaryValue: hasDistance ? CardioFormatter.duration(movingDuration) : '—',
          tertiaryLabel: l10n.paceLabel,
          tertiaryValue: hasDistance
              ? (CardioFormatter.pace(_distanceMeters!, movingDuration, unitSystem) ?? '—')
              : '—',
          paused: _manuallyPaused,
          movingSecondsBase: _movingSeconds,
          movingSinceEpochMs: _movingSinceEpochMs,
        );
      case ActivityFamily.machine:
        return CardioLiveMetrics(
          primaryLabel: l10n.movingTimeLabel,
          primaryValue: CardioFormatter.duration(movingDuration),
          secondaryLabel: l10n.avgCadenceFieldLabel,
          secondaryValue: _avgCadence == null ? '—' : '${_avgCadence!.round()} rpm',
          tertiaryLabel: l10n.avgWattsFieldLabel,
          tertiaryValue: _avgWatts == null ? '—' : '${_avgWatts!.round()} W',
          paused: _manuallyPaused,
          movingSecondsBase: _movingSeconds,
          movingSinceEpochMs: _movingSinceEpochMs,
        );
      case ActivityFamily.game:
        return CardioLiveMetrics(
          primaryLabel: l10n.playingTimeLabel,
          primaryValue: CardioFormatter.duration(movingDuration),
          secondaryLabel: l10n.grossTimeLabel,
          secondaryValue: CardioFormatter.duration(Duration(seconds: _liveGrossSeconds)),
          tertiaryLabel: l10n.heartRateFieldLabel,
          tertiaryValue: '—',
          paused: _manuallyPaused,
          movingSecondsBase: _movingSeconds,
          movingSinceEpochMs: _movingSinceEpochMs,
        );
    }
  }

  /// The full state pushed to both native surfaces. [WorkoutSessionState]'s
  /// legacy strength fields ([WorkoutSessionState.exerciseName] etc.) are
  /// filled with cardio-appropriate fallbacks, not left at their defaults —
  /// see [WorkoutSessionState.kind]'s doc for why that's what actually makes
  /// the C2.9 kész-ha ("régi natív build... nem törik") true: an old native
  /// build renders exactly these fields, nothing more.
  WorkoutSessionState _liveSessionState(AppLocalizations l10n) {
    final unitSystem =
        (ref.read(settingsControllerProvider).value ?? const UserSettings.defaults())
            .unitSystem;
    final cardio = _cardioLiveMetrics(l10n, unitSystem);
    return WorkoutSessionState(
      exerciseName: '${activityTypeLabel(l10n, _activityType)} — ${cardio.primaryValue}',
      setsDone: 0,
      // Null, not 0 — `WorkoutSessionNotifierService`'s Android renderer
      // only appends the "N/total" fraction when `setsTotal` is non-null,
      // so this is what keeps a cardio session from showing "· 0/null"
      // even on today's unmodified Android branch.
      setsTotal: null,
      totalSetsDone: 0,
      kind: 'CARDIO',
      activityType: _activityType,
      cardio: cardio,
    );
  }

  /// Brings up the Live Activity / ongoing notification, and (once) tells
  /// the watch to start its own session. Safe to call repeatedly — the
  /// retry entry point as well as the first attempt: no-ops while one is in
  /// flight, once it's up, or once the platform has refused for good. Now
  /// mirrors `LogSessionScreen._startSessionNotifier` in full, including the
  /// watch-mirror push (C5.2, docs/cardio/55-cardio-watch-plan.md §5/W-2) —
  /// C2.9's own doc comment here used to note that push was left out because
  /// D-C5.1's phone-side receiver (C5.1) had to land first.
  Future<void> _startSessionNotifier() async {
    if (!mounted || _isFinished) return;

    final l10n = AppLocalizations.of(context)!;

    // Best-effort, alongside (not instead of) the Live Activity/ongoing
    // notification below, gated only on its own latch — same structure as
    // `LogSessionScreen`'s (see its doc comment for why the two starts are
    // independent).
    if (_watchEnabled && !_watchStartPushed) {
      _watchStartPushed = true;
      unawaited(ref.read(watchWorkoutServiceProvider).startWorkout(
            sessionClientId: _clientId,
            title: activityTypeLabel(l10n, _activityType),
            startedAt: _startedAt,
            state: _liveSessionState(l10n),
            activityType: _activityType,
            venue: widget.session.cardio?.venue,
          ));
    }

    if (_startingSessionNotifier || _sessionNotifierStarted || _sessionNotifierUnavailable) {
      return;
    }
    _startingSessionNotifier = true;
    try {
      final result = await ref.read(workoutSessionNotifierServiceProvider).start(
            sessionClientId: _clientId,
            title: activityTypeLabel(l10n, _activityType),
            startedAt: _startedAt,
            startedLabel: l10n.startedLabel,
            state: _liveSessionState(l10n),
          );
      _sessionNotifierStarted = result.started;
      // A retryable refusal leaves both flags false: the next state change
      // and the next foreground both try again.
      _sessionNotifierUnavailable = result.status == WorkoutSessionNotifierStatus.unavailable;
    } finally {
      _startingSessionNotifier = false;
    }
  }

  /// Pushes the current state to both surfaces. The indicator update no-ops
  /// natively when there's nothing showing (iOS finds no activity, Android
  /// has no notification to re-render), so this is safe to call after every
  /// state change regardless of whether [_startSessionNotifier] ever
  /// actually succeeded — and it has to be, because the watch push below
  /// must not be collateral damage of a Live Activity that was refused or
  /// switched off.
  Future<void> _updateSessionNotifier() async {
    if (!mounted) return;
    final l10n = AppLocalizations.of(context)!;
    final state = _liveSessionState(l10n);
    await ref.read(workoutSessionNotifierServiceProvider).update(
          sessionClientId: _clientId,
          startedLabel: l10n.startedLabel,
          state: state,
        );
    if (_watchEnabled) {
      unawaited(ref.read(watchWorkoutServiceProvider).updateState(
            sessionClientId: _clientId,
            state: state,
          ));
    }
  }

  /// "Meccs szünet" — a whole-session pause, initiated by the user tapping
  /// the Pause button. Freezes playing time *and* (for GAME) gross time; see
  /// the class doc. Public so the Pause button (below) and tests can call it
  /// directly, same shape as [autoPause].
  Future<void> pause() => _pauseAs(_PauseReason.manual);

  /// A DISTANCE-only, GPS-driven pause — see the class doc. No caller exists
  /// yet (that's C4a.5's job); this only differs from [pause] in the reason
  /// it records, which decides whether the manual (M08) or auto (M09) card
  /// renders. A no-op outside the DISTANCE family, since auto-pause isn't a
  /// concept MACHINE or GAME have (docs/cardio/53-cardio-mobile-plan.md §4.3).
  Future<void> autoPause() {
    if (_family != ActivityFamily.distance) return Future<void>.value();
    return _pauseAs(_PauseReason.auto);
  }

  Future<void> _pauseAs(_PauseReason reason) async {
    if (_busy || _manuallyPaused || _isFinished) return;
    final l10n = AppLocalizations.of(context)!;
    setState(() => _busy = true);
    final totalMoving = _liveMovingSeconds;
    final wasAccruingMoving = _movingSinceEpochMs != null;
    try {
      if (wasAccruingMoving) {
        await ref.read(workoutSessionControllerProvider.notifier).pauseCardioSession(
              _clientId,
              startedAt: _startedAt,
              movingSeconds: totalMoving,
            );
      }
      if (!mounted) return;
      setState(() {
        _manuallyPaused = true;
        _pauseReason = reason;
        _pauseStartedAtMs = DateTime.now().millisecondsSinceEpoch;
        if (wasAccruingMoving) {
          _movingSeconds = totalMoving;
          _movingSinceEpochMs = null;
        }
        if (_family == ActivityFamily.game) {
          _grossSeconds = _liveGrossSeconds;
          _grossSinceEpochMs = null;
        }
        _busy = false;
      });
      unawaited(_updateSessionNotifier());
      _syncPositionTracking(); // _isRunning just flipped false — stop recording.
    } catch (_) {
      if (!mounted) return;
      setState(() => _busy = false);
      _showError(l10n);
    }
  }

  /// Resumes from a whole-session pause — manual or auto, the call is
  /// identical either way (docs/cardio/57-cardio-design-prompt.md DD-6:
  /// nothing about *resuming* differs, only the paused-state card). Public
  /// for the same reason as [pause]/[autoPause] — GPS-driven motion
  /// detection (C4a.5) resumes exactly like a manual tap does.
  Future<void> resume() async {
    if (_busy || !_manuallyPaused || _isFinished) return;
    final l10n = AppLocalizations.of(context)!;
    setState(() => _busy = true);
    final resumedAt = DateTime.now();
    // Coming back from a whole-session pause doesn't put a benched GAME
    // player back on court — only the on-court toggle does that.
    final willAccrueMoving = _family != ActivityFamily.game || _onCourt;
    try {
      if (willAccrueMoving) {
        await ref.read(workoutSessionControllerProvider.notifier).resumeCardioSession(
              _clientId,
              startedAt: _startedAt,
              resumedAt: resumedAt,
            );
      }
      if (!mounted) return;
      setState(() {
        _manuallyPaused = false;
        _pauseReason = _PauseReason.none;
        _pauseStartedAtMs = null;
        if (willAccrueMoving) _movingSinceEpochMs = resumedAt.millisecondsSinceEpoch;
        if (_family == ActivityFamily.game) {
          _grossSinceEpochMs = resumedAt.millisecondsSinceEpoch;
        }
        _busy = false;
      });
      unawaited(_updateSessionNotifier());
      _syncPositionTracking(); // _isRunning just flipped true — (re)start recording.
    } catch (_) {
      if (!mounted) return;
      setState(() => _busy = false);
      _showError(l10n);
    }
  }

  /// GAME only — the "Pályán/Padon" toggle. Independent of [pause]/
  /// [resume]: benching never touches gross time, and re-pausing while
  /// benched is a no-op for `movingSeconds` (it's already frozen).
  Future<void> _setOnCourt(bool onCourt) async {
    if (_busy || _isFinished || _manuallyPaused || _onCourt == onCourt) return;
    final l10n = AppLocalizations.of(context)!;
    HapticFeedback.mediumImpact();
    setState(() => _busy = true);
    try {
      if (onCourt) {
        final resumedAt = DateTime.now();
        await ref.read(workoutSessionControllerProvider.notifier).resumeCardioSession(
              _clientId,
              startedAt: _startedAt,
              resumedAt: resumedAt,
            );
        if (!mounted) return;
        setState(() {
          _onCourt = true;
          _movingSinceEpochMs = resumedAt.millisecondsSinceEpoch;
          _busy = false;
        });
        unawaited(_updateSessionNotifier());
      } else {
        final total = _liveMovingSeconds;
        await ref.read(workoutSessionControllerProvider.notifier).pauseCardioSession(
              _clientId,
              startedAt: _startedAt,
              movingSeconds: total,
            );
        if (!mounted) return;
        setState(() {
          _onCourt = false;
          _movingSeconds = total;
          _movingSinceEpochMs = null;
          _busy = false;
        });
        unawaited(_updateSessionNotifier());
      }
    } catch (_) {
      if (!mounted) return;
      setState(() => _busy = false);
      _showError(l10n);
    }
  }

  /// The watch's End button asking the phone to close this session — mirrors
  /// `LogSessionScreen._onWatchEvent`'s identical `WatchEndRequested` branch.
  /// No-op if this screen isn't showing the matching session, or it's
  /// already finished/finishing. `event.rpe` (whatever the watch's own
  /// effort stepper produced) is dropped: unlike a STRENGTH session, cardio
  /// has no RPE entry point at finish time at all — [CardioSummaryScreen]
  /// owns that, from either origin, exactly the same as [_finish]'s own
  /// phone-initiated call already leaves it unset.
  void _onWatchEvent(Object event) {
    switch (event) {
      case WatchEndRequested():
        if (event.sessionClientId != _clientId) return;
        unawaited(_finish());
      case WatchStartedOnWatch():
        if (event.sessionClientId != _clientId || !mounted) return;
        setState(() => _measuringOnWatch = true);
      case WatchReachabilityChanged():
        if (event.reachable || !mounted) return;
        setState(() => _measuringOnWatch = false);
      case WatchLiveMetrics():
        // The watch is the more real-time heart-rate source while it's
        // actively measuring — see [_pollHeartRate]'s doc for why the two
        // sources coexist rather than one replacing the other.
        if (event.sessionClientId != _clientId || !mounted) return;
        if (event.heartRateBpm == null) return;
        setState(() {
          _currentHeartRate = event.heartRateBpm!.round();
          _showHeartRate = true;
          _lastHrSampleAt = DateTime.now();
        });
      default:
        break;
    }
  }

  /// The **only** in-app way a live cardio session ends — reached
  /// exclusively through [_SlideToFinishBar]'s drag-past-threshold or
  /// long-press, never a plain tap (docs/cardio/59-cardio-implementation-plan.md
  /// C2.5 kész-ha) — or, now, [_onWatchEvent]'s `WatchEndRequested` branch,
  /// which reaches this the same way the watch already drives
  /// `LogSessionScreen`'s finish flow.
  /// The confirmation text that used to live in a tap-through `AlertDialog`
  /// now overlays the drag itself — see `_FinishConfirmationOverlay` — so
  /// there's no separate confirm step to bypass.
  /// Ends the session and hands off to [CardioSummaryScreen] — that screen,
  /// not this one, owns everything past this point (RPE, manual edits,
  /// re-viewing later — docs/cardio/59-cardio-implementation-plan.md C2.8).
  /// `pushReplacement`, not `push`: this screen has nothing left to show
  /// once finished (no controls, no live numbers), so it doesn't belong on
  /// the back stack underneath the summary.
  Future<void> _finish() async {
    if (_busy || _isFinished) return;
    final l10n = AppLocalizations.of(context)!;
    final navigator = Navigator.of(context);
    setState(() => _busy = true);
    final total = _liveMovingSeconds;
    final finishedAt = DateTime.now();
    // The GPS route closing pipeline (docs/cardio/54-cardio-gps-route-plan.md
    // §5, C4a.6): simplify → encode → splits, folded into the same outbox
    // write `finishCardioSession` already makes below — one write, not two.
    // MACHINE/GAME and any DISTANCE session with no GPS trail (permission
    // denied, indoor) leave `routeCardio` null and finish exactly as before;
    // their metrics were already persisted live via `_updateCardioMetrics`.
    final trail = _trackFilter?.trail ?? const [];
    CardioMetrics? routeCardio;
    List<CardioSplit> routeSplits = const [];
    if (_family == ActivityFamily.distance && trail.isNotEmpty) {
      final encoded = encodeRoute(trail);
      routeSplits = computeSplits(trail);
      final originalCardio = widget.session.cardio;
      // elevationGainMeters is never null on the accumulator itself (it
      // starts at 0 and only grows) — but "0 m gain" and "no altitude data
      // at all" are different facts, and only the latter should hide the
      // elevation-gain tile/profile downstream (CardioSummaryScreen gates on
      // null). A trail with zero altitude readings genuinely has neither.
      final hasAltitude = trail.any((p) => p.altitude != null);
      routeCardio = CardioMetrics(
        distanceMeters: _trackFilter!.distanceMeters,
        elevationGainMeters: hasAltitude ? _trackFilter!.elevationGainMeters : null,
        avgCadence: _avgCadence,
        avgWatts: _avgWatts,
        resistanceLevel: _resistanceLevel,
        venue: originalCardio?.venue,
        intensity: originalCardio?.intensity,
        scorePoints: originalCardio?.scorePoints,
        distanceSource: 'MEASURED',
        routePolyline: encoded.polyline,
        routePointCount: encoded.pointCount,
      );
    }
    try {
      await ref.read(workoutSessionControllerProvider.notifier).finishCardioSession(
            _clientId,
            startedAt: _startedAt,
            finishedAt: finishedAt,
            movingSeconds: total,
            cardio: routeCardio == null ? const Value.absent() : Value(routeCardio),
            splits: routeCardio == null ? const Value.absent() : Value(routeSplits),
          );
      if (!mounted) return;
      _ticker?.cancel();
      unawaited(ref.read(workoutSessionNotifierServiceProvider).end());
      // Keyed on the push having happened, not on whether the watch is
      // actually available/paired — same reasoning as `LogSessionScreen`'s
      // `_watchStartPushed` check at its own `endWorkout` call: a no-op
      // `startWorkout` (unavailable/disabled) still deserves a matching
      // `endWorkout` no-op, cheaper than tracking "did the watch really get
      // it" just to skip a call that's already a safe no-op on its own.
      if (_watchStartPushed) {
        unawaited(ref.read(watchWorkoutServiceProvider).endWorkout(_clientId));
      }
      // So the summary screen's back button lands on the session list
      // (docs/cardio/59-cardio-implementation-plan.md) instead of wherever
      // the shell happened to be showing when this workout was started —
      // the FAB long-press that starts a quick cardio session is reachable
      // from any tab, not just Workouts. Switching the shell now, while
      // it's hidden underneath the still-showing CardioSessionScreen, is
      // invisible to the user; only the eventual pop reveals it.
      // `GoRouter.maybeOf` guards this screen being pumped without a
      // router at all, as every existing widget test here does (plain
      // `MaterialApp`) — a no-op there, never reached in the real app.
      ref.read(workoutsSessionsTabRequestProvider.notifier).request();
      if (GoRouter.maybeOf(context) != null) context.go('/workouts');
      // Reuses the exact object just persisted above when a route was
      // recorded — this is the same CardioMetrics, not a second,
      // display-only approximation of it (see the doc comment above).
      final displayCardio = routeCardio ??
          CardioMetrics(
            distanceMeters: _distanceMeters,
            avgCadence: _avgCadence,
            avgWatts: _avgWatts,
            resistanceLevel: _resistanceLevel,
            venue: widget.session.cardio?.venue,
            intensity: widget.session.cardio?.intensity,
            scorePoints: widget.session.cardio?.scorePoints,
            distanceSource: _hasGpsDistance ? 'MEASURED' : (_distanceMeters == null ? null : 'MANUAL'),
          );
      final finishedSession = WorkoutSession(
        clientId: _clientId,
        exercises: const [],
        sets: const [],
        startedAt: _startedAt,
        finishedAt: finishedAt,
        sessionKind: 'CARDIO',
        activityType: _activityType,
        movingSeconds: total,
        cardio: displayCardio,
        splits: routeSplits,
      );
      // Baseline is every other cardio session already known locally — read
      // once, here, rather than a dedicated repository query: the whole list
      // is already resident via `workoutSessionControllerProvider`
      // (`watchAll()`), and the strength engine's own `getPrBaseline` is the
      // only place that owns a second raw-row query, for a table
      // (`exerciseSets`) `WorkoutSession` doesn't already assemble.
      final priorSessions = (ref.read(workoutSessionControllerProvider).value ?? const [])
          .where((s) => s.clientId != _clientId);
      final newRecords = detectCardioPrs(
        CardioPrBaseline.fromSessions(priorSessions),
        finishedSession,
      );
      navigator.pushReplacement(
        MaterialPageRoute(
          builder: (_) => CardioSummaryScreen(session: finishedSession, newRecords: newRecords),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _busy = false);
      _showError(l10n);
    }
  }

  /// Opens a dialog to manually set the distance-so-far — the only source
  /// for a DISTANCE session's distance until GPS starts contributing
  /// ([_hasGpsDistance]), after which it's disabled: overwriting a live GPS
  /// total by hand would just be immediately re-overwritten by the next fix.
  /// Also used by MACHINE's distance tile (a stationary bike's own distance
  /// is an estimate anyway — docs/cardio/design M05 note — and MACHINE never
  /// has a [_trackFilter], so [_hasGpsDistance] is always false there).
  Future<void> _editDistance() async {
    if (_busy || _isFinished || _hasGpsDistance) return;
    final l10n = AppLocalizations.of(context)!;
    final unitSystem =
        (ref.read(settingsControllerProvider).value ?? const UserSettings.defaults())
            .unitSystem;
    final imperial = unitSystem == UnitSystem.imperial;
    final unitMeters = imperial ? 1609.344 : 1000.0;
    final current = _distanceMeters;
    final result = await promptNumber(
      context,
      l10n,
      title: l10n.editDistanceDialogTitle,
      suffix: imperial ? 'mi' : 'km',
      initialText: current == null ? '' : (current / unitMeters).toStringAsFixed(2),
    );
    if (result == null || result < 0 || !mounted) return;
    await _updateCardioMetrics(distanceMeters: result * unitMeters);
  }

  Future<void> _editCadence() async {
    if (_busy || _isFinished) return;
    final l10n = AppLocalizations.of(context)!;
    final result = await promptNumber(
      context,
      l10n,
      title: l10n.editCadenceDialogTitle,
      suffix: 'rpm',
      initialText: _avgCadence?.round().toString() ?? '',
    );
    if (result == null || result < 0 || !mounted) return;
    await _updateCardioMetrics(avgCadence: result);
  }

  Future<void> _editPower() async {
    if (_busy || _isFinished) return;
    final l10n = AppLocalizations.of(context)!;
    final result = await promptNumber(
      context,
      l10n,
      title: l10n.editPowerDialogTitle,
      suffix: 'W',
      initialText: _avgWatts?.round().toString() ?? '',
    );
    if (result == null || result < 0 || !mounted) return;
    await _updateCardioMetrics(avgWatts: result);
  }

  Future<void> _adjustResistance(int delta) async {
    if (_busy || _isFinished) return;
    final next = ((_resistanceLevel ?? 0) + delta).clamp(0, 1 << 30);
    await _updateCardioMetrics(resistanceLevel: next);
  }

  /// Persists one changed field, **merged** against whatever the others
  /// currently hold — omitting a parameter here means "use the value already
  /// in state", not "clear it". Each `_edit*`/`_adjust*` caller passes only
  /// the field it changed; this reconstructs the full `CardioMetrics` every
  /// time because [WorkoutSessionRepository.update]'s `cardio` parameter is
  /// a full replace, same as `LogCardioSheet`'s submit.
  Future<void> _updateCardioMetrics({
    double? distanceMeters,
    double? avgCadence,
    double? avgWatts,
    int? resistanceLevel,
  }) async {
    final l10n = AppLocalizations.of(context)!;
    final newDistance = distanceMeters ?? _distanceMeters;
    final newCadence = avgCadence ?? _avgCadence;
    final newWatts = avgWatts ?? _avgWatts;
    final newResistance = resistanceLevel ?? _resistanceLevel;
    setState(() => _busy = true);
    try {
      await ref.read(workoutSessionControllerProvider.notifier).updateLiveCardioMetrics(
            _clientId,
            startedAt: _startedAt,
            cardio: CardioMetrics(
              distanceMeters: newDistance,
              avgCadence: newCadence,
              avgWatts: newWatts,
              resistanceLevel: newResistance,
              // GPS wins permanently once it's contributed anything this
              // session ([_hasGpsDistance]'s own doc) — even a call that's
              // only changing cadence/watts/resistance still carries the
              // *current* distance along in this merged `CardioMetrics`, and
              // that value is GPS-sourced whenever `_hasGpsDistance` is true,
              // regardless of which field this particular call is editing.
              distanceSource: _hasGpsDistance ? 'MEASURED' : (newDistance == null ? null : 'MANUAL'),
            ),
          );
      if (!mounted) return;
      setState(() {
        _distanceMeters = newDistance;
        _avgCadence = newCadence;
        _avgWatts = newWatts;
        _resistanceLevel = newResistance;
        _busy = false;
      });
      unawaited(_updateSessionNotifier());
    } catch (_) {
      if (!mounted) return;
      setState(() => _busy = false);
      _showError(l10n);
    }
  }

  Widget _distanceBody(BuildContext context, AppLocalizations l10n, ThemeData theme, ColorScheme scheme) {
    final unitSystem =
        (ref.watch(settingsControllerProvider).value ?? const UserSettings.defaults())
            .unitSystem;
    final hasDistance = (_distanceMeters ?? 0) > 0;
    final duration = Duration(seconds: _liveMovingSeconds);

    // The dominant slot always shows distance once there's one to show — the
    // "cél alakú szám" rule (docs/cardio/57-cardio-design-prompt.md DD-5) —
    // falling back to moving time only while nothing's been entered yet, so
    // the screen never shows a giant "0.00 km".
    final dominantLabel = hasDistance ? l10n.distanceFieldLabel : l10n.movingTimeLabel;
    final dominantValue = hasDistance
        ? CardioFormatter.distance(_distanceMeters!, unitSystem)
        : CardioFormatter.duration(duration);
    final secondaryLabel = hasDistance ? l10n.movingTimeLabel : l10n.distanceFieldLabel;
    final secondaryValue = hasDistance ? CardioFormatter.duration(duration) : '—';

    // M10: while the signal's weak, pace is blanked rather than showing a
    // stale average — "a tempó nem hazudik" — and the distance number (still
    // shown, since it's a monotonic total that stays meaningful even through
    // a gap) is labelled "estimated" instead. M04's healthy state shows
    // neither: a plain "GPS" chip is enough there.
    final weakSignal = _weakSignal;
    final paceLabel = weakSignal ? l10n.noSignalLabel : l10n.paceLabel;
    final paceValue = weakSignal
        ? '—:—'
        : (hasDistance ? (CardioFormatter.pace(_distanceMeters!, duration, unitSystem) ?? '—') : '—');

    final metrics = Theme.of(context).extension<AppMetricColors>();
    final accent = activityTypeColor(_activityType, context);
    // M04's route card, drawn from the same filtered trail the splits and
    // the summary polyline come from — the live screen's one "picture"
    // region. Nothing to draw before the first fixes land, and MACHINE/GAME
    // never have a trail at all.
    final trail = _trackFilter?.trail ?? const [];
    final routePolyline = trail.length >= 2 ? encodeRoute(trail).polyline : '';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // "Szünetben a domináns szám és a metrikák kiszürkülnek" — M08's
        // note: nothing here is still ticking, so graying it out keeps that
        // obvious without disabling the tap-to-edit affordances underneath
        // (those stay live on purpose — a paused session is exactly when
        // correcting a metric by hand is easiest).
        Opacity(
          opacity: _isRunning ? 1 : 0.62,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _DominantMetric(
                label: dominantLabel,
                badge: (hasDistance && weakSignal) ? l10n.distanceEstimatedBadgeLabel : null,
                labelColor: _pauseReason == _PauseReason.auto ? _kAutoAccent : null,
                value: dominantValue,
                onTap: _busy || _isFinished || _hasGpsDistance ? null : _editDistance,
              ),
              const SizedBox(height: 18),
              _MetricRow(
                children: [
                  _MetricTile(
                    icon: hasDistance ? Icons.schedule : Icons.straighten,
                    iconColor: metrics?.protein,
                    label: secondaryLabel,
                    value: secondaryValue,
                    // M11: with no distance source the empty tile is the
                    // call to action — dashed border, "írd be" affordance.
                    outlined: !hasDistance,
                    onTap: hasDistance || _busy || _isFinished ? null : _editDistance,
                  ),
                  _MetricTile(
                    icon: Icons.speed,
                    iconColor: weakSignal ? scheme.secondary : accent,
                    label: paceLabel,
                    value: paceValue,
                    color: weakSignal ? scheme.secondary : null,
                  ),
                  _MetricTile(
                    icon: Icons.favorite,
                    iconColor: metrics?.heart,
                    label: l10n.heartRateFieldLabel,
                    value: _showHeartRate && _currentHeartRate != null
                        ? '$_currentHeartRate bpm'
                        : '—',
                  ),
                ],
              ),
            ],
          ),
        ),
        if (routePolyline.isNotEmpty) ...[
          const SizedBox(height: 14),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: Container(
                color: scheme.surfaceContainerLow,
                child: RoutePainter(polyline: routePolyline, height: 200),
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _machineBody(BuildContext context, AppLocalizations l10n, ThemeData theme, ColorScheme scheme) {
    final unitSystem =
        (ref.watch(settingsControllerProvider).value ?? const UserSettings.defaults())
            .unitSystem;
    final duration = Duration(seconds: _liveMovingSeconds);

    // Unlike DISTANCE, MACHINE's dominant slot never switches — moving time
    // always wins here (docs/cardio/57-cardio-design-prompt.md §2 and
    // docs/cardio/53-cardio-mobile-plan.md §4.2 agree, no doc conflict this
    // time), so it isn't tappable: there's nothing to manually override.
    final metrics = theme.extension<AppMetricColors>();
    final accent = activityTypeColor(_activityType, context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Opacity(
          opacity: _isRunning ? 1 : 0.62,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _DominantMetric(
                label: l10n.movingTimeLabel,
                value: CardioFormatter.duration(duration),
              ),
              const SizedBox(height: 18),
              _MetricRow(
                children: [
                  _MetricTile(
                    icon: Icons.straighten,
                    iconColor: accent,
                    label: l10n.distanceFieldLabel,
                    value: _distanceMeters == null
                        ? '—'
                        : CardioFormatter.distance(_distanceMeters!, unitSystem),
                    outlined: _distanceMeters == null,
                    onTap: _busy || _isFinished ? null : _editDistance,
                  ),
                  _MetricTile(
                    icon: Icons.autorenew,
                    iconColor: metrics?.protein,
                    label: l10n.avgCadenceFieldLabel,
                    value: _avgCadence == null ? '—' : '${_avgCadence!.round()} rpm',
                    outlined: _avgCadence == null,
                    onTap: _busy || _isFinished ? null : _editCadence,
                  ),
                  _MetricTile(
                    icon: Icons.bolt,
                    iconColor: metrics?.calories,
                    label: l10n.avgWattsFieldLabel,
                    value: _avgWatts == null ? '—' : '${_avgWatts!.round()} W',
                    outlined: _avgWatts == null,
                    onTap: _busy || _isFinished ? null : _editPower,
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        // M05: the resistance stepper lives *inside* a card, not on the
        // metric row — "nem metrika, hanem beállítás". (The frame's cadence
        // chart above it needs a per-second cadence history the app doesn't
        // record, so the card carries the stepper alone.)
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Container(
            padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
            decoration: BoxDecoration(
              color: scheme.surfaceContainerLow,
              borderRadius: BorderRadius.circular(24),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    l10n.resistanceLevelFieldLabel,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                      letterSpacing: 1.2,
                    ),
                  ),
                ),
                _StepperButton(
                  icon: Icons.remove,
                  onPressed: _busy || _isFinished || (_resistanceLevel ?? 0) <= 0
                      ? null
                      : () => _adjustResistance(-1),
                ),
                SizedBox(
                  width: 34,
                  child: Text(
                    '${_resistanceLevel ?? 0}',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 19,
                      fontWeight: FontWeight.w800,
                      fontFeatures: [FontFeature.tabularFigures()],
                    ),
                  ),
                ),
                _StepperButton(
                  icon: Icons.add,
                  onPressed: _busy || _isFinished ? null : () => _adjustResistance(1),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  /// The GAME layout. **Deliberately no score/box-score counter** — Q-D2
  /// (docs/cardio/59-cardio-implementation-plan.md §1.2, "a GAME pont/gól-
  /// számláló alapból látszik-e") is an open product question this step
  /// doesn't resolve; 53-cardio-mobile-plan.md's own table tags the live
  /// point/goal stepper "(C9)" — a later, sport-specific iteration — so
  /// leaving it out isn't a gap, it's following that doc's own placement.
  /// (`LogCardioSheet`'s C1.9 points stepper is unrelated: that's a
  /// post-hoc, one-time entry on a finished session, not a live, distracting-
  /// during-play counter — the concern Q-D2 is actually about.)
  Widget _gameBody(BuildContext context, AppLocalizations l10n, ThemeData theme, ColorScheme scheme) {
    final playingDuration = Duration(seconds: _liveMovingSeconds);
    final grossDuration = Duration(seconds: _liveGrossSeconds);

    final metrics = theme.extension<AppMetricColors>();
    // M07: on the bench the dominant number greys out and the *gross* time
    // gets the highlight border instead — "látszik, hogy a mérés nem állt
    // le, csak átterelődött".
    final benched = !_onCourt && !_manuallyPaused;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _DominantMetric(
          label: benched ? l10n.playingTimeStoppedLabel : l10n.playingTimeRunningLabel,
          leading: benched
              ? const Icon(Icons.pause_circle, size: 15, color: _kAutoAccent)
              : Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(shape: BoxShape.circle, color: scheme.primary),
                ),
          labelColor: benched ? _kAutoAccent : scheme.primary,
          value: CardioFormatter.duration(playingDuration),
          valueColor: benched ? scheme.onSurfaceVariant.withValues(alpha: 0.7) : null,
        ),
        const SizedBox(height: 18),
        _MetricRow(
          children: [
            _MetricTile(
              icon: Icons.hourglass_top,
              iconColor: benched ? _kAutoAccent : scheme.onSurfaceVariant,
              label: benched ? l10n.grossTimeRunningLabel : l10n.grossTimeLabel,
              value: CardioFormatter.duration(grossDuration),
              highlighted: benched,
            ),
            _MetricTile(
              icon: Icons.favorite,
              iconColor: metrics?.heart,
              label: l10n.heartRateFieldLabel,
              value: _showHeartRate && _currentHeartRate != null ? '$_currentHeartRate bpm' : '—',
            ),
            _MetricTile(
              icon: Icons.signal_cellular_alt,
              iconColor: scheme.onSurfaceVariant,
              label: l10n.zoneFieldLabel,
              value: '—',
            ),
          ],
        ),
        if (benched) ...[
          const SizedBox(height: 14),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: _BenchedNoticeCard(
              title: l10n.benchedNoticeTitle,
              body: l10n.benchedNoticeBody,
            ),
          ),
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    // No "finished" branch here: `_finish()` navigates straight to
    // `CardioSummaryScreen` (C2.8) rather than setting local state, and
    // `open_workout_screens.dart` — the only real entry point — never
    // constructs this screen with an already-finished session in the first
    // place, so `_isFinished` never actually flips true while this widget
    // is on screen to render.
    final paused = !_isRunning;

    final Widget familyBody;
    switch (_family) {
      case ActivityFamily.distance:
        familyBody = _distanceBody(context, l10n, theme, scheme);
      case ActivityFamily.machine:
        familyBody = _machineBody(context, l10n, theme, scheme);
      case ActivityFamily.game:
        familyBody = _gameBody(context, l10n, theme, scheme);
    }

    // M27/M28 (C4a.2) — computed once here rather than inline in the Column
    // below, since both the header chip and the card itself need to agree
    // on "is there actually an issue right now".
    final availability = _locationAvailability;
    final locationCardContent = (_family == ActivityFamily.distance &&
            !_locationCardDismissed &&
            availability != null)
        ? _locationCardContent(l10n, availability)
        : null;
    // C4a.4 — same resolved state feeds the header chip, the weak-signal
    // banner below, and `_distanceBody`'s badge/pace, so it's read once here.
    final gpsChipState = _gpsChipState;

    final autoPaused = paused && _pauseReason == _PauseReason.auto;

    return Scaffold(
      backgroundColor: scheme.surface,
      body: SafeArea(
        child: Stack(
          children: [
            Column(
              children: [
                // M09's first of three auto-pause signals: a full-width amber
                // rail above everything, so the state is readable before a
                // single word is.
                if (autoPaused)
                  Container(height: 5, color: _kAutoAccent),
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 8, 14, 0),
                  child: _ActivityHeaderBar(
                    activityType: _activityType,
                    title: activityTypeLabel(l10n, _activityType),
                    status: _headerStatusPill(l10n, scheme, gpsChipState),
                    // C4a.5a — the "Kikapcsolható" half of auto-pause;
                    // DISTANCE only. M04 has no slot for it, so it rides in
                    // the header bar's trailing corner rather than growing a
                    // second bar of its own.
                    onSettings: _family == ActivityFamily.distance
                        ? () => unawaited(_openAutoPauseSettings())
                        : null,
                    settingsTooltip: l10n.autoPauseSettingsIconTooltip,
                  ),
                ),
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (paused) ...[
                          const SizedBox(height: 14),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 14),
                            child: _PauseStatusCard(
                              l10n: l10n,
                              auto: autoPaused,
                              elapsed: _pausedDuration,
                            ),
                          ),
                        ],
                        if (locationCardContent != null) ...[
                          const SizedBox(height: 12),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 14),
                            child: _LocationStatusCard(
                              content: locationCardContent,
                              dismissLabel: l10n.locationDismissButton,
                              busy: _locationActionBusy,
                              onAction: () => _handleLocationCardAction(locationCardContent),
                              onDismiss: () => setState(() => _locationCardDismissed = true),
                            ),
                          ),
                        ],
                        // M10 — mutually exclusive with the card above: this only
                        // ever shows once `canTrack` is already true (see
                        // `_gpsChipState`), never alongside a permission/service
                        // problem. Not dismissible on purpose — it should track
                        // the live signal state, not a one-time acknowledgement.
                        if (gpsChipState == _GpsChipState.weak) ...[
                          const SizedBox(height: 12),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 14),
                            child: _WeakSignalBanner(text: l10n.gpsWeakSignalBannerBody),
                          ),
                        ],
                        const SizedBox(height: 26),
                        familyBody,
                        const SizedBox(height: 20),
                      ],
                    ),
                  ),
                ),
                _bottomControls(l10n, scheme, paused: paused, autoPaused: autoPaused),
              ],
            ),
            _FinishConfirmationOverlay(
              progress: _finishProgress,
              title: l10n.finishCardioConfirmTitle,
              message: l10n.finishCardioConfirmMessage,
              cancelLabel: l10n.slideToFinishCancelLabel,
              progressHint: l10n.slideToFinishProgressHint,
              summary: _finishSummaryLine(l10n),
            ),
          ],
        ),
      ),
    );
  }

  /// The header bar's right-hand pill (M04 "GPS" · M10 "Gyenge" · M11 "Nincs
  /// GPS" · M05/M06 venue) — one slot, filled by whichever state is
  /// currently true. MACHINE/GAME have no GPS at all, so they fall through
  /// to the neutral indoor pill instead of showing nothing.
  Widget? _headerStatusPill(AppLocalizations l10n, ColorScheme scheme, _GpsChipState state) {
    return switch (state) {
      _GpsChipState.healthy => _StatusPill(
          icon: Icons.gps_fixed,
          label: l10n.gpsHealthyChipLabel,
          color: scheme.primary,
          tinted: true,
        ),
      _GpsChipState.weak => _StatusPill(
          icon: Icons.gps_not_fixed,
          label: l10n.gpsWeakChipLabel,
          color: scheme.secondary,
          tinted: true,
        ),
      _GpsChipState.off => _StatusPill(
          icon: Icons.location_disabled,
          label: l10n.locationOffChipLabel,
          color: scheme.onSurfaceVariant,
        ),
      // M05/M06's "Beltéri" / "Terem" pill — the same slot, saying the one
      // true thing about a session that never had a GPS story to tell.
      _GpsChipState.none => _family == ActivityFamily.distance
          ? null
          : _StatusPill(
              icon: Icons.home,
              label: l10n.indoorVenueChipLabel,
              color: scheme.onSurfaceVariant,
            ),
    };
  }

  /// M12's confirmation body line — the actual numbers being locked in
  /// ("5,24 km · 28:14"), so the last screen before saving is also the last
  /// chance to notice it's the wrong session.
  String _finishSummaryLine(AppLocalizations l10n) {
    final unitSystem =
        (ref.watch(settingsControllerProvider).value ?? const UserSettings.defaults()).unitSystem;
    final duration = Duration(seconds: _liveMovingSeconds);
    final hasDistance = (_distanceMeters ?? 0) > 0;
    final pace = hasDistance && _family == ActivityFamily.distance
        ? CardioFormatter.pace(_distanceMeters!, duration, unitSystem)
        : null;
    final parts = <String>[
      if (hasDistance) CardioFormatter.distance(_distanceMeters!, unitSystem),
      CardioFormatter.duration(duration),
      if (pace != null) pace,
    ];
    return parts.join(' · ');
  }

  /// The bottom control block — M04/M05/M10/M11's three-circle row while
  /// running, M08/M09's resume affordance plus slide-to-finish while paused,
  /// and GAME's own full-width pause bar (M06/M07).
  ///
  /// One deliberate departure from the frames: **the slide-to-finish bar
  /// stays reachable while running.** M04 only shows it in the paused state,
  /// which would mean "pause before you can finish" — a behavior change, not
  /// a restyle, so the bar keeps its place under the circle row.
  Widget _bottomControls(
    AppLocalizations l10n,
    ColorScheme scheme, {
    required bool paused,
    required bool autoPaused,
  }) {
    final children = <Widget>[];

    if (_family == ActivityFamily.game) {
      children.add(_CourtSwitch(
        onCourt: _onCourt,
        onCourtLabel: l10n.onCourtLabel,
        onBenchLabel: l10n.onBenchLabel,
        hint: _onCourt ? l10n.courtSwitchHint : l10n.benchSwitchHint,
        enabled: !(_busy || _isFinished || _manuallyPaused),
        onChanged: _setOnCourt,
      ));
      children.add(const SizedBox(height: 14));
    }

    if (paused) {
      children.add(
        autoPaused
            ? _AutoPauseResumeButton(
                onPressed: _busy ? null : resume,
                titleLabel: l10n.autoPauseResumeHintTitle,
                subtitleLabel: l10n.autoPauseResumeHintSubtitle,
              )
            : _ResumeButton(onPressed: _busy ? null : resume, label: l10n.resumeButtonLabel),
      );
    } else if (_family == ActivityFamily.game) {
      // M06/M07: GAME pauses through a full-width bar, not a circle — a
      // "meccs szünet" stops both clocks and is a rarer, more deliberate
      // action than the court/bench toggle above it.
      children.add(_WideActionButton(
        icon: Icons.pause,
        label: l10n.gameMatchPauseLabel,
        onPressed: _busy ? null : pause,
      ));
    } else {
      children.add(_RunningControlRow(
        onPause: _busy ? null : pause,
        pauseLabel: l10n.pauseButtonLabel,
        leading: _family == ActivityFamily.distance
            ? _CircleAction(
                icon: Icons.timer_outlined,
                label: l10n.autoPauseCircleLabel,
                onPressed: () => unawaited(_openAutoPauseSettings()),
              )
            : null,
        trailing: _trailingCircle(l10n),
      ));
    }

    children.add(const SizedBox(height: 14));
    children.add(
      SizedBox(
        key: const Key('slideToFinishBar'),
        child: _SlideToFinishBar(
          progress: _finishProgress,
          onFinish: _finish,
          label: l10n.slideToFinishLabel,
          releaseLabel: l10n.slideToFinishReleaseLabel,
        ),
      ),
    );

    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
      child: Column(mainAxisSize: MainAxisSize.min, children: children),
    );
  }

  /// The right-hand circle of the running control row: M11's "Táv" quick
  /// entry whenever distance is still hand-editable, otherwise M05's live
  /// heart-rate readout. Null when neither applies — the row then centers
  /// the pause button on its own.
  Widget? _trailingCircle(AppLocalizations l10n) {
    final canEditDistance = !_isFinished && !_hasGpsDistance && _family != ActivityFamily.game;
    if (canEditDistance) {
      return _CircleAction(
        icon: Icons.straighten,
        label: l10n.distanceCircleLabel,
        onPressed: _busy ? null : _editDistance,
      );
    }
    if (_showHeartRate && _currentHeartRate != null) {
      return _CircleAction(
        icon: Icons.favorite,
        label: '$_currentHeartRate',
        color: Theme.of(context).extension<AppMetricColors>()?.heart,
        onPressed: null,
      );
    }
    return null;
  }
}

/// M09's amber auto-pause accent — the design's own literal tone for "the
/// system did this, not you" (DD-6). Matching it to a semantic theme color
/// would be a coincidence, so it stays a named constant.
const Color _kAutoAccent = Color(0xFFC49A6C);

/// What to show on the in-session "no GPS" card (C4a.2, M27/M28) for a given
/// [LocationAvailability] — `null` from [_locationCardContent] when tracking
/// is fully available, meaning there's nothing to show. [onAction] receives
/// the live [LocationService] so the button can call the right recovery
/// method for the exact cause (docs/cardio/54-cardio-gps-route-plan.md
/// §3.3's state matrix).
typedef _LocationCardContent = ({
  IconData icon,
  String title,
  String body,
  String buttonLabel,
  Future<void> Function(LocationService) onAction,
});

/// Resolves [availability] to the exact card content + recovery action,
/// checked in the same priority order as docs/cardio/54 §3.3's table:
/// permanently-denied first (the only case with no in-app recovery path at
/// all), then not-yet-granted, then the device-wide toggle, then iOS
/// precision. Returns `null` once every condition is satisfied
/// ([LocationAvailability.canTrack]).
///
/// `notDetermined` and `denied` deliberately share one branch/button: both
/// route to [LocationService.requestPermission], which — per its own
/// contract (C4a.1) — only actually shows the system dialog while
/// permission is still askable, and simply no-ops otherwise. That contract
/// is exactly what makes a single "Engedélyezés" action correct for both,
/// without this resolver needing to guess whether the OS will currently
/// honor a second prompt.
_LocationCardContent? _locationCardContent(AppLocalizations l10n, LocationAvailability availability) {
  if (availability.authorization == LocationAuthorization.deniedForever) {
    return (
      icon: Icons.block,
      title: l10n.locationDeniedForeverTitle,
      body: l10n.locationDeniedForeverBody,
      buttonLabel: l10n.locationOpenAppSettingsButton,
      onAction: (service) => service.openAppSettings(),
    );
  }
  if (availability.authorization != LocationAuthorization.granted) {
    return (
      icon: Icons.location_off,
      title: l10n.locationOffTitle,
      body: l10n.locationOffBody,
      buttonLabel: l10n.locationRequestButton,
      onAction: (service) => service.requestPermission(),
    );
  }
  if (!availability.serviceEnabled) {
    return (
      icon: Icons.location_off,
      title: l10n.locationOffTitle,
      body: l10n.locationOffBody,
      buttonLabel: l10n.locationEnableServiceButton,
      onAction: (service) => service.openLocationSettings(),
    );
  }
  if (!availability.precise) {
    return (
      icon: Icons.my_location,
      title: l10n.locationImpreciseTitle,
      body: l10n.locationImpreciseBody,
      buttonLabel: l10n.locationEnablePreciseButton,
      onAction: (service) => service.openAppSettings(),
    );
  }
  return null;
}

/// The in-session "no GPS" card itself (M27/M28) — one component for every
/// [_LocationCardContent] variant, same "same shape, different copy"
/// approach as [_PauseStatusCard] right below. Leads with what still works
/// (M27's own design note), never with what's missing.
class _LocationStatusCard extends StatelessWidget {
  const _LocationStatusCard({
    required this.content,
    required this.dismissLabel,
    required this.busy,
    required this.onAction,
    required this.onDismiss,
  });

  final _LocationCardContent content;
  final String dismissLabel;
  final bool busy;
  final VoidCallback onAction;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      constraints: const BoxConstraints(maxWidth: 340),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(content.icon, color: scheme.onSurfaceVariant),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(content.title, style: const TextStyle(fontWeight: FontWeight.w800)),
                    const SizedBox(height: 3),
                    Text(content.body, style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 13),
          Row(
            children: [
              Expanded(
                child: FilledButton(
                  onPressed: busy ? null : onAction,
                  child: Text(content.buttonLabel),
                ),
              ),
              const SizedBox(width: 9),
              Expanded(
                child: OutlinedButton(
                  onPressed: busy ? null : onDismiss,
                  child: Text(dismissLabel),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Small persistent header chip — stays visible even after
/// [_LocationStatusCard] is dismissed for the session (M27's own design
/// note: measurement quality is always visible, only the actionable card is
/// skippable). One widget for all three [_GpsChipState] variants that render
/// a chip (M26-28's grey "off" plus C4a.4's tinted "weak"/"healthy", M04/M10)
/// — same shape, different color/icon/copy, same pattern as
/// [_LocationStatusCard] itself.
class _StatusPill extends StatelessWidget {
  const _StatusPill({
    required this.icon,
    required this.label,
    required this.color,
    this.tinted = false,
  });

  final IconData icon;
  final String label;
  final Color color;

  /// False for the neutral "off"/indoor pill (grey background); true for the
  /// weak/healthy chips, whose background is a tint of [color] instead — a
  /// plain grey pill wouldn't read as either good or concerning news.
  final bool tinted;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
      decoration: BoxDecoration(
        color: tinted ? color.withValues(alpha: 0.16) : scheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: color),
          ),
        ],
      ),
    );
  }
}

/// M04's floating header bar — activity chip, name, and one status pill, in
/// a 54 px `surfaceContainer` capsule that floats over the screen rather
/// than an `AppBar` docked to it. The screen is a full-bleed measurement
/// surface; a Material app bar would cut the top off it.
class _ActivityHeaderBar extends StatelessWidget {
  const _ActivityHeaderBar({
    required this.activityType,
    required this.title,
    this.status,
    this.onSettings,
    this.settingsTooltip,
  });

  final String activityType;
  final String title;
  final Widget? status;
  final VoidCallback? onSettings;
  final String? settingsTooltip;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      height: 54,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: scheme.surfaceContainer.withValues(alpha: 0.94),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        children: [
          ActivityChip(activityType: activityType, size: 32),
          const SizedBox(width: 11),
          Expanded(
            child: Text(
              title,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 15.5,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.2,
              ),
            ),
          ),
          if (status != null) status!,
          if (onSettings != null)
            Padding(
              padding: const EdgeInsets.only(left: 4),
              child: IconButton(
                tooltip: settingsTooltip,
                iconSize: 20,
                visualDensity: VisualDensity.compact,
                icon: const Icon(Icons.timer_outlined),
                color: scheme.onSurfaceVariant,
                onPressed: onSettings,
              ),
            ),
        ],
      ),
    );
  }
}

/// M10's in-session weak-signal banner — informational only (no button, not
/// dismissible), auto-appearing/disappearing with [_GpsChipState.weak]
/// itself rather than an acknowledgement the user clears once.
class _WeakSignalBanner extends StatelessWidget {
  const _WeakSignalBanner({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      constraints: const BoxConstraints(maxWidth: 340),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: scheme.secondary.withValues(alpha: 0.12),
        border: Border.all(color: scheme.secondary.withValues(alpha: 0.34)),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.satellite_alt, size: 20, color: scheme.secondary),
          const SizedBox(width: 11),
          Expanded(
            child: Text(text, style: TextStyle(fontSize: 11.5, color: scheme.onSurfaceVariant)),
          ),
        ],
      ),
    );
  }
}

/// The paused-state card — M08 (manual) vs M09 (auto), visually distinct per
/// docs/cardio/57-cardio-design-prompt.md DD-6: same information shape
/// (icon + title + one line of detail), different color and copy so a
/// glance tells you which one this is without reading the words.
class _PauseStatusCard extends StatelessWidget {
  const _PauseStatusCard({required this.l10n, required this.auto, required this.elapsed});

  final AppLocalizations l10n;
  final bool auto;
  final Duration? elapsed;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    // Auto-pause gets the design's dedicated amber/tan tone (M09) so it
    // reads as "the system did this", not the neutral surface a manual pause
    // (M08) uses.
    final title = auto ? l10n.autoPauseCardTitle : l10n.manualPauseCardTitle;

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: auto ? 15 : 12),
      decoration: BoxDecoration(
        color: auto ? _kAutoAccent.withValues(alpha: 0.14) : scheme.surfaceContainer,
        border: auto ? Border.all(color: _kAutoAccent.withValues(alpha: 0.5), width: 1.5) : null,
        borderRadius: BorderRadius.circular(auto ? 22 : 20),
      ),
      child: Row(
        crossAxisAlignment: auto ? CrossAxisAlignment.start : CrossAxisAlignment.center,
        children: [
          Icon(
            auto ? Icons.motion_photos_paused : Icons.pause_circle,
            size: auto ? 24 : 20,
            color: auto ? _kAutoAccent : scheme.onSurface,
          ),
          SizedBox(width: auto ? 12 : 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: auto ? 15 : 13.5,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.2,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  auto
                      ? l10n.autoPauseCardMessage
                      : l10n.manualPauseCardSubtitle(
                          elapsed == null ? '—' : CardioFormatter.duration(elapsed!)),
                  style: TextStyle(
                    fontSize: auto ? 12 : 11,
                    height: auto ? 1.5 : 1.3,
                    fontWeight: FontWeight.w600,
                    color: auto ? _kAutoAccent : scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// The auto-pause card's own resume affordance — dashed border, two lines,
/// deliberately *not* a solid filled button like the manual-pause "Folytatás"
/// (M08): the primary expectation here is that motion resumes it, tapping is
/// the fallback (docs/cardio/design M09 note).
class _AutoPauseResumeButton extends StatelessWidget {
  const _AutoPauseResumeButton({
    required this.onPressed,
    required this.titleLabel,
    required this.subtitleLabel,
  });

  final VoidCallback? onPressed;
  final String titleLabel;
  final String subtitleLabel;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(32),
        child: CustomPaint(
          painter: const _DashedBorderPainter(color: _kAutoAccent, radius: 32),
          child: SizedBox(
            height: 104,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  titleLabel,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.2,
                    color: _kAutoAccent,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  subtitleLabel,
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: _kAutoAccent.withValues(alpha: 0.72),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// M09's dashed outline. Flutter has no dashed `Border`, and the dash is the
/// whole point here: it is the third of the three signals that separate an
/// auto-pause from a manual one — "az elsődleges akció itt nem a koppintás,
/// hanem az elindulás".
class _DashedBorderPainter extends CustomPainter {
  const _DashedBorderPainter({required this.color, required this.radius});

  final Color color;
  final double radius;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color.withValues(alpha: 0.6)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    final rrect = RRect.fromRectAndRadius(
      Offset.zero & size,
      Radius.circular(radius),
    );
    const dash = 9.0;
    const gap = 7.0;
    for (final metric in (Path()..addRRect(rrect)).computeMetrics()) {
      var distance = 0.0;
      while (distance < metric.length) {
        canvas.drawPath(
          metric.extractPath(distance, math.min(distance + dash, metric.length)),
          paint,
        );
        distance += dash + gap;
      }
    }
  }

  @override
  bool shouldRepaint(_DashedBorderPainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.radius != radius;
}

/// Finishing a live cardio session never reacts to a plain tap
/// (docs/cardio/59-cardio-implementation-plan.md C2.5 kész-ha) — this is the
/// **only** control that can end one, and it only fires on a drag past
/// [_threshold] of its own width or on a [_longPressDuration] hold, either
/// released via raw [Listener] pointer callbacks rather than
/// [GestureDetector]'s tap/drag recognizers so a plain, no-movement tap
/// genuinely never crosses the finish threshold (a `GestureDetector` tap
/// recognizer would still fire `onTapUp` for that same gesture).
class _SlideToFinishBar extends StatefulWidget {
  const _SlideToFinishBar({
    required this.progress,
    required this.onFinish,
    required this.label,
    required this.releaseLabel,
  });

  final ValueNotifier<double> progress;
  final Future<void> Function() onFinish;
  final String label;
  final String releaseLabel;

  @override
  State<_SlideToFinishBar> createState() => _SlideToFinishBarState();
}

class _SlideToFinishBarState extends State<_SlideToFinishBar> {
  static const _threshold = 0.75;
  static const _longPressDuration = Duration(milliseconds: 600);

  double _width = 0;
  Timer? _longPressTimer;
  bool _completing = false;

  void _armLongPress() {
    _longPressTimer?.cancel();
    _longPressTimer = Timer(_longPressDuration, () {
      _longPressTimer = null;
      HapticFeedback.mediumImpact();
      _complete();
    });
  }

  void _disarmLongPress() {
    _longPressTimer?.cancel();
    _longPressTimer = null;
  }

  void _setProgress(double value) => widget.progress.value = value.clamp(0.0, 1.0);

  Future<void> _complete() async {
    if (_completing) return;
    _completing = true;
    _setProgress(1);
    await widget.onFinish();
    _completing = false;
    if (mounted) _setProgress(0);
  }

  void _releasePointer() {
    if (widget.progress.value >= _threshold) {
      _complete();
    } else {
      _setProgress(0);
    }
  }

  @override
  void dispose() {
    _longPressTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return LayoutBuilder(
      builder: (context, constraints) {
        _width = constraints.maxWidth;
        return Listener(
          behavior: HitTestBehavior.opaque,
          onPointerDown: (_) => _armLongPress(),
          onPointerMove: (event) {
            _disarmLongPress();
            if (_width > 0) _setProgress(event.localPosition.dx / _width);
          },
          onPointerUp: (_) {
            _disarmLongPress();
            _releasePointer();
          },
          onPointerCancel: (_) {
            _disarmLongPress();
            _setProgress(0);
          },
          child: ValueListenableBuilder<double>(
            valueListenable: widget.progress,
            builder: (context, value, _) {
              final released = value >= _threshold;
              return Container(
                height: 72,
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(
                  color: scheme.surfaceContainer,
                  borderRadius: BorderRadius.circular(26),
                ),
                child: Stack(
                  children: [
                    // The filled track grows under the handle as the drag
                    // travels — M12's "66%" state.
                    Positioned.fill(
                      child: FractionallySizedBox(
                        alignment: Alignment.centerLeft,
                        widthFactor: value,
                        child: Container(
                          color: released
                              ? scheme.primary
                              : scheme.primary.withValues(alpha: 0.55),
                        ),
                      ),
                    ),
                    Align(
                      alignment: Alignment.centerRight,
                      child: Padding(
                        padding: const EdgeInsets.only(right: 22),
                        child: Icon(
                          Icons.flag,
                          size: 22,
                          color: value > 0.85 ? scheme.onPrimary : scheme.outlineVariant,
                        ),
                      ),
                    ),
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 76),
                        child: Text(
                          released ? widget.releaseLabel : widget.label,
                          textAlign: TextAlign.center,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: value > 0.4 ? scheme.onPrimary : scheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ),
                    // The handle itself: a 60 px squircle that rides the
                    // drag, so the gesture has something to grab visually.
                    Align(
                      alignment: Alignment(-1 + 2 * value.clamp(0.0, 1.0) * 0.86, 0),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 6),
                        child: Container(
                          width: 60,
                          height: 60,
                          decoration: BoxDecoration(
                            color: value > 0 ? scheme.surface : scheme.surfaceContainerHigh,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Icon(
                            released ? Icons.flag : Icons.chevron_right,
                            size: 26,
                            color: value > 0 ? scheme.primary : scheme.onSurface,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }
}

/// The dimmed, full-screen M12 confirmation — appears the moment a
/// slide-to-finish drag starts (any `progress > 0`) and disappears the
/// moment it ends, whichever way. Purely a read of the same
/// [ValueNotifier] the bar drives, except for its Cancel row, which writes
/// back to it directly — see the `_finishProgress` field doc on why it's
/// shared through a controller rather than plain `setState`.
class _FinishConfirmationOverlay extends StatelessWidget {
  const _FinishConfirmationOverlay({
    required this.progress,
    required this.title,
    required this.message,
    required this.cancelLabel,
    required this.progressHint,
    required this.summary,
  });

  final ValueNotifier<double> progress;
  final String title;
  final String message;
  final String cancelLabel;
  final String Function(int percent) progressHint;

  /// The live numbers about to be saved ("5,24 km · 28:14 · 5:23 /km") —
  /// M12 puts them on the confirmation because this is the last moment the
  /// user can notice they're closing the wrong session.
  final String summary;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ValueListenableBuilder<double>(
      valueListenable: progress,
      builder: (context, value, _) {
        if (value <= 0) return const SizedBox.shrink();
        final remainingPercent = (100 * (1 - value)).clamp(0, 100).round();
        return Positioned.fill(
          child: Stack(
            children: [
              // The scrim and its copy must not swallow pointer events: the
              // overlay appears *during* the very drag that opens it, and
              // that drag has to keep reaching the bar underneath.
              IgnorePointer(
                child: Container(
                  color: const Color(0xFF0A0B08).withValues(alpha: 0.55),
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 150),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                  Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: scheme.primary.withValues(alpha: 0.16),
                    ),
                    child: Icon(Icons.flag, size: 38, color: scheme.primary),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    title,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (summary.isNotEmpty)
                    Text(
                      summary,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: scheme.onSurface,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                  const SizedBox(height: 4),
                  Text(
                    message,
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 14, height: 1.5, color: scheme.onSurfaceVariant),
                  ),
                      const SizedBox(height: 14),
                      Text(
                        progressHint(remainingPercent),
                        style: TextStyle(
                          fontSize: 12,
                          color: scheme.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              // M12's escape hatch, above the drag bar it belongs to.
              Positioned(
                left: 14,
                right: 14,
                bottom: 98,
                child: Material(
                  color: scheme.surfaceContainer,
                  borderRadius: BorderRadius.circular(22),
                  child: InkWell(
                    onTap: () => progress.value = 0,
                    borderRadius: BorderRadius.circular(22),
                    child: SizedBox(
                      height: 58,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.close, size: 20, color: scheme.onSurfaceVariant),
                          const SizedBox(width: 9),
                          Text(
                            cancelLabel,
                            style: TextStyle(
                              fontSize: 14.5,
                              fontWeight: FontWeight.w700,
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// The big, headline number — label above, large value below. Tappable when
/// [onTap] is given (DISTANCE, while showing distance; never for MACHINE's
/// or GAME's fixed dominant metric).
class _DominantMetric extends StatelessWidget {
  const _DominantMetric({
    required this.label,
    required this.value,
    this.badge,
    this.leading,
    this.labelColor,
    this.valueColor,
    this.onTap,
  });

  final String label;
  final String value;

  /// Small pill next to [label] — M10's "BECSÜLT" while the GPS signal is
  /// weak (docs/cardio/59-cardio-implementation-plan.md C4a.4). `null` the
  /// rest of the time, including M04's healthy-GPS and every non-GPS state.
  final String? badge;

  /// M06/M07's state dot or pause glyph ahead of the label.
  final Widget? leading;
  final Color? labelColor;
  final Color? valueColor;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    // The unit rides at 26 px next to a 96 px number (M04) — the formatter
    // hands both back in one string, so the last space is the seam. A
    // duration ("28:14") has no space and stays whole.
    final spaceIndex = value.lastIndexOf(' ');
    final hasUnit = spaceIndex > 0;
    final number = hasUnit ? value.substring(0, spaceIndex) : value;
    final unit = hasUnit ? value.substring(spaceIndex + 1) : null;

    return InkWell(
      onTap: onTap,
      child: Padding(
        // Left-aligned, not centered: "napfényben, mozgás közben a bal
        // szélről indul az olvasás, és a tizedesvessző mindig ugyanott van".
        padding: const EdgeInsets.fromLTRB(24, 6, 24, 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                if (leading != null) ...[leading!, const SizedBox(width: 8)],
                Flexible(
                  child: Text(
                    label,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.6,
                      color: labelColor ?? scheme.onSurfaceVariant,
                    ),
                  ),
                ),
                if (badge != null) ...[
                  const SizedBox(width: 7),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: scheme.secondary.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      badge!,
                      style: TextStyle(
                        fontSize: 9.5,
                        fontWeight: FontWeight.w700,
                        color: scheme.secondary,
                      ),
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 2),
            // One `Text.rich`, not two `Text`s side by side: the unit has to
            // sit on the number's baseline at a third of its size, and
            // keeping it a single text node also keeps the whole value
            // greppable as one string ("5.24 km") for tests and semantics.
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text.rich(
                TextSpan(
                  children: [
                    TextSpan(
                      text: number,
                      style: TextStyle(
                        fontSize: 96,
                        height: 1.02,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -4,
                        color: valueColor,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                    if (unit != null)
                      TextSpan(
                        text: ' $unit',
                        style: TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0,
                          color: valueColor ?? scheme.onSurfaceVariant,
                        ),
                      ),
                  ],
                ),
                maxLines: 1,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The three-across secondary metric strip (M04/M05/M06) — equal widths,
/// full bleed to the screen's 14 px gutter, 9 px gaps.
class _MetricRow extends StatelessWidget {
  const _MetricRow({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      // IntrinsicHeight, not plain `stretch`: the row lives in a scroll
      // view, so "stretch" alone would ask the tiles for infinite height.
      // The tiles must still match each other — one tile growing a line
      // taller than its neighbours is exactly what the frames don't do.
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (var i = 0; i < children.length; i++) ...[
              if (i > 0) const SizedBox(width: 9),
              Expanded(child: children[i]),
            ],
          ],
        ),
      ),
    );
  }
}

/// One secondary-metric box — tappable when [onTap] is given. [color], when
/// given, tints both the value and the label (M10's amber pace tile while
/// the signal is weak); otherwise both use the normal theme colors.
class _MetricTile extends StatelessWidget {
  const _MetricTile({
    required this.label,
    required this.value,
    this.icon,
    this.iconColor,
    this.onTap,
    this.color,
    this.outlined = false,
    this.highlighted = false,
  });

  final String label;
  final String value;
  final IconData? icon;
  final Color? iconColor;
  final VoidCallback? onTap;
  final Color? color;

  /// M11's dashed, empty tile — "— km · írd be": the tile *is* the call to
  /// action when there's no source for the value.
  final bool outlined;

  /// M07's bordered gross-time tile while benched — the one metric still
  /// moving gets the frame.
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final accent = outlined ? scheme.primary : (color ?? scheme.onSurfaceVariant);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 13),
        decoration: BoxDecoration(
          color: highlighted ? scheme.surfaceContainer : scheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(18),
          border: highlighted
              ? Border.all(color: _kAutoAccent.withValues(alpha: 0.34))
              : (outlined && onTap != null
                  ? Border.all(color: scheme.outlineVariant, width: 1.5)
                  : null),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                if (icon != null)
                  Icon(icon, size: 17, color: iconColor ?? scheme.onSurfaceVariant),
                const Spacer(),
                if (outlined && onTap != null) Icon(Icons.edit, size: 15, color: scheme.primary),
              ],
            ),
            const SizedBox(height: 5),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                value,
                style: TextStyle(
                  fontSize: 25,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.8,
                  color: color,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ),
            // The frames draw these labels lower-case ("mozgásidő"); the ARB
            // keeps them upper-case because the same strings are field
            // labels on the manual-entry sheet and the summary. Casing is
            // the one place this tile deviates from M04 — everything else
            // (size, weight, color, order) follows it.
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600, color: accent),
            ),
          ],
        ),
      ),
    );
  }
}

/// The round −/+ pair inside M05's resistance card.
class _StepperButton extends StatelessWidget {
  const _StepperButton({required this.icon, required this.onPressed});

  final IconData icon;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return IconButton(
      onPressed: onPressed,
      iconSize: 19,
      icon: Icon(icon),
      style: IconButton.styleFrom(
        backgroundColor: scheme.surfaceContainer,
        foregroundColor: scheme.onSurfaceVariant,
        disabledForegroundColor: scheme.onSurfaceVariant.withValues(alpha: 0.4),
        minimumSize: const Size(40, 40),
        shape: const CircleBorder(),
      ),
    );
  }
}

/// M07's "A mérés pihen" card — the one place that says out loud what a
/// benched clock does and doesn't record.
class _BenchedNoticeCard extends StatelessWidget {
  const _BenchedNoticeCard({required this.title, required this.body});

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: _kAutoAccent.withValues(alpha: 0.12),
        border: Border.all(color: _kAutoAccent.withValues(alpha: 0.32)),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.timer_off, size: 20, color: _kAutoAccent),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800)),
                const SizedBox(height: 3),
                Text(
                  body,
                  style: TextStyle(fontSize: 11.5, height: 1.5, color: scheme.onSurfaceVariant),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// One half of the GAME family's "Pályán/Padon" switch — large, thumb-zone
/// sized per docs/cardio/53-cardio-mobile-plan.md §4.3's explicit ask
/// ("A kapcsoló nagy, hüvelykkel elérhető").
class _CourtSwitch extends StatelessWidget {
  const _CourtSwitch({
    required this.onCourt,
    required this.onCourtLabel,
    required this.onBenchLabel,
    required this.hint,
    required this.enabled,
    required this.onChanged,
  });

  final bool onCourt;
  final String onCourtLabel;
  final String onBenchLabel;
  final String hint;
  final bool enabled;
  final void Function(bool onCourt) onChanged;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          height: 96,
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: scheme.surfaceContainerLow,
            borderRadius: BorderRadius.circular(26),
          ),
          child: Row(
            children: [
              Expanded(
                child: _CourtSwitchHalf(
                  icon: Icons.sports,
                  label: onCourtLabel,
                  selected: onCourt,
                  // "Pályán" is the primary, measuring state; "Padon" takes
                  // the secondary brown so the screen reads differently at a
                  // glance without leaving the palette (M07's note).
                  selectedColor: scheme.primary,
                  onSelectedColor: scheme.onPrimary,
                  onPressed: enabled && !onCourt ? () => onChanged(true) : null,
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: _CourtSwitchHalf(
                  icon: Icons.airline_seat_recline_normal,
                  label: onBenchLabel,
                  selected: !onCourt,
                  selectedColor: _kAutoAccent,
                  onSelectedColor: const Color(0xFF231C12),
                  onPressed: enabled && onCourt ? () => onChanged(false) : null,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 9),
        Text(
          hint,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 10.5,
            fontWeight: FontWeight.w600,
            color: onCourt ? scheme.onSurfaceVariant : _kAutoAccent,
          ),
        ),
      ],
    );
  }
}

class _CourtSwitchHalf extends StatelessWidget {
  const _CourtSwitchHalf({
    required this.icon,
    required this.label,
    required this.selected,
    required this.selectedColor,
    required this.onSelectedColor,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final Color selectedColor;
  final Color onSelectedColor;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final fg = selected ? onSelectedColor : scheme.onSurfaceVariant;
    return Material(
      color: selected ? selectedColor : Colors.transparent,
      borderRadius: BorderRadius.circular(21),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(21),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 28, color: fg),
            const SizedBox(height: 3),
            Text(
              label,
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: fg),
            ),
          ],
        ),
      ),
    );
  }
}

/// M04/M05/M10/M11's control row: a 104 px primary pause circle, flanked by
/// up to two 72 px secondary circles. The frames' left slot is a screen lock
/// the app doesn't have, so DISTANCE puts the auto-pause settings there and
/// every other family leaves it empty — the pause circle stays centered
/// either way.
class _RunningControlRow extends StatelessWidget {
  const _RunningControlRow({
    required this.onPause,
    required this.pauseLabel,
    this.leading,
    this.trailing,
  });

  final VoidCallback? onPause;
  final String pauseLabel;
  final Widget? leading;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      children: [
        Expanded(child: Align(alignment: Alignment.centerLeft, child: leading ?? const SizedBox(width: 72))),
        Material(
          color: scheme.primary,
          shape: const CircleBorder(),
          child: InkWell(
            onTap: onPause,
            customBorder: const CircleBorder(),
            child: SizedBox(
              width: 104,
              height: 104,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.pause, size: 38, color: scheme.onPrimary),
                  Text(
                    pauseLabel,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: scheme.onPrimary,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        Expanded(
          child: Align(
            alignment: Alignment.centerRight,
            child: trailing ?? const SizedBox(width: 72),
          ),
        ),
      ],
    );
  }
}

/// One 72 px secondary circle of the control row.
class _CircleAction extends StatelessWidget {
  const _CircleAction({
    required this.icon,
    required this.label,
    required this.onPressed,
    this.color,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onPressed;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final fg = color ?? scheme.onSurfaceVariant;
    return Material(
      color: scheme.surfaceContainer,
      shape: const CircleBorder(),
      child: InkWell(
        onTap: onPressed,
        customBorder: const CircleBorder(),
        child: SizedBox(
          width: 72,
          height: 72,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 24, color: fg),
              const SizedBox(height: 2),
              Text(
                label,
                style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w700, color: fg),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// M08's resume button — a solid, full-width 104 px primary block. The
/// manual pause is the user's own decision, so tapping is exactly the right
/// affordance (contrast [_AutoPauseResumeButton]).
class _ResumeButton extends StatelessWidget {
  const _ResumeButton({required this.onPressed, required this.label});

  final VoidCallback? onPressed;
  final String label;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.primary,
      borderRadius: BorderRadius.circular(32),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(32),
        child: SizedBox(
          height: 104,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.play_arrow, size: 36, color: scheme.onPrimary),
              const SizedBox(width: 11),
              Text(
                label,
                style: TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.3,
                  color: scheme.onPrimary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// M06/M07's full-width "Meccs szünet" bar.
class _WideActionButton extends StatelessWidget {
  const _WideActionButton({required this.icon, required this.label, required this.onPressed});

  final IconData icon;
  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.surfaceContainer,
      borderRadius: BorderRadius.circular(24),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(24),
        child: SizedBox(
          height: 64,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 22, color: scheme.primary),
              const SizedBox(width: 9),
              Text(label, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
            ],
          ),
        ),
      ),
    );
  }
}
