import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/format/cardio_formatter.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/widgets/activity_chip.dart';
import '../../../shared/widgets/app_snackbar.dart';
import '../../settings/application/settings_controller.dart';
import '../../settings/domain/user_settings.dart';
import '../application/workout_session_controller.dart';
import '../domain/activity_type.dart';
import '../domain/workout_session.dart';

/// The live cardio screen — skeleton (docs/cardio/59-cardio-implementation-plan.md
/// C2.1) plus all three family layouts: DISTANCE (C2.2), MACHINE (C2.3), and
/// GAME (C2.4).
///
/// `IDLE` never actually renders here: the screen is always constructed with
/// an already-started [session] (`startCardioSession` runs before the push —
/// today only reachable from tests, since the real entry point is C2.7's
/// quick-start flow). `ENDING` is a plain confirm dialog for now, standing in
/// for the slide-to-finish gesture C2.5 adds — accidental-tap protection
/// beyond "are you sure?" isn't this step's job.
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
  ConsumerState<CardioSessionScreen> createState() => _CardioSessionScreenState();
}

class _CardioSessionScreenState extends ConsumerState<CardioSessionScreen> {
  late final String _clientId;
  late final DateTime _startedAt;
  late final String _activityType;
  late int _movingSeconds;
  int? _movingSinceEpochMs;
  DateTime? _finishedAt;

  /// True whenever `movingSeconds` is frozen because of a whole-session
  /// pause (as opposed to, for GAME, just being benched) — see the class doc.
  late bool _manuallyPaused;

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

  Timer? _ticker;
  bool _busy = false;

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
    if (!_manuallyPaused && _finishedAt == null) _startTicker();
  }

  @override
  void dispose() {
    _ticker?.cancel();
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

  /// "Meccs szünet" — a whole-session pause. Freezes playing time *and*
  /// (for GAME) gross time; see the class doc.
  Future<void> _pause() async {
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
      _ticker?.cancel();
      setState(() {
        _manuallyPaused = true;
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
    } catch (_) {
      if (!mounted) return;
      setState(() => _busy = false);
      _showError(l10n);
    }
  }

  Future<void> _resume() async {
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
        if (willAccrueMoving) _movingSinceEpochMs = resumedAt.millisecondsSinceEpoch;
        if (_family == ActivityFamily.game) {
          _grossSinceEpochMs = resumedAt.millisecondsSinceEpoch;
        }
        _busy = false;
      });
      _startTicker();
    } catch (_) {
      if (!mounted) return;
      setState(() => _busy = false);
      _showError(l10n);
    }
  }

  /// GAME only — the "Pályán/Padon" toggle. Independent of [_pause]/
  /// [_resume]: benching never touches gross time, and re-pausing while
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
      }
    } catch (_) {
      if (!mounted) return;
      setState(() => _busy = false);
      _showError(l10n);
    }
  }

  Future<void> _confirmFinish() async {
    if (_busy || _isFinished) return;
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.finishCardioConfirmTitle),
        content: Text(l10n.finishCardioConfirmMessage),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(l10n.cancelButton),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(l10n.finishButtonLabel),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await _finish();
  }

  Future<void> _finish() async {
    final l10n = AppLocalizations.of(context)!;
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
      setState(() {
        _movingSeconds = total;
        _movingSinceEpochMs = null;
        _finishedAt = finishedAt;
        _busy = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _busy = false);
      _showError(l10n);
    }
  }

  /// A single-field numeric-entry dialog, shared by every manual metric edit
  /// on this screen (distance, cadence, power). `TextFormField` — not a
  /// manually-owned `TextEditingController` — so its own State disposes it;
  /// a controller disposed by hand right as `showDialog` resolves can still
  /// be attached to the outgoing route's closing transition for a frame,
  /// throwing "used after being disposed".
  Future<double?> _promptNumber(
    AppLocalizations l10n, {
    required String title,
    required String? suffix,
    required String initialText,
  }) {
    var enteredText = initialText;
    return showDialog<double>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(title),
        content: TextFormField(
          initialValue: enteredText,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[\d.,]'))],
          onChanged: (value) => enteredText = value,
          decoration: InputDecoration(suffixText: suffix, border: const OutlineInputBorder()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(l10n.cancelButton),
          ),
          FilledButton(
            onPressed: () {
              final parsed = double.tryParse(enteredText.replaceAll(',', '.').trim());
              Navigator.of(dialogContext).pop(parsed);
            },
            child: Text(l10n.saveButton),
          ),
        ],
      ),
    );
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
    final result = await _promptNumber(
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
    final result = await _promptNumber(
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
    final result = await _promptNumber(
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

    final statusLabel = _isFinished
        ? l10n.cardioSessionFinishedLabel
        : _isRunning
            ? l10n.inProgressLabel
            : l10n.cardioSessionPausedLabel;

    final Widget body;
    switch (_family) {
      case ActivityFamily.distance:
        body = _distanceBody(context, l10n, theme, scheme);
      case ActivityFamily.machine:
        body = _machineBody(context, l10n, theme, scheme);
      case ActivityFamily.game:
        body = _gameBody(context, l10n, theme, scheme);
    }

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: Text(activityTypeLabel(l10n, _activityType)),
      ),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ActivityChip(activityType: _activityType, size: 56),
            const SizedBox(height: 16),
            Text(
              statusLabel,
              style: theme.textTheme.labelLarge?.copyWith(color: scheme.onSurfaceVariant),
            ),
            const SizedBox(height: 8),
            body,
            const SizedBox(height: 32),
            if (!_isFinished)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_isRunning)
                    FilledButton.icon(
                      onPressed: _busy ? null : _pause,
                      icon: const Icon(Icons.pause),
                      label: Text(l10n.pauseButtonLabel),
                    )
                  else
                    FilledButton.icon(
                      onPressed: _busy ? null : _resume,
                      icon: const Icon(Icons.play_arrow),
                      label: Text(l10n.resumeButtonLabel),
                    ),
                  const SizedBox(width: 12),
                  OutlinedButton.icon(
                    onPressed: _busy ? null : _confirmFinish,
                    icon: const Icon(Icons.check),
                    label: Text(l10n.finishButtonLabel),
                  ),
                ],
              ),
          ],
        ),
      ),
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
