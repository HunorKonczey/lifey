import 'dart:async';
import 'dart:math' as math;

import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/ads/interstitial_manager.dart';
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
import '../application/box_score_preferences.dart';
import '../application/game_setup_preferences.dart';
import '../application/km_cue_controller.dart';
import '../application/interval_cue_preferences.dart';
import '../application/interval_player_controller.dart';
import '../application/km_cue_preferences.dart';
import '../application/workout_session_controller.dart';
import '../data/cardio_track_point_repository.dart';
import '../domain/activity_type.dart';
import '../domain/auto_pause_detector.dart';
import '../domain/best_effort_calculator.dart';
import '../domain/cardio_personal_record.dart';
import '../data/cardio_interval_plan_repository.dart';
import '../domain/cardio_interval_plan.dart';
import '../domain/cardio_splits_calculator.dart';
import '../domain/elevation_profile.dart';
import '../domain/grade_adjusted_pace.dart';
import '../domain/route_encoder.dart';
import '../domain/track_filter.dart';
import '../domain/workout_session.dart';
import 'cardio_summary_screen.dart';
import 'open_workout_screens.dart';
import 'widgets/box_score_stepper.dart';
import 'widgets/cardio_session_settings_sheet.dart';
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
  const CardioSessionScreen({super.key, required this.session, this.intervalPlanClientId});

  final WorkoutSession session;

  /// The interval plan this ride is playing back (docs/cardio/60 C7.5), or
  /// null — which is the normal case and leaves the screen exactly as it was
  /// before intervals existed (M38's "terv nélkül" state). Passed in rather
  /// than read off the session: no session ever references a plan
  /// (D-C7.1), so the choice belongs to whoever started the ride.
  final String? intervalPlanClientId;

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

  // -- Waypoints (C8.4, M41) — HIKING only ----------------------------------

  /// This session's marked waypoints so far — seeded from [widget.session] in
  /// `initState`, appended/truncated locally on mark/undo, persisted through
  /// [WorkoutSessionController.updateLiveWaypoints] as a full replace, same
  /// convention as [_distanceMeters]/[_updateCardioMetrics].
  List<CardioWaypoint> _waypoints = const [];

  /// The most recent GPS fix (regardless of [_isRunning] — set from every
  /// [_onPositionFix] call, since tracking also runs during an auto-pause).
  /// Null until the first fix of the session arrives — the marker button
  /// stays disabled until then, same as the "GPS nélkül" state, since there
  /// is nothing yet to mark.
  LocationFix? _lastFix;

  /// Non-null while the "N. útpont megjelölve" feedback banner is showing
  /// (M41) — cleared by [_waypointFeedbackTimer] after 4 s, or immediately by
  /// "Vissza" undoing the mark.
  CardioWaypoint? _justMarkedWaypoint;
  Timer? _waypointFeedbackTimer;

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
  /// default) and refreshed once after [showCardioSessionSettingsSheet]
  /// closes — cached rather than re-read from `shared_preferences` on every
  /// fix, since [_onPositionFix] fires far more often than the setting could
  /// plausibly change.
  bool _autoPauseEnabled = true;

  /// The per-kilometre cue (C6.6, M35). Created alongside [_autoPauseDetector]
  /// and fed from the same place the live distance is updated, which is what
  /// makes "auto-pause alatt nem üt" true by construction rather than by an
  /// extra check: [_onPositionFix] only advances the distance while genuinely
  /// running, so a paused session never reaches [KmCueController.onDistance].
  KmCueController? _kmCueController;

  /// Non-null only while a plan is playing. Owns no clock of its own — it is
  /// fed [_liveMovingSeconds] from [_startTicker], which is what makes the
  /// section countdown stop dead with a pause (docs/cardio/60 §9's named
  /// risk for this step).
  IntervalPlayerController? _intervalPlayer;
  IntervalPlayerState? _intervalState;
  IntervalCueSettings _intervalCueSettings = IntervalCueSettings.defaults;

  /// Cached like [_autoPauseEnabled], and for the same reason.
  KmCueSettings _kmCueSettings = KmCueSettings.defaults;

  Timer? _ticker;
  bool _busy = false;

  // -- Box score (C9.2, M44) ------------------------------------------------

  /// Live counters, seeded from the session and persisted through
  /// [_updateCardioMetrics] like every other live metric. `null` means "never
  /// counted", which is what keeps an untouched match from storing zeroes.
  int? _scorePoints;
  int? _scoreAssists;
  int? _scoreRebounds;

  /// Whether the stepper panel is currently up. Hidden by default (Q-D2): in
  /// a pocket or while defending, a permanently visible stepper collects
  /// accidental taps.
  bool _boxScoreOpen = false;

  /// Closes [_boxScoreOpen] after 6 s of **idle** time — restarted by every
  /// tap, so a stepper being actively used never folds away mid-count.
  Timer? _boxScoreIdleTimer;

  /// Answer to the one-time offer; drives whether the offer card shows at all.
  BoxScoreOffer _boxScoreOffer = BoxScoreOffer.unanswered;

  /// Whether this **outdoor** match records distance (C9.4). Opt-in, and only
  /// ever true outdoors: indoors there is nothing to record, so GPS is not
  /// disabled here — it doesn't exist ([GameSetup.recordsDistance]). Read from
  /// the same device-local store the setup sheet writes, so a session
  /// reopened after an app kill resumes with the same answer.
  bool _gameGpsEnabled = false;

  /// True when this session should have a GPS subscription at all: every
  /// DISTANCE session, and an outdoor GAME that opted in. The single question
  /// [_syncPositionTracking] asks, so "no GPS indoors" is one condition in one
  /// place rather than a rule repeated per call site.
  bool get _tracksLocation =>
      _family == ActivityFamily.distance ||
      (_family == ActivityFamily.game &&
          widget.session.cardio?.venue == 'OUTDOOR' &&
          _gameGpsEnabled);

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

  /// This screen's entry in the open-screen registry while it is showing a
  /// **running** session (`open_workout_screens.dart`) — two jobs, both of
  /// which only started to matter once a watch-started cardio session could
  /// open this screen by itself (`StandaloneSessionProcessor._adoptCardio`):
  /// it stops `workout_resume_prompt.dart` from pushing a *second* screen for
  /// the same session (the watch resends its adoption snapshot on every
  /// reconnect), and it is how [_onEndedElsewhere] is reached.
  OpenWorkoutScreen? _openScreen;

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
    _scorePoints = s.cardio?.scorePoints;
    _scoreAssists = s.cardio?.scoreAssists;
    _scoreRebounds = s.cardio?.scoreRebounds;
    _waypoints = s.waypoints;
    if (s.finishedAt == null) {
      _openScreen = openWorkoutScreen(s.clientId, onEndedElsewhere: _onEndedElsewhere);
    }

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

    // C7.5 — the interval player. Only ever set up when this ride has a
    // plan; without one nothing below it changes and the screen is M05 to
    // the pixel. The id comes either from the picker that just started the
    // ride or, for a session reopened after an app kill, from the memory
    // that same picker wrote.
    if (_finishedAt == null) {
      unawaited(_seedIntervalPlayer());
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
      _startLocationPipeline();
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

      // The unit is read once, here, from the profile — never chosen in the
      // settings sheet (M35's closing line: two places to set a unit is a
      // guaranteed bug report).
      final unitSystem =
          (ref.read(settingsControllerProvider).value ?? const UserSettings.defaults()).unitSystem;
      _kmCueController = KmCueController(
        unitMeters: unitSystem == UnitSystem.imperial ? 1609.344 : 1000,
        onCue: (_, __) => _playKmCue(),
      );
      unawaited(_seedKmCueSettings());
    }
    if (_family == ActivityFamily.game) {
      unawaited(_seedBoxScoreOffer());
      // Outdoor GAME distance recording (C9.4). Seeded before the trail replay
      // so `_syncPositionTracking` never starts a subscription for an indoor
      // match, not even for one frame.
      unawaited(_seedGameGps());
    }
  }

  /// Reads the outdoor-GPS opt-in, then — only if this match actually records
  /// distance — sets up the same trail machinery a DISTANCE session uses.
  Future<void> _seedGameGps() async {
    final setup = await ref.read(gameSetupPreferencesProvider).load();
    if (!mounted) return;
    _gameGpsEnabled = setup.gpsEnabled;
    // Nothing at all happens for an indoor match, or an outdoor one that
    // didn't opt in: no availability subscription, so no permission prompt
    // and no radio (the C9.4 battery guarantee).
    if (!_tracksLocation) return;
    _startLocationPipeline();
    unawaited(_seedTrackPointSeqAndSync());
  }

  /// The availability subscription + lifecycle observer both tracking families
  /// need. Extracted so an outdoor GAME reuses the DISTANCE path exactly
  /// rather than growing a parallel one that could drift.
  void _startLocationPipeline() {
    WidgetsBinding.instance.addObserver(this);
    _locationSub = ref.read(locationServiceProvider).availability.listen((a) {
      if (mounted) {
        setState(() => _locationAvailability = a);
        _syncPositionTracking();
      }
    });
  }

  /// One-time read of [BoxScorePreferences] (C9.2). An `accepted` answer also
  /// opens the stepper straight away — the user asked for it, so they
  /// shouldn't have to find the button again on the next match.
  Future<void> _seedBoxScoreOffer() async {
    final offer = await ref.read(boxScorePreferencesProvider).offerState();
    if (!mounted) return;
    setState(() {
      _boxScoreOffer = offer;
      if (offer == BoxScoreOffer.accepted) _boxScoreOpen = true;
    });
    if (_boxScoreOpen) _armBoxScoreIdleTimer();
  }

  Future<void> _answerBoxScoreOffer(BoxScoreOffer answer) async {
    setState(() {
      _boxScoreOffer = answer;
      _boxScoreOpen = answer == BoxScoreOffer.accepted;
    });
    if (_boxScoreOpen) _armBoxScoreIdleTimer();
    await ref.read(boxScorePreferencesProvider).setOfferState(answer);
  }

  void _toggleBoxScore() {
    setState(() => _boxScoreOpen = !_boxScoreOpen);
    if (_boxScoreOpen) {
      _armBoxScoreIdleTimer();
    } else {
      _boxScoreIdleTimer?.cancel();
    }
  }

  /// (Re)starts the 6 s idle countdown — measured from the last interaction,
  /// not from opening, so counting a fast break doesn't race the timer.
  void _armBoxScoreIdleTimer() {
    _boxScoreIdleTimer?.cancel();
    _boxScoreIdleTimer = Timer(const Duration(seconds: 6), () {
      if (mounted) setState(() => _boxScoreOpen = false);
    });
  }

  /// One box-score column changed. Persisted through the same merged write
  /// every other live metric uses — and deliberately **nowhere near
  /// `movingSeconds`**: counting a basket is not a clock event, and the
  /// court/bench switch remains the only thing that moves playing time.
  /// [delta] is +1/-1, applied to whatever the counter currently holds — see
  /// [BoxScoreColumn.onStep] for why the stepper reports a step rather than a
  /// finished number.
  Future<void> _stepBoxScore({int? points, int? assists, int? rebounds}) {
    int? next(int? delta, int? current) =>
        delta == null ? null : ((current ?? 0) + delta).clamp(0, 1 << 30);
    return _updateCardioMetrics(
      scorePoints: next(points, _scorePoints),
      scoreAssists: next(assists, _scoreAssists),
      scoreRebounds: next(rebounds, _scoreRebounds),
    );
  }

  /// Loads the plan and fast-forwards the player to wherever this ride
  /// already is — a session reopened after an app kill resumes mid-plan
  /// rather than starting the plan over, because [IntervalPlayerController]
  /// derives everything from moving time (which survives the kill) instead
  /// of from when the screen happened to open.
  Future<void> _seedIntervalPlayer() async {
    final planClientId = widget.intervalPlanClientId ??
        await ref.read(intervalPlanSessionMemoryProvider).planFor(_clientId);
    if (planClientId == null || !mounted) return;
    final plan = await ref.read(cardioIntervalPlanRepositoryProvider).findByClientId(planClientId);
    final cueSettings = await ref.read(intervalCuePreferencesProvider).load();
    if (!mounted || plan == null || plan.steps.isEmpty) return;
    final player = IntervalPlayerController(plan: plan, onSectionChanged: _onIntervalSection);
    // Catching up is silent: a resumed ride must not fire a burst of cues
    // for the sections it already rode (same lesson as KmCueController.seed).
    final resuming = _liveMovingSeconds;
    _suppressIntervalCues = true;
    final state = player.update(resuming);
    _suppressIntervalCues = false;
    setState(() {
      _intervalCueSettings = cueSettings;
      _intervalPlayer = player;
      _intervalState = state;
    });
  }

  bool _suppressIntervalCues = false;

  /// M38's cue: three short taps through the 3–2–1 countdown and a longer one
  /// at the switch. The taps are what the *countdown* fires (see
  /// [_tickIntervalPlayer]); this is the switch itself.
  ///
  /// A change into an easy section gets only the long tap — after four hard
  /// minutes the rider doesn't need to be told to relax, and the countdown
  /// ceremony is what makes the hard start feel deliberate.
  void _onIntervalSection(IntervalPlayerState state) {
    if (_suppressIntervalCues) return;
    if (_intervalCueSettings.vibration) HapticFeedback.heavyImpact();
    if (_intervalCueSettings.sound) {
      // The platform's own alert sound, same call and same reasoning as the
      // kilometre cue's — see [_playKmCue].
      unawaited(SystemSound.play(SystemSoundType.alert));
    }
  }

  /// Advances the player to the session's current moving time and fires the
  /// 3–2–1 taps on the way into a hard section. Called once a second from
  /// [_startTicker] — and only from there, so a paused session (whose moving
  /// time is frozen) simply keeps handing the player the same number.
  void _tickIntervalPlayer() {
    final player = _intervalPlayer;
    if (player == null) return;
    final previous = _intervalState;
    final state = player.update(_liveMovingSeconds);
    _intervalState = state;

    // Only into a hard section, and only once per second of the countdown:
    // the long tap at the switch itself comes from [_onIntervalSection].
    final crossedIntoCountdown = previous == null ||
        previous.secondsRemaining != state.secondsRemaining ||
        previous.sectionNumber != state.sectionNumber;
    if (state.isCountingDown &&
        crossedIntoCountdown &&
        state.nextIntensity == IntervalIntensity.hard &&
        _intervalCueSettings.vibration) {
      HapticFeedback.selectionClick();
    }
  }

  /// The "Léptet" circle (M38): ends the current section at whatever length
  /// it actually got, and moves on.
  void _skipIntervalSection() {
    final player = _intervalPlayer;
    if (player == null) return;
    setState(() => _intervalState = player.skip(_liveMovingSeconds));
  }

  Future<void> _seedKmCueSettings() async {
    final settings = await ref.read(kmCuePreferencesProvider).load();
    if (mounted) _kmCueSettings = settings;
  }

  /// Fires the cue itself. Runs off the GPS fix stream, which keeps
  /// delivering with the app backgrounded and the screen locked (the Android
  /// foreground service / iOS background location mode C4a.5 already set up
  /// for the recording itself), so the cue arrives on a locked phone in a
  /// pocket — the only place it's any use.
  ///
  /// Both switches off means silence, not a fallback: turning everything off
  /// is a state M35 lists in its own right.
  void _playKmCue() {
    if (_kmCueSettings.vibration) {
      // "Két rövid koppintás" (M35) — two impacts, not one long buzz, so it
      // reads as a deliberate signal rather than a notification.
      HapticFeedback.mediumImpact();
      Future.delayed(const Duration(milliseconds: 140), HapticFeedback.mediumImpact);
    }
    if (_kmCueSettings.sound) {
      // The platform's own alert sound, deliberately not a bundled audio
      // asset: playing a custom chime *over* music needs an audio-session
      // category and a player package, which is a dependency decision this
      // step doesn't get to make on its own (see the C6.6 note in
      // docs/cardio/60).
      unawaited(SystemSound.play(SystemSoundType.alert));
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
    // Adopt the replayed distance as already-announced ground — without this,
    // reopening a 7 km run after an app kill would buzz seven times in one
    // frame (see [KmCueController.seed]).
    _kmCueController?.seed(filter.distanceMeters);
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

  /// Opens [CardioSessionSettingsSheet] and refreshes both cached settings
  /// from whatever the user left them as — the sheet writes straight through
  /// the preference stores itself, so this is just picking the new values
  /// back up for the in-flight [_autoPauseDetector]/[_kmCueController] to
  /// actually honor.
  /// The in-session settings sheet — auto-pause and the kilometre cue for a
  /// run, the section-change cue for a ride playing a plan (Q-D4). One sheet,
  /// one entry point; which switches it shows follows the family.
  Future<void> _openAutoPauseSettings() async {
    await showCardioSessionSettingsSheet(context, family: _family);
    if (!mounted) return;
    unawaited(_seedAutoPauseEnabled());
    unawaited(_seedKmCueSettings());
    final cueSettings = await ref.read(intervalCuePreferencesProvider).load();
    if (mounted) setState(() => _intervalCueSettings = cueSettings);
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
        _tracksLocation &&
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
    _lastFix = fix;
    if (_isRunning) {
      final seq = _nextTrackPointSeq++;
      unawaited(ref.read(cardioTrackPointRepositoryProvider).addPoint(_clientId, seq, fix));

      final filter = _trackFilter;
      if (filter != null && filter.addFix(fix)) {
        _armWeakSignalTimer();
        if (mounted && filter.distanceMeters > 0) {
          setState(() => _distanceMeters = filter.distanceMeters);
          _kmCueController?.onDistance(filter.distanceMeters);
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
    final openScreen = _openScreen;
    if (openScreen != null) closeWorkoutScreen(openScreen);
    _ticker?.cancel();
    _hrTicker?.cancel();
    _finishProgress.dispose();
    _watchEventsSubscription?.cancel();
    _locationSub?.cancel();
    _positionSub?.cancel();
    _weakSignalTimer?.cancel();
    _boxScoreIdleTimer?.cancel();
    _waypointFeedbackTimer?.cancel();
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
      if (!mounted) return;
      // The player rides on this same tick and on the same moving-time
      // number the dominant metric shows — it never starts a clock of its own.
      _tickIntervalPlayer();
      setState(() {});
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
        // Cycling shows speed (km/h), not pace (min/km) — docs/cardio/
        // 62-cardio-cycling-plan.md §2.2: at cycling speeds pace reads as a
        // nonsensical small number. Every other DISTANCE type is unchanged.
        final isCycling = _activityType == 'CYCLING';
        return CardioLiveMetrics(
          primaryLabel: hasDistance ? l10n.distanceFieldLabel : l10n.movingTimeLabel,
          primaryValue: hasDistance
              ? CardioFormatter.distance(_distanceMeters!, unitSystem)
              : CardioFormatter.duration(movingDuration),
          secondaryLabel: hasDistance ? l10n.movingTimeLabel : l10n.distanceFieldLabel,
          secondaryValue: hasDistance ? CardioFormatter.duration(movingDuration) : '—',
          tertiaryLabel: isCycling ? l10n.speedLabel : l10n.paceLabel,
          tertiaryValue: hasDistance
              ? ((isCycling
                      ? CardioFormatter.speed(_distanceMeters!, movingDuration, unitSystem)
                      : CardioFormatter.pace(_distanceMeters!, movingDuration, unitSystem)) ??
                  '—')
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
          // The watch shows the same pályán/padon toggle (W-9) — see
          // [CardioLiveMetrics.onCourt].
          onCourt: _onCourt,
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
      case WatchCourtChanged():
        // The wrist's own pályán/padon switch (W-9). Routed through the very
        // same `_setOnCourt` the in-app toggle calls, so the clock arithmetic
        // and the persistence live in one place regardless of which device
        // the tap happened on — and its own guards (busy/finished/manually
        // paused/already-there) apply to the watch too.
        if (event.sessionClientId != _clientId) return;
        // GAME only, even though no watch build sends it for anything else:
        // `_setOnCourt` freezes the *moving* clock, and doing that to a run
        // or a ride — which have no bench, and no way back to on-court from
        // their own UI — would strand the session's own timer.
        if (_family != ActivityFamily.game) return;
        unawaited(_setOnCourt(event.onCourt));
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

  /// The session this screen is running was finished **elsewhere** — the
  /// watch closing a session it started and this phone joined
  /// (`StandaloneSessionProcessor`), while this screen never got the
  /// `WatchEndRequested` that normally precedes it (the phone was
  /// unreachable at that moment, so only the queued closing payload made it).
  ///
  /// The row in the database is already the finished, authoritative one. This
  /// screen must therefore stop measuring **and** never write its own finish
  /// over it — [_finish] refuses once `_finishedAt` is set, so setting it is
  /// what makes that safe. Closing the screen is best-effort on top: popping
  /// something that isn't the current route would dismiss the wrong thing, so
  /// a screen the user has already navigated away from just stops and waits
  /// to be popped normally.
  void _onEndedElsewhere() {
    if (!mounted || _isFinished) return;
    _ticker?.cancel();
    _hrTicker?.cancel();
    _positionSub?.cancel();
    _autoPauseDetector?.dispose();
    _autoPauseDetector = null;
    setState(() => _finishedAt = DateTime.now());
    unawaited(ref.read(workoutSessionNotifierServiceProvider).end());
    if (ModalRoute.of(context)?.isCurrent ?? false) Navigator.of(context).pop();
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
    // The executed sections of an interval plan are splits too (D-C7.1) —
    // cut off wherever the ride actually ended, so a session finished
    // mid-section still logs the part that was ridden.
    final intervalSplits = _intervalPlayer?.executedSplits(total) ?? const <CardioSplit>[];
    if (_tracksLocation && trail.isNotEmpty) {
      final encoded = encodeRoute(trail);
      // A match gets **distance and a route, and nothing derived from pace**
      // (C9.4's promise, docs/cardio/51 §3.4): km splits across a basketball
      // court describe nothing, and the best efforts are running's alone
      // anyway. Both stay empty for GAME rather than being computed and then
      // hidden.
      final isDistanceFamily = _family == ActivityFamily.distance;
      routeSplits = isDistanceFamily ? computeSplits(trail) : const [];
      // Same trail, same moment, same write (docs/cardio/60 C6.3) — the
      // best efforts have exactly the splits' inputs and lifetime, and
      // deriving them here rather than later is what makes them survive the
      // raw track points being pruned.
      final bestEfforts =
          isDistanceFamily ? computeBestEfforts(trail) : CardioBestEfforts.none;
      final originalCardio = widget.session.cardio;
      // elevationGainMeters is never null on the accumulator itself (it
      // starts at 0 and only grows) — but "0 m gain" and "no altitude data
      // at all" are different facts, and only the latter should hide the
      // elevation-gain tile/profile downstream (CardioSummaryScreen gates on
      // null). A trail with zero altitude readings genuinely has neither.
      final hasAltitude = trail.any((p) => p.altitude != null);
      // Same source as the elevation profile itself (C8.3) — the highest
      // vertex across the whole local trail, computed once here so it
      // survives the raw points being pruned, exactly like the best efforts
      // above (docs/cardio/60 C8.5, Q-D6).
      final maxAltitudeMeters = hasAltitude ? buildElevationProfile(trail)?.peak?.altitudeMeters : null;
      // Hike-only (docs/cardio/60 C8.2, docs/cardio/56 D-C3.9), same trail
      // and same close-time computation as the best efforts/elevation peak
      // above — the M42 "TEREP" block is what actually shows this, and that
      // frame only ever appears on a hike. `computeGradeAdjustedPaceSecondsPerKm`
      // is itself null-tolerant of missing altitude (a flat/no-altitude
      // trail just returns the raw average pace), so no extra `hasAltitude`
      // gate is needed here.
      final avgGapSecondsPerKm =
          _activityType == 'HIKING' ? computeGradeAdjustedPaceSecondsPerKm(trail) : null;
      routeCardio = CardioMetrics(
        distanceMeters: _trackFilter!.distanceMeters,
        elevationGainMeters: hasAltitude ? _trackFilter!.elevationGainMeters : null,
        maxAltitudeMeters: maxAltitudeMeters,
        avgGapSecondsPerKm: avgGapSecondsPerKm,
        best1kSeconds: bestEfforts.best1kSeconds,
        best5kSeconds: bestEfforts.best5kSeconds,
        best10kSeconds: bestEfforts.best10kSeconds,
        avgCadence: _avgCadence,
        avgWatts: _avgWatts,
        resistanceLevel: _resistanceLevel,
        venue: originalCardio?.venue,
        gameFormat: originalCardio?.gameFormat,
        intensity: originalCardio?.intensity,
        // The live counters, not the session's copy from when this screen
        // opened — C9.2's stepper has been changing these all match.
        scorePoints: _scorePoints,
        scoreAssists: _scoreAssists,
        scoreRebounds: _scoreRebounds,
        distanceSource: 'MEASURED',
        routePolyline: encoded.polyline,
        routePointCount: encoded.pointCount,
        // Never set on this screen (docs/cardio/60 C8.5: backpack weight is
        // only ever entered afterward, on the summary, or up front via
        // `LogCardioSheet`) — carried through defensively so a live-tracked
        // hike that somehow already had one doesn't lose it at finish.
        backpackWeightKg: originalCardio?.backpackWeightKg,
      );
    }
    try {
      await ref.read(workoutSessionControllerProvider.notifier).finishCardioSession(
            _clientId,
            startedAt: _startedAt,
            finishedAt: finishedAt,
            movingSeconds: total,
            cardio: routeCardio == null ? const Value.absent() : Value(routeCardio),
            splits: intervalSplits.isNotEmpty
                ? Value([...routeSplits, ...intervalSplits])
                : (routeCardio == null ? const Value.absent() : Value(routeSplits)),
          );
      if (!mounted) return;
      _ticker?.cancel();
      // `67` §5.3: fired here, not blocking the summary navigation below —
      // same fire-and-forget timing as `LogMealScreen`'s own call site.
      unawaited(
        ref.read(interstitialManagerProvider).maybeShow(context, InterstitialReason.workoutSaved),
      );
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
      // The plan has done its job: the executed sections are on the session
      // now, as splits.
      unawaited(ref.read(intervalPlanSessionMemoryProvider).forget(_clientId));
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
            scorePoints: _scorePoints,
            scoreAssists: _scoreAssists,
            scoreRebounds: _scoreRebounds,
            distanceSource: _hasGpsDistance ? 'MEASURED' : (_distanceMeters == null ? null : 'MANUAL'),
            backpackWeightKg: widget.session.cardio?.backpackWeightKg,
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
        splits: [...routeSplits, ...intervalSplits],
      );
      // Baseline is every other cardio session already known locally — read
      // once, here, rather than a dedicated repository query: the whole list
      // is already resident via `workoutSessionControllerProvider`
      // (`watchAll()`), and the strength engine's own `getPrBaseline` is the
      // only place that owns a second raw-row query, for a table
      // (`exerciseSets`) `WorkoutSession` doesn't already assemble.
      final priorSessions = (ref.read(workoutSessionControllerProvider).value ?? const [])
          .where((s) => s.clientId != _clientId);
      final baseline = CardioPrBaseline.fromSessions(priorSessions);
      final newRecords = detectCardioPrs(baseline, finishedSession);
      navigator.pushReplacement(
        MaterialPageRoute(
          builder: (_) => CardioSummaryScreen(
            session: finishedSession,
            newRecords: newRecords,
            // The baseline as it stood *before* this session — what the
            // celebration names as the record just replaced (C6.7, M36).
            previousBests: baseline,
          ),
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

  /// Marks a waypoint at [_lastFix] (M41) — appended, never replacing what's
  /// already there, so a failed write can simply be retried without losing
  /// earlier marks. The 4 s feedback banner is purely local state; the write
  /// itself is fire-and-forget from the user's point of view (same shape as
  /// every other live-metric edit on this screen), since undo within the
  /// window still has the original list to fall back to.
  Future<void> _markWaypoint() async {
    final fix = _lastFix;
    if (fix == null) return;
    final waypoint = CardioWaypoint(
      waypointIndex: _waypoints.length,
      latitude: fix.latitude,
      longitude: fix.longitude,
      altitudeMeters: fix.altitude,
    );
    final updated = [..._waypoints, waypoint];
    setState(() {
      _waypoints = updated;
      _justMarkedWaypoint = waypoint;
    });
    _armWaypointFeedbackTimer();
    unawaited(ref.read(workoutSessionControllerProvider.notifier).updateLiveWaypoints(
          _clientId,
          startedAt: _startedAt,
          waypoints: updated,
        ));
  }

  /// "Vissza" — undoes exactly the mark [_markWaypoint] just made, only
  /// reachable while its feedback banner is still showing.
  Future<void> _undoLastWaypoint() async {
    final justMarked = _justMarkedWaypoint;
    if (justMarked == null) return;
    _waypointFeedbackTimer?.cancel();
    final updated = _waypoints.where((w) => w.waypointIndex != justMarked.waypointIndex).toList();
    setState(() {
      _waypoints = updated;
      _justMarkedWaypoint = null;
    });
    unawaited(ref.read(workoutSessionControllerProvider.notifier).updateLiveWaypoints(
          _clientId,
          startedAt: _startedAt,
          waypoints: updated,
        ));
  }

  void _armWaypointFeedbackTimer() {
    _waypointFeedbackTimer?.cancel();
    _waypointFeedbackTimer = Timer(const Duration(seconds: 4), () {
      if (mounted) setState(() => _justMarkedWaypoint = null);
    });
  }

  /// M41's "8,24 km · 612 m · 12:19" — the session's own live numbers at the
  /// moment of marking, since a waypoint has nothing else to show yet (no
  /// label in V1, docs/cardio/60 Q-D5).
  String _waypointFeedbackDetail(AppLocalizations l10n, CardioWaypoint waypoint) {
    final unitSystem =
        (ref.read(settingsControllerProvider).value ?? const UserSettings.defaults()).unitSystem;
    final parts = <String>[
      if ((_distanceMeters ?? 0) > 0) CardioFormatter.distance(_distanceMeters!, unitSystem),
      if (waypoint.altitudeMeters != null)
        CardioFormatter.elevation(waypoint.altitudeMeters!, unitSystem),
      CardioFormatter.duration(Duration(seconds: _liveMovingSeconds)),
    ];
    return parts.join(' · ');
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
    int? scorePoints,
    int? scoreAssists,
    int? scoreRebounds,
  }) async {
    final l10n = AppLocalizations.of(context)!;
    final newDistance = distanceMeters ?? _distanceMeters;
    final newCadence = avgCadence ?? _avgCadence;
    final newWatts = avgWatts ?? _avgWatts;
    final newResistance = resistanceLevel ?? _resistanceLevel;
    final newPoints = scorePoints ?? _scorePoints;
    final newAssists = scoreAssists ?? _scoreAssists;
    final newRebounds = scoreRebounds ?? _scoreRebounds;
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
              scorePoints: newPoints,
              scoreAssists: newAssists,
              scoreRebounds: newRebounds,
              // Carried through, not edited here: `updateLiveCardioMetrics`
              // full-replaces the cardio row, so any field this method omits
              // is *erased*. Before C9.2 nothing on a GAME session could
              // reach this method (distance/cadence/watts/resistance are all
              // DISTANCE/MACHINE), so the omission was latent — the box-score
              // stepper is the first GAME caller, and without these two lines
              // counting a basket would wipe the match's venue and intensity.
              venue: widget.session.cardio?.venue,
              intensity: widget.session.cardio?.intensity,
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
        _scorePoints = newPoints;
        _scoreAssists = newAssists;
        _scoreRebounds = newRebounds;
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

    // M10: while the signal's weak, pace/speed is blanked rather than
    // showing a stale average — "a tempó nem hazudik" — and the distance
    // number (still shown, since it's a monotonic total that stays
    // meaningful even through a gap) is labelled "estimated" instead. M04's
    // healthy state shows neither: a plain "GPS" chip is enough there.
    final weakSignal = _weakSignal;
    // Cycling shows speed (km/h), not pace (min/km) — docs/cardio/
    // 62-cardio-cycling-plan.md §2.2. Every other DISTANCE type unchanged.
    final isCycling = _activityType == 'CYCLING';
    final paceLabel =
        weakSignal ? l10n.noSignalLabel : (isCycling ? l10n.speedLabel : l10n.paceLabel);
    final paceValue = weakSignal
        ? (isCycling ? '—' : '—:—') // speed has no M:SS shape to blank into
        : (hasDistance
            ? ((isCycling
                    ? CardioFormatter.speed(_distanceMeters!, duration, unitSystem)
                    : CardioFormatter.pace(_distanceMeters!, duration, unitSystem)) ??
                '—')
            : '—');

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
                child: RoutePainter(
                  polyline: routePolyline,
                  height: 200,
                  waypoints: _activityType == 'HIKING' ? _waypoints : const [],
                ),
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
    final intervalState = _intervalState;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // M38 sits between the header and the dominant number, and takes
        // space from neither: the resistance stepper below is pixel-identical
        // either way.
        if (intervalState != null) ...[
          _IntervalPlayerBlock(
            state: intervalState,
            accent: accent,
            paused: !_isRunning,
            l10n: l10n,
          ),
          const SizedBox(height: 12),
        ],
        Opacity(
          opacity: _isRunning ? 1 : 0.62,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _DominantMetric(
                label: l10n.movingTimeLabel,
                value: CardioFormatter.duration(duration),
                // The one size change M38 allows against M05, and only while
                // a plan is playing: the countdown needs the 14 px.
                valueFontSize: intervalState == null ? 96 : 82,
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
          valueColor: benched ? scheme.onSurfaceVariant : null,
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
        // C9.2/M44 — the offer is asked at most once ever, and the stepper
        // sits *above* the court/bench switch rather than replacing it: that
        // switch keeps its size and its place, since it is the control a
        // player reaches for without looking.
        if (_boxScoreOffer == BoxScoreOffer.unanswered && !_isFinished) ...[
          const SizedBox(height: 14),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: BoxScoreOfferCard(
              onAccept: () => unawaited(_answerBoxScoreOffer(BoxScoreOffer.accepted)),
              onDecline: () => unawaited(_answerBoxScoreOffer(BoxScoreOffer.declined)),
            ),
          ),
        ],
        if (_boxScoreOpen) ...[
          const SizedBox(height: 14),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: BoxScoreStepper(
              columns: _boxScoreColumns(l10n),
              enabled: !(_busy || _isFinished),
              onInteraction: _armBoxScoreIdleTimer,
            ),
          ),
        ],
      ],
    );
  }

  /// Three columns for basketball, **two for football** (M44): a rebound is
  /// not a concept there, so the column is absent rather than pinned at zero.
  /// Football's first column is the same stored `scorePoints` field, named
  /// "goals" for the sport.
  List<BoxScoreColumn> _boxScoreColumns(AppLocalizations l10n) {
    final isBasketball = _activityType == 'BASKETBALL';
    return [
      BoxScoreColumn(
        label: isBasketball ? l10n.boxScorePointsLabel : l10n.boxScoreGoalsLabel,
        value: _scorePoints ?? 0,
        onStep: (delta) => unawaited(_stepBoxScore(points: delta)),
      ),
      if (isBasketball)
        BoxScoreColumn(
          label: l10n.boxScoreReboundsLabel,
          value: _scoreRebounds ?? 0,
          onStep: (delta) => unawaited(_stepBoxScore(rebounds: delta)),
        ),
      BoxScoreColumn(
        label: l10n.boxScoreAssistsLabel,
        value: _scoreAssists ?? 0,
        onStep: (delta) => unawaited(_stepBoxScore(assists: delta)),
      ),
    ];
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

    // M38: on a hard section the top third of the screen is painted, not
    // just labelled — sweating, with peripheral vision, the colour field is
    // what carries. Behind the content, and never on an easy section.
    final hardSection = _intervalState != null &&
        !_intervalState!.finished &&
        _intervalState!.intensity == IntervalIntensity.hard &&
        _isRunning;

    return Scaffold(
      backgroundColor: scheme.surface,
      body: SafeArea(
        child: Stack(
          children: [
            if (hardSection)
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                height: MediaQuery.sizeOf(context).height / 3,
                child: IgnorePointer(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          activityTypeColor(_activityType, context).withValues(alpha: 0.22),
                          activityTypeColor(_activityType, context).withValues(alpha: 0),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
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
                    // DISTANCE has always had it (auto-pause, C4a.5a).
                    // MACHINE grows one only while a plan is playing, for
                    // Q-D4's "kikapcsolható" sound — with no plan there is
                    // nothing to configure and no gear, so M05 is intact.
                    onSettings: _family == ActivityFamily.distance ||
                            (_family == ActivityFamily.machine && _intervalState != null)
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
    // Cycling shows speed (km/h), not pace (min/km) — docs/cardio/
    // 62-cardio-cycling-plan.md §2.2. Every other DISTANCE type unchanged.
    final paceOrSpeed = hasDistance && _family == ActivityFamily.distance
        ? (_activityType == 'CYCLING'
            ? CardioFormatter.speed(_distanceMeters!, duration, unitSystem)
            : CardioFormatter.pace(_distanceMeters!, duration, unitSystem))
        : null;
    final parts = <String>[
      if (hasDistance) CardioFormatter.distance(_distanceMeters!, unitSystem),
      CardioFormatter.duration(duration),
      if (paceOrSpeed != null) paceOrSpeed,
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
      children.add(Row(
        children: [
          Expanded(
            child: _WideActionButton(
              icon: Icons.pause,
              label: l10n.gameMatchPauseLabel,
              onPressed: _busy ? null : pause,
            ),
          ),
          const SizedBox(width: 12),
          // M44's bottom-right circle — the same corner DISTANCE's trailing
          // circle already sits in. It only opens and closes the panel; the
          // court/bench switch above is untouched.
          _CircleAction(
            key: const Key('boxScoreCircle'),
            icon: Icons.scoreboard,
            label: l10n.boxScoreCircleLabel,
            onPressed: _toggleBoxScore,
          ),
        ],
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

    // M41: the waypoint marker — HIKING only, directly above the thumb zone
    // and the finish-gesture bar it must never overlap. A full-width hasáb
    // rather than a fourth circle, so it can't be confused with the three
    // circular controls above it, and stays reachable in gloves/boots.
    if (_activityType == 'HIKING') {
      children.add(const SizedBox(height: 14));
      children.add(_WaypointMarkerButton(
        onPressed: _busy ? null : _markWaypoint,
        available: _gpsChipState != _GpsChipState.off,
        onUnavailableTap: () => setState(() => _locationCardDismissed = false),
        label: l10n.waypointMarkButtonLabel,
        subtitleLabel: l10n.waypointMarkButtonSubtitle,
        unavailableLabel: l10n.waypointMarkButtonUnavailable,
      ));
      final justMarked = _justMarkedWaypoint;
      if (justMarked != null) {
        children.add(const SizedBox(height: 10));
        children.add(_WaypointMarkedBanner(
          message: l10n.waypointMarkedFeedback(justMarked.waypointIndex + 1),
          detail: _waypointFeedbackDetail(l10n, justMarked),
          undoLabel: l10n.waypointMarkUndoLabel,
          onUndo: _undoLastWaypoint,
        ));
      }
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
    // M38: the same circle, the same size, in the same corner — while a plan
    // is playing it steps the section instead of opening the distance sheet.
    // The finish gesture below it is untouched.
    final intervalState = _intervalState;
    if (intervalState != null && !intervalState.finished && !_isFinished) {
      return _CircleAction(
        key: const Key('intervalSkipCircle'),
        icon: Icons.skip_next,
        label: l10n.intervalSkipCircleLabel,
        onPressed: _busy ? null : _skipIntervalSection,
      );
    }
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
    this.valueFontSize = 96,
  });

  final String label;
  final String value;

  /// 96 everywhere (M04/M05); 82 only on the MACHINE screen while an interval
  /// plan is playing, which is the single size change M38 makes against M05.
  final double valueFontSize;

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
                        fontSize: valueFontSize,
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
    super.key,
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

/// M41's "Útpont jelölése" bar — 88 px tall, full width, so it can't be
/// mistaken for one of the three circular controls above it and stays
/// reachable in gloves/boots. [available] false renders the "GPS nélkül"
/// state (M25): the button never disappears, it just stops accepting the
/// mark and opens the location explanation instead.
class _WaypointMarkerButton extends StatelessWidget {
  const _WaypointMarkerButton({
    required this.onPressed,
    required this.available,
    required this.onUnavailableTap,
    required this.label,
    required this.subtitleLabel,
    required this.unavailableLabel,
  });

  final VoidCallback? onPressed;
  final bool available;
  final VoidCallback onUnavailableTap;
  final String label;
  final String subtitleLabel;
  final String unavailableLabel;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: available ? scheme.tertiaryContainer : scheme.surfaceContainer,
      borderRadius: BorderRadius.circular(24),
      child: InkWell(
        key: const Key('waypointMarkButton'),
        onTap: available ? onPressed : onUnavailableTap,
        borderRadius: BorderRadius.circular(24),
        child: SizedBox(
          height: 88,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                available ? Icons.add_location_alt : Icons.location_off,
                size: 26,
                color: available ? scheme.onTertiaryContainer : scheme.onSurfaceVariant,
              ),
              const SizedBox(width: 12),
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.2,
                      color: available ? scheme.onTertiaryContainer : scheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    available ? subtitleLabel : unavailableLabel,
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: (available ? scheme.onTertiaryContainer : scheme.onSurfaceVariant)
                          .withValues(alpha: 0.72),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// M41's 4 s auto-dismissing "3. útpont megjelölve" confirmation, with the
/// numbers the waypoint itself has nothing else to show yet, and "Vissza" to
/// undo the mark it's reporting on.
class _WaypointMarkedBanner extends StatelessWidget {
  const _WaypointMarkedBanner({
    required this.message,
    required this.detail,
    required this.undoLabel,
    required this.onUndo,
  });

  final String message;
  final String detail;
  final String undoLabel;
  final VoidCallback onUndo;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      key: const Key('waypointMarkedBanner'),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          Icon(Icons.check_circle, size: 18, color: scheme.tertiary),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(message, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800)),
                if (detail.isNotEmpty)
                  Text(
                    detail,
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      color: scheme.onSurfaceVariant,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
              ],
            ),
          ),
          TextButton(onPressed: onUndo, child: Text(undoLabel)),
        ],
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

/// M38's player block: which section is running, how much of it is left, and
/// what comes next. Sits between the header and the dominant number and takes
/// space from neither — see [_DominantMetric.valueFontSize] for the one
/// concession (96 → 82 px) M38 allows itself against M05.
class _IntervalPlayerBlock extends StatelessWidget {
  const _IntervalPlayerBlock({
    required this.state,
    required this.accent,
    required this.paused,
    required this.l10n,
  });

  final IntervalPlayerState state;
  final Color accent;
  final bool paused;
  final AppLocalizations l10n;

  String _intensityLabel(IntervalIntensity intensity) => switch (intensity) {
        IntervalIntensity.easy => l10n.intervalIntensityEasy,
        IntervalIntensity.moderate => l10n.intervalIntensityModerate,
        IntervalIntensity.hard => l10n.intervalIntensityHard,
      };

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final hard = state.intensity == IntervalIntensity.hard;
    // The last three seconds are their own state: the screen stops reporting
    // the section that is ending and starts announcing the one that is coming.
    final countingDown = state.isCountingDown && !paused;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 13),
        decoration: BoxDecoration(
          color: scheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(24),
          border: hard && !paused ? Border.all(color: accent.withValues(alpha: 0.35)) : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  l10n.intervalSectionCounterLabel(state.sectionNumber, state.totalSections),
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.4,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
                if (paused) ...[
                  const SizedBox(width: 8),
                  Text(
                    l10n.intervalPausedSectionLabel,
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.4,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 2),
            if (state.finished)
              Text(
                l10n.intervalPlanFinishedLabel,
                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
              )
            else if (countingDown)
              _UpNext(state: state, accent: accent, l10n: l10n, label: _intensityLabel)
            else ...[
              Text(
                _intensityLabel(state.intensity).toUpperCase(),
                style: TextStyle(
                  fontSize: 30,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -1,
                  height: 1.1,
                  color: hard ? accent : scheme.onSurface,
                ),
              ),
              const SizedBox(height: 4),
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(
                    CardioFormatter.duration(Duration(seconds: state.secondsRemaining)),
                    style: const TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.8,
                      fontFeatures: [FontFeature.tabularFigures()],
                    ),
                  ),
                  const SizedBox(width: 7),
                  Text(
                    l10n.intervalRemainingLabel,
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
              if (state.nextIntensity != null) ...[
                const SizedBox(height: 6),
                Row(
                  children: [
                    Icon(Icons.arrow_forward, size: 15, color: scheme.onSurfaceVariant),
                    const SizedBox(width: 7),
                    Expanded(
                      child: Text(
                        l10n.intervalNextLabel(
                          CardioFormatter.duration(
                              Duration(seconds: state.nextDurationSeconds ?? 0)),
                          _intensityLabel(state.nextIntensity!),
                        ),
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ],
            if (paused && !state.finished) ...[
              const SizedBox(height: 8),
              Text(
                l10n.intervalPausedSectionBody,
                style: TextStyle(
                  fontSize: 11,
                  height: 1.45,
                  fontWeight: FontWeight.w500,
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// The last three seconds (M38): the screen switches from "this section" to
/// "the one starting now", with the count itself as the biggest thing on the
/// block.
class _UpNext extends StatelessWidget {
  const _UpNext({
    required this.state,
    required this.accent,
    required this.l10n,
    required this.label,
  });

  final IntervalPlayerState state;
  final Color accent;
  final AppLocalizations l10n;
  final String Function(IntervalIntensity) label;

  @override
  Widget build(BuildContext context) {
    final next = state.nextIntensity;
    final nextDuration =
        CardioFormatter.duration(Duration(seconds: state.nextDurationSeconds ?? 0));
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l10n.intervalUpNextLabel,
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.4,
                  color: accent,
                ),
              ),
              Text(
                next == null
                    ? l10n.intervalPlanFinishedLabel
                    : '$nextDuration ${label(next).toUpperCase()}',
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.8,
                  height: 1.2,
                ),
              ),
            ],
          ),
        ),
        Text(
          '${state.secondsRemaining}',
          style: TextStyle(
            fontSize: 44,
            fontWeight: FontWeight.w800,
            letterSpacing: -2,
            color: accent,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
      ],
    );
  }
}
