import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/format/cardio_formatter.dart';
import '../../../core/location/location_service.dart';
import '../../../core/location/location_service_geolocator.dart';
import '../../../core/workout_session_notifier/workout_session_notifier_service.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/widgets/activity_chip.dart';
import '../../../shared/widgets/app_snackbar.dart';
import '../../settings/application/settings_controller.dart';
import '../../settings/domain/user_settings.dart';
import '../application/workout_session_controller.dart';
import '../data/cardio_track_point_repository.dart';
import '../domain/activity_type.dart';
import '../domain/cardio_personal_record.dart';
import '../domain/workout_session.dart';
import 'cardio_summary_screen.dart';
import 'widgets/prompt_number_dialog.dart';
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
  // `CardioTrackPoints`, immediately, one at a time; nothing here computes
  // distance/route from them yet — that's `track_filter.dart` (C4a.4) and
  // the closing pipeline (C4a.6).
  StreamSubscription<LocationFix>? _positionSub;

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

  Timer? _ticker;
  bool _busy = false;

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

  @override
  void initState() {
    super.initState();
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
    if (_finishedAt == null) _startTicker();

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
    }
  }

  /// One-time DB read so [_nextTrackPointSeq] resumes correctly after an app
  /// kill mid-session (C4a.3) — see the field's own doc.
  Future<void> _seedTrackPointSeqAndSync() async {
    final count = await ref.read(cardioTrackPointRepositoryProvider).pointCount(_clientId);
    if (!mounted) return;
    _nextTrackPointSeq = count;
    _trackPointSeqSeeded = true;
    _syncPositionTracking();
  }

  /// Starts/stops the raw GPS point recording subscription to match current
  /// conditions — called whenever any of them could have changed:
  /// [_locationAvailability] updates, [_seedTrackPointSeqAndSync] finishes,
  /// and every [_pauseAs]/[resume] transition (both flip [_isRunning]).
  /// Idempotent either way — safe to call from all of those unconditionally.
  void _syncPositionTracking() {
    final shouldTrack = _trackPointSeqSeeded &&
        _family == ActivityFamily.distance &&
        (_locationAvailability?.canTrack ?? false) &&
        _isRunning;
    if (shouldTrack && _positionSub == null) {
      _positionSub = ref
          .read(locationServiceProvider)
          .positionStream(profile: locationTrackingProfileFor(_activityType))
          .listen(_onPositionFix);
    } else if (!shouldTrack && _positionSub != null) {
      _positionSub!.cancel();
      _positionSub = null;
    }
  }

  /// Writes [fix] to `CardioTrackPoints` immediately (C4a.3 — "kilőtt app
  /// legfeljebb egy pontot veszít"), never buffered in memory. Fire-and-forget:
  /// a single slow/failed write shouldn't stall the next fix's write, and
  /// there's nothing meaningful to show the user for one dropped point
  /// (the whole point of writing immediately is that this is rare).
  void _onPositionFix(LocationFix fix) {
    final seq = _nextTrackPointSeq++;
    unawaited(ref.read(cardioTrackPointRepositoryProvider).addPoint(_clientId, seq, fix));
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
    _finishProgress.dispose();
    _locationSub?.cancel();
    _positionSub?.cancel();
    if (_family == ActivityFamily.distance) WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  ActivityFamily get _family => activityFamilyOf(_activityType);

  bool get _isRunning => _finishedAt == null && !_manuallyPaused;
  bool get _isFinished => _finishedAt != null;

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

  /// Brings up the Live Activity / ongoing notification. Safe to call
  /// repeatedly — the retry entry point as well as the first attempt:
  /// no-ops while one is in flight, once it's up, or once the platform has
  /// refused for good. Mirrors `LogSessionScreen._startSessionNotifier`
  /// exactly, minus the watch-mirror push: that's C5's job, not C2.9's —
  /// docs/cardio/55-cardio-watch-plan.md's own D-C5.1 has the phone-side
  /// cardio processor land *before* anything sends it a payload.
  Future<void> _startSessionNotifier() async {
    if (!mounted || _isFinished) return;
    if (_startingSessionNotifier || _sessionNotifierStarted || _sessionNotifierUnavailable) {
      return;
    }
    final l10n = AppLocalizations.of(context)!;
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

  /// Pushes the current state to the native surface. No-ops there when
  /// nothing's showing (iOS finds no activity, Android has no notification
  /// to re-render), so this is safe to call after every state change
  /// regardless of whether [_startSessionNotifier] ever actually succeeded.
  Future<void> _updateSessionNotifier() async {
    if (!mounted) return;
    final l10n = AppLocalizations.of(context)!;
    await ref.read(workoutSessionNotifierServiceProvider).update(
          sessionClientId: _clientId,
          startedLabel: l10n.startedLabel,
          state: _liveSessionState(l10n),
        );
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

  /// The **only** way a live cardio session ends — reached exclusively
  /// through [_SlideToFinishBar]'s drag-past-threshold or long-press, never
  /// a plain tap (docs/cardio/59-cardio-implementation-plan.md C2.5 kész-ha).
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
    try {
      await ref.read(workoutSessionControllerProvider.notifier).finishCardioSession(
            _clientId,
            startedAt: _startedAt,
            finishedAt: finishedAt,
            movingSeconds: total,
          );
      if (!mounted) return;
      _ticker?.cancel();
      unawaited(ref.read(workoutSessionNotifierServiceProvider).end());
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
      final originalCardio = widget.session.cardio;
      final finishedSession = WorkoutSession(
        clientId: _clientId,
        exercises: const [],
        sets: const [],
        startedAt: _startedAt,
        finishedAt: finishedAt,
        sessionKind: 'CARDIO',
        activityType: _activityType,
        movingSeconds: total,
        cardio: CardioMetrics(
          distanceMeters: _distanceMeters,
          avgCadence: _avgCadence,
          avgWatts: _avgWatts,
          resistanceLevel: _resistanceLevel,
          venue: originalCardio?.venue,
          intensity: originalCardio?.intensity,
          scorePoints: originalCardio?.scorePoints,
          distanceSource: _distanceMeters == null ? null : 'MANUAL',
        ),
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

  /// Opens a dialog to manually set the distance-so-far — the only way a
  /// DISTANCE session's distance ever gets a value until GPS (C4a) exists.
  /// Also used by MACHINE's distance tile (a stationary bike's own distance
  /// is an estimate anyway — docs/cardio/design M05 note — so it's just
  /// another manually-entered secondary field there, no fallback logic).
  Future<void> _editDistance() async {
    if (_busy || _isFinished) return;
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
              distanceSource: newDistance == null ? null : 'MANUAL',
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
    final paceValue =
        hasDistance ? (CardioFormatter.pace(_distanceMeters!, duration, unitSystem) ?? '—') : '—';

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _DominantMetric(
          label: dominantLabel,
          value: dominantValue,
          onTap: _busy || _isFinished ? null : _editDistance,
        ),
        const SizedBox(height: 20),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _MetricTile(
              label: secondaryLabel,
              value: secondaryValue,
              onTap: hasDistance || _busy || _isFinished ? null : _editDistance,
            ),
            const SizedBox(width: 10),
            _MetricTile(label: l10n.paceLabel, value: paceValue),
            const SizedBox(width: 10),
            _MetricTile(label: l10n.heartRateFieldLabel, value: '—'),
          ],
        ),
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
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _DominantMetric(
          label: l10n.movingTimeLabel,
          value: CardioFormatter.duration(duration),
        ),
        const SizedBox(height: 20),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _MetricTile(
              label: l10n.distanceFieldLabel,
              value: _distanceMeters == null
                  ? '—'
                  : CardioFormatter.distance(_distanceMeters!, unitSystem),
              onTap: _busy || _isFinished ? null : _editDistance,
            ),
            const SizedBox(width: 10),
            _MetricTile(
              label: l10n.avgCadenceFieldLabel,
              value: _avgCadence == null ? '—' : '${_avgCadence!.round()} rpm',
              onTap: _busy || _isFinished ? null : _editCadence,
            ),
            const SizedBox(width: 10),
            _MetricTile(
              label: l10n.avgWattsFieldLabel,
              value: _avgWatts == null ? '—' : '${_avgWatts!.round()} W',
              onTap: _busy || _isFinished ? null : _editPower,
            ),
          ],
        ),
        const SizedBox(height: 20),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(l10n.resistanceLevelFieldLabel, style: theme.textTheme.labelLarge),
            const SizedBox(width: 12),
            IconButton.outlined(
              onPressed: _busy || _isFinished || (_resistanceLevel ?? 0) <= 0
                  ? null
                  : () => _adjustResistance(-1),
              icon: const Icon(Icons.remove),
            ),
            SizedBox(
              width: 32,
              child: Text(
                '${_resistanceLevel ?? 0}',
                textAlign: TextAlign.center,
                style: theme.textTheme.titleMedium,
              ),
            ),
            IconButton.outlined(
              onPressed: _busy || _isFinished ? null : () => _adjustResistance(1),
              icon: const Icon(Icons.add),
            ),
          ],
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

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _DominantMetric(
          label: l10n.playingTimeLabel,
          value: CardioFormatter.duration(playingDuration),
        ),
        const SizedBox(height: 20),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _MetricTile(label: l10n.grossTimeLabel, value: CardioFormatter.duration(grossDuration)),
            const SizedBox(width: 10),
            _MetricTile(label: l10n.heartRateFieldLabel, value: '—'),
            const SizedBox(width: 10),
            _MetricTile(label: l10n.zoneFieldLabel, value: '—'),
          ],
        ),
        const SizedBox(height: 24),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _CourtToggleButton(
              label: l10n.onCourtLabel,
              icon: Icons.sports_basketball,
              selected: _onCourt,
              onPressed:
                  _busy || _isFinished || _manuallyPaused ? null : () => _setOnCourt(true),
            ),
            const SizedBox(width: 10),
            _CourtToggleButton(
              label: l10n.onBenchLabel,
              icon: Icons.event_seat,
              selected: !_onCourt,
              onPressed:
                  _busy || _isFinished || _manuallyPaused ? null : () => _setOnCourt(false),
            ),
          ],
        ),
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
    final showGpsOffChip =
        _family == ActivityFamily.distance && availability != null && !availability.canTrack;

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: Text(activityTypeLabel(l10n, _activityType)),
        actions: [
          if (showGpsOffChip) _GpsOffChip(label: l10n.locationOffChipLabel),
        ],
      ),
      body: Stack(
        children: [
          Center(
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ActivityChip(activityType: _activityType, size: 56),
                  const SizedBox(height: 16),
                  if (!paused)
                    Text(
                      l10n.inProgressLabel,
                      style: theme.textTheme.labelLarge?.copyWith(color: scheme.onSurfaceVariant),
                    )
                  else
                    _PauseStatusCard(
                      l10n: l10n,
                      auto: _pauseReason == _PauseReason.auto,
                      elapsed: _pausedDuration,
                    ),
                  const SizedBox(height: 8),
                  if (locationCardContent != null) ...[
                    _LocationStatusCard(
                      content: locationCardContent,
                      dismissLabel: l10n.locationDismissButton,
                      busy: _locationActionBusy,
                      onAction: () => _handleLocationCardAction(locationCardContent),
                      onDismiss: () => setState(() => _locationCardDismissed = true),
                    ),
                    const SizedBox(height: 8),
                  ],
                  // "Szünetben a domináns szám és a metrikák kiszürkülnek" —
                  // M08's note: nothing here is still ticking, so graying it
                  // out keeps that obvious without disabling the tap-to-edit
                  // affordances underneath (those stay live on purpose — a
                  // paused session is exactly when correcting a metric by
                  // hand is easiest).
                  Opacity(opacity: paused ? 0.6 : 1, child: familyBody),
                  const SizedBox(height: 32),
                  if (_isRunning)
                    FilledButton.icon(
                      onPressed: _busy ? null : pause,
                      icon: const Icon(Icons.pause),
                      label: Text(l10n.pauseButtonLabel),
                    )
                  else if (_pauseReason == _PauseReason.auto)
                    _AutoPauseResumeButton(
                      onPressed: _busy ? null : resume,
                      titleLabel: l10n.autoPauseResumeHintTitle,
                      subtitleLabel: l10n.autoPauseResumeHintSubtitle,
                    )
                  else
                    FilledButton.icon(
                      onPressed: _busy ? null : resume,
                      icon: const Icon(Icons.play_arrow),
                      label: Text(l10n.resumeButtonLabel),
                    ),
                  const SizedBox(height: 20),
                  SizedBox(
                    key: const Key('slideToFinishBar'),
                    width: 280,
                    child: _SlideToFinishBar(
                      progress: _finishProgress,
                      onFinish: _finish,
                      label: l10n.slideToFinishLabel,
                      releaseLabel: l10n.slideToFinishReleaseLabel,
                    ),
                  ),
                ],
              ),
            ),
          ),
          _FinishConfirmationOverlay(
            progress: _finishProgress,
            title: l10n.finishCardioConfirmTitle,
            message: l10n.finishCardioConfirmMessage,
            cancelLabel: l10n.slideToFinishCancelLabel,
            progressHint: l10n.slideToFinishProgressHint,
          ),
        ],
      ),
    );
  }
}

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
/// skippable).
class _GpsOffChip extends StatelessWidget {
  const _GpsOffChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(right: 16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
        decoration: BoxDecoration(
          color: scheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.location_disabled, size: 15, color: scheme.onSurfaceVariant),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: scheme.onSurfaceVariant),
            ),
          ],
        ),
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
    // reads as "the system did this", not the neutral tone a manual pause
    // (M08) uses — matching that color to any semantic theme color would
    // be a coincidence, so it's a literal, non-themed accent here.
    const autoAccent = Color(0xFFC49A6C);
    final accent = auto ? autoAccent : scheme.onSurfaceVariant;
    final title = auto ? l10n.autoPauseCardTitle : l10n.manualPauseCardTitle;

    return Container(
      constraints: const BoxConstraints(maxWidth: 340),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: auto ? autoAccent.withValues(alpha: 0.14) : scheme.surfaceContainerLow,
        border: auto ? Border.all(color: autoAccent.withValues(alpha: 0.5), width: 1.5) : null,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(auto ? Icons.motion_photos_paused : Icons.pause_circle, color: accent),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: TextStyle(fontWeight: FontWeight.w800, color: accent)),
                const SizedBox(height: 3),
                Text(
                  auto
                      ? l10n.autoPauseCardMessage
                      : l10n.manualPauseCardSubtitle(
                          elapsed == null ? '—' : CardioFormatter.duration(elapsed!)),
                  style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
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
    const autoAccent = Color(0xFFC49A6C);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(24),
        child: Container(
          width: 280,
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            border: Border.all(color: autoAccent.withValues(alpha: 0.6), width: 2),
            borderRadius: BorderRadius.circular(24),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                titleLabel,
                style: const TextStyle(fontWeight: FontWeight.w800, color: autoAccent),
              ),
              const SizedBox(height: 2),
              Text(subtitleLabel, style: TextStyle(fontSize: 12, color: autoAccent.withValues(alpha: 0.85))),
            ],
          ),
        ),
      ),
    );
  }
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
                  color: scheme.surfaceContainerHigh,
                  borderRadius: BorderRadius.circular(26),
                ),
                child: Stack(
                  children: [
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
                        padding: const EdgeInsets.only(right: 18),
                        child: Icon(Icons.flag, color: scheme.onSurfaceVariant),
                      ),
                    ),
                    Center(
                      child: Text(
                        released ? widget.releaseLabel : widget.label,
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          color: value > 0.4 ? scheme.onPrimary : scheme.onSurfaceVariant,
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
  });

  final ValueNotifier<double> progress;
  final String title;
  final String message;
  final String cancelLabel;
  final String Function(int percent) progressHint;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ValueListenableBuilder<double>(
      valueListenable: progress,
      builder: (context, value, _) {
        if (value <= 0) return const SizedBox.shrink();
        final remainingPercent = (100 * (1 - value)).clamp(0, 100).round();
        return Positioned.fill(
          child: Container(
            color: Colors.black.withValues(alpha: 0.55),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.flag_circle, size: 56, color: scheme.primary),
                  const SizedBox(height: 16),
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32),
                    child: Text(
                      message,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.white70),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    progressHint(remainingPercent),
                    style: TextStyle(color: scheme.primary, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 24),
                  TextButton.icon(
                    onPressed: () => progress.value = 0,
                    icon: const Icon(Icons.close, color: Colors.white70),
                    label: Text(cancelLabel, style: const TextStyle(color: Colors.white70)),
                  ),
                ],
              ),
            ),
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
  const _DominantMetric({required this.label, required this.value, this.onTap});

  final String label;
  final String value;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Column(
          children: [
            Text(
              label,
              style: theme.textTheme.labelSmall?.copyWith(
                color: scheme.onSurfaceVariant,
                letterSpacing: 1.2,
                fontWeight: FontWeight.w700,
              ),
            ),
            Text(
              value,
              style: theme.textTheme.displayLarge?.copyWith(fontWeight: FontWeight.w800),
            ),
          ],
        ),
      ),
    );
  }
}

/// One secondary-metric box — tappable when [onTap] is given.
class _MetricTile extends StatelessWidget {
  const _MetricTile({required this.label, required this.value, this.onTap});

  final String label;
  final String value;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        width: 96,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        decoration: BoxDecoration(
          color: scheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              value,
              style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
            ),
            Text(
              label,
              textAlign: TextAlign.center,
              style: theme.textTheme.labelSmall?.copyWith(color: scheme.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}

/// One half of the GAME family's "Pályán/Padon" switch — large, thumb-zone
/// sized per docs/cardio/53-cardio-mobile-plan.md §4.3's explicit ask
/// ("A kapcsoló nagy, hüvelykkel elérhető").
class _CourtToggleButton extends StatelessWidget {
  const _CourtToggleButton({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onPressed,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SizedBox(
      width: 130,
      height: 84,
      child: Material(
        color: selected ? scheme.primary : scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(20),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: selected ? scheme.onPrimary : scheme.onSurfaceVariant),
              const SizedBox(height: 6),
              Text(
                label,
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  color: selected ? scheme.onPrimary : scheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
