import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/format/cardio_formatter.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/widgets/activity_chip.dart';
import '../../../shared/widgets/app_snackbar.dart';
import '../../../shared/widgets/charts/time_series_chart.dart';
import '../../settings/application/settings_controller.dart';
import '../../settings/domain/user_settings.dart';
import '../application/workout_session_controller.dart';
import '../domain/activity_type.dart';
import '../domain/cardio_personal_record.dart';
import '../domain/route_encoder.dart';
import '../domain/workout_session.dart';
import 'widgets/prompt_number_dialog.dart';
import 'widgets/route_painter.dart';
import 'widgets/rpe_selector.dart';
import 'workouts_screen.dart';

/// The cardio summary screen (docs/cardio/59-cardio-implementation-plan.md
/// C2.8, M14/M15) — reached two ways, always the same widget:
/// `CardioSessionScreen._finish()` replaces itself with this the instant a
/// live session ends, and `open_workout_screens.dart` opens it for any
/// already-finished cardio session reopened later (manually logged via
/// `LogCardioSheet`, C1.8/C1.9, or a past live one). One screen, not two —
/// a value edited here reads back the same whether you edit it the moment
/// you finish or three weeks later.
///
/// **Route-free, deliberately** — the plan's own C2.8 row calls this the
/// "útvonal nélküli változat" (routeless variant); the GPS route, splits,
/// and elevation profile are C4a.6's job, and MACHINE's power-curve chart
/// needs time-series power samples this app doesn't record yet. Showing
/// none of that isn't a placeholder gap: GPS doesn't exist anywhere in the
/// app before C4a, so *no* cardio session has a route to show yet, live or
/// logged.
///
/// **Editing, per docs/cardio/51-cardio-overview-plan.md R8**: "minden
/// metrikának van `source` jelzése (`MEASURED`/`MANUAL`/`DEVICE`); a kézi
/// felülírás nyer és megjelölődik." Only [CardioMetrics.distanceMeters] and
/// [CardioMetrics.deviceCalories] actually carry a `source` field today
/// (`distanceSource`/`caloriesSource`, set by C1.8/C2.2/C2.3's existing
/// manual-entry paths) — every other metric (elevation, cadence, watts,
/// resistance, GAME fields) has no provenance column at all, since nothing
/// in this app can measure them automatically yet either (no GPS, no BLE
/// trainer pairing, docs/cardio/53-cardio-mobile-plan.md §4.2's own "Extra
/// vezérlő" notes). Building per-metric provenance for fields nothing can
/// yet measure would be schema work with no payoff before it's needed —
/// this screen implements the *pattern* (tap to edit, "Edited" badge on a
/// `MANUAL` source) on the two fields where it's real today, and leaves the
/// rest read-only, carried over unchanged from however they were recorded.
class CardioSummaryScreen extends ConsumerStatefulWidget {
  const CardioSummaryScreen({super.key, required this.session, this.newRecords = const []});

  final WorkoutSession session;

  /// Cardio records [session] just broke, detected by
  /// `CardioSessionScreen._finish()` right before handing off here — always
  /// empty when this screen is reached by reopening an already-finished
  /// session (`open_workout_screens.dart`), since re-viewing a past session
  /// isn't the moment it earned anything. See `cardio_personal_record.dart`.
  final List<CardioPrType> newRecords;

  @override
  ConsumerState<CardioSummaryScreen> createState() => _CardioSummaryScreenState();
}

class _CardioSummaryScreenState extends ConsumerState<CardioSummaryScreen> {
  static final _dateLabel = DateFormat('EEE, MMM d · HH:mm');

  late final String _clientId;
  late final DateTime _startedAt;
  late final String _activityType;
  late final ActivityFamily _family;
  late final Duration? _duration;

  double? _distanceMeters;
  String? _distanceSource;
  double? _deviceCalories;
  String? _caloriesSource;

  // Read-only carry-over — no provenance field exists for any of these yet
  // (see the class doc), so they're never edited on this screen, just
  // preserved byte-for-byte across every write this screen makes.
  double? _elevationGainMeters;
  double? _avgCadence;
  double? _avgWatts;
  int? _resistanceLevel;
  String? _venue;
  int? _intensity;
  int? _scorePoints;

  // C4a.6 — the closing route, also read-only carry-over here (this screen
  // has no route re-processing UI, only `CardioSessionScreenState._finish()`
  // ever produces these). Must still round-trip through every
  // `_persistCardio` write below — `updateLiveCardioMetrics` replaces the
  // whole `CardioMetrics` row, so omitting these here would silently erase
  // the route the moment someone edits, say, the distance on this screen.
  String? _routePolyline;
  int? _routePointCount;

  int? _rpe;
  late final TextEditingController _noteController;
  late final FocusNode _noteFocusNode;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    final s = widget.session;
    _clientId = s.clientId;
    _startedAt = s.startedAt!;
    _activityType = s.activityType!;
    _family = s.family!;
    _duration = s.effectiveDuration;

    final cardio = s.cardio;
    _distanceMeters = cardio?.distanceMeters;
    _distanceSource = cardio?.distanceSource;
    _deviceCalories = cardio?.deviceCalories;
    _caloriesSource = cardio?.caloriesSource;
    _elevationGainMeters = cardio?.elevationGainMeters;
    _avgCadence = cardio?.avgCadence;
    _avgWatts = cardio?.avgWatts;
    _resistanceLevel = cardio?.resistanceLevel;
    _venue = cardio?.venue;
    _intensity = cardio?.intensity;
    _scorePoints = cardio?.scorePoints;
    _routePolyline = cardio?.routePolyline;
    _routePointCount = cardio?.routePointCount;

    _rpe = s.rpe;
    _noteController = TextEditingController(text: s.feedbackNote ?? '');
    _noteFocusNode = FocusNode()..addListener(_onNoteFocusChange);
  }

  @override
  void dispose() {
    _noteFocusNode.dispose();
    _noteController.dispose();
    super.dispose();
  }

  void _showError(AppLocalizations l10n) {
    if (!mounted) return;
    AppSnackbar.showError(context, title: l10n.couldNotUpdateWorkoutMessage);
  }

  void _onNoteFocusChange() {
    if (!_noteFocusNode.hasFocus) _saveFeedback();
  }

  /// Saves [_rpe]/the note together, same pairing `LogCardioSheet` submits
  /// at creation time. A no-op until the session has been rated at least
  /// once — `rateSession` requires a non-null `rpe`, so a note typed before
  /// ever tapping a rating simply doesn't have anywhere to attach yet.
  Future<void> _saveFeedback() async {
    final rpe = _rpe;
    if (rpe == null) return;
    final l10n = AppLocalizations.of(context)!;
    final note = _noteController.text.trim();
    try {
      await ref.read(workoutSessionControllerProvider.notifier).rateSession(
            _clientId,
            rpe: rpe,
            feedbackNote: note.isEmpty ? null : note,
          );
    } catch (_) {
      _showError(l10n);
    }
  }

  Future<void> _setRpe(int value) async {
    setState(() => _rpe = value);
    await _saveFeedback();
  }

  /// Persists a metric edit, merged against every other field this screen
  /// already knows about — a full replace of [CardioMetrics], same
  /// "reconstruct the whole object" shape `CardioSessionScreen._updateCardioMetrics`
  /// and `LogCardioSheet`'s submit both already use. Only the two fields
  /// named here ever get a new value; everything else round-trips through
  /// unchanged from local state.
  Future<void> _persistCardio({
    double? distanceMeters,
    String? distanceSource,
    double? deviceCalories,
    String? caloriesSource,
  }) async {
    final l10n = AppLocalizations.of(context)!;
    final newDistance = distanceMeters ?? _distanceMeters;
    final newDistanceSource = distanceSource ?? _distanceSource;
    final newCalories = deviceCalories ?? _deviceCalories;
    final newCaloriesSource = caloriesSource ?? _caloriesSource;
    setState(() => _busy = true);
    try {
      await ref.read(workoutSessionControllerProvider.notifier).updateLiveCardioMetrics(
            _clientId,
            startedAt: _startedAt,
            cardio: CardioMetrics(
              distanceMeters: newDistance,
              elevationGainMeters: _elevationGainMeters,
              avgCadence: _avgCadence,
              avgWatts: _avgWatts,
              resistanceLevel: _resistanceLevel,
              deviceCalories: newCalories,
              venue: _venue,
              intensity: _intensity,
              scorePoints: _scorePoints,
              distanceSource: newDistanceSource,
              caloriesSource: newCaloriesSource,
              routePolyline: _routePolyline,
              routePointCount: _routePointCount,
            ),
          );
      if (!mounted) return;
      setState(() {
        _distanceMeters = newDistance;
        _distanceSource = newDistanceSource;
        _deviceCalories = newCalories;
        _caloriesSource = newCaloriesSource;
        _busy = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _busy = false);
      _showError(l10n);
    }
  }

  Future<void> _editDistance() async {
    if (_busy) return;
    final l10n = AppLocalizations.of(context)!;
    final unitSystem =
        (ref.read(settingsControllerProvider).value ?? const UserSettings.defaults()).unitSystem;
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
    await _persistCardio(distanceMeters: result * unitMeters, distanceSource: 'MANUAL');
  }

  Future<void> _editDeviceCalories() async {
    if (_busy) return;
    final l10n = AppLocalizations.of(context)!;
    final result = await promptNumber(
      context,
      l10n,
      title: l10n.editDeviceCaloriesDialogTitle,
      suffix: 'kcal',
      initialText: _deviceCalories?.round().toString() ?? '',
    );
    if (result == null || result < 0 || !mounted) return;
    await _persistCardio(deviceCalories: result, caloriesSource: 'MANUAL');
  }

  /// The bottom "Done" button — reached whether this screen just replaced a
  /// live [CardioSessionScreen] (`_finish()` pushed it via `pushReplacement`
  /// onto an imperative `Navigator`, layered on top of the go_router shell —
  /// its own `context.go('/workouts')` call primes the Sessions tab *behind*
  /// this screen, but leaves this screen itself on top until it's dismissed)
  /// or a reopened already-finished session (`open_workout_screens.dart`).
  /// Either way, `context.go('/workouts')` is the reliable way back: go_router
  /// replaces its whole stack on `go()`, so it tears down this imperatively-
  /// pushed screen too, rather than depending on exactly how many routes
  /// happen to be underneath it right now (a plain `Navigator.pop()` would).
  void _done() {
    ref.read(workoutsSessionsTabRequestProvider.notifier).request();
    if (GoRouter.maybeOf(context) != null) {
      context.go('/workouts');
    } else if (Navigator.of(context).canPop()) {
      // Test/host harnesses without a GoRouter ancestor — falls back to a
      // plain pop rather than doing nothing.
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final unitSystem =
        (ref.watch(settingsControllerProvider).value ?? const UserSettings.defaults()).unitSystem;

    final polyline = _routePolyline;
    final hasRoute = polyline != null && polyline.isNotEmpty;

    return Scaffold(
      backgroundColor: scheme.surface,
      body: SafeArea(
        child: Column(
          children: [
            // M13's floating header capsule instead of an AppBar — the route
            // card below it is the hero, and a docked app bar would put a
            // hard edge above it.
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 8, 14, 0),
              child: _SummaryHeaderBar(
                title: activityTypeLabel(l10n, _activityType),
                onBack: () => Navigator.of(context).maybePop(),
              ),
            ),
            Expanded(
              child: ListView(
                padding: EdgeInsets.fromLTRB(14, 12, 14, MediaQuery.paddingOf(context).bottom + 12),
                children: [
                  // The route leads (M13) — inset card, not full-bleed.
                  if (hasRoute) ...[
                    ClipRRect(
                      borderRadius: BorderRadius.circular(26),
                      child: Container(
                        color: scheme.surfaceContainerLow,
                        child: RoutePainter(polyline: polyline, height: 262),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                  _IdentityRow(
                    activityType: _activityType,
                    title: activityTypeLabel(l10n, _activityType),
                    subtitle: _subtitleLine(l10n),
                    // M13's ⌚ pill: this session carries a Health/watch id,
                    // so its numbers came from the wrist, not the phone.
                    watchLabel: widget.session.healthWorkoutId != null ? l10n.watchChipLabel : null,
                  ),
                  if (widget.newRecords.isNotEmpty) ...[
                    const SizedBox(height: 14),
                    _NewRecordBanner(
                        types: widget.newRecords, l10n: l10n, theme: theme, scheme: scheme),
                  ],
                  const SizedBox(height: 16),
                  ..._metricSections(l10n, theme, scheme, unitSystem),
                  const SizedBox(height: 14),
                  _FeedbackCard(
                    l10n: l10n,
                    scheme: scheme,
                    theme: theme,
                    rpe: _rpe,
                    noteController: _noteController,
                    noteFocusNode: _noteFocusNode,
                    busy: _busy,
                    onRpeChanged: _busy ? (_) {} : _setRpe,
                  ),
                ],
              ),
            ),
            // M13–M16 all end the same way: one primary block, pinned, never
            // scrolled away.
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 4, 14, 14),
              child: SizedBox(
                height: 56,
                child: FilledButton.icon(
                  onPressed: _done,
                  icon: const Icon(Icons.check, size: 22),
                  label: Text(l10n.cardioSummaryDoneButton),
                  style: FilledButton.styleFrom(
                    textStyle: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w800),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// M13/M15's second header line: when it happened, plus the venue when the
  /// session has one ("Tegnap 19:24 · beltéri").
  String _subtitleLine(AppLocalizations l10n) {
    final date = _dateLabel.format(_startedAt.toLocal());
    final venue = switch (_venue) {
      'INDOOR' => l10n.venueIndoorLabel,
      'OUTDOOR' => l10n.venueOutdoorLabel,
      _ => null,
    };
    return venue == null ? date : '$date · ${venue.toLowerCase()}';
  }

  List<Widget> _metricSections(
    AppLocalizations l10n,
    ThemeData theme,
    ColorScheme scheme,
    UnitSystem unitSystem,
  ) {
    final durationValue = _duration == null ? '—' : CardioFormatter.duration(_duration);
    final hasDistance = (_distanceMeters ?? 0) > 0;

    final metrics = theme.extension<AppMetricColors>();
    final accent = activityTypeColor(_activityType, context);
    final heartRate = widget.session.averageHeartRate;
    final activeCalories = widget.session.activeCalories;

    switch (_family) {
      // M13: no single hero number here — the route is the hero, and the
      // numbers below it form one even six-cell grid.
      case ActivityFamily.distance:
        final pace = hasDistance && _duration != null
            ? CardioFormatter.pace(_distanceMeters!, _duration, unitSystem)
            : null;
        return [
          _MetricGrid(
            children: [
              _MetricTile(
                icon: Icons.straighten,
                iconColor: accent,
                label: l10n.distanceFieldLabel,
                value: hasDistance ? CardioFormatter.distance(_distanceMeters!, unitSystem) : '—',
                edited: hasDistance && _distanceSource == 'MANUAL',
                editedLabel: l10n.manuallyEditedBadgeLabel,
                onTap: _busy ? null : _editDistance,
              ),
              _MetricTile(
                icon: Icons.schedule,
                iconColor: metrics?.protein,
                label: l10n.durationSectionLabel,
                value: durationValue,
              ),
              if (pace != null)
                _MetricTile(
                  icon: Icons.speed,
                  iconColor: metrics?.calories,
                  label: l10n.paceLabel,
                  value: pace,
                ),
              if (_elevationGainMeters != null)
                _MetricTile(
                  icon: Icons.terrain,
                  iconColor: metrics?.weight,
                  label: l10n.elevationGainFieldLabel,
                  value: CardioFormatter.elevation(_elevationGainMeters!, unitSystem),
                ),
              if (heartRate != null)
                _MetricTile(
                  icon: Icons.favorite,
                  iconColor: metrics?.heart,
                  label: l10n.heartRateFieldLabel,
                  value: '${heartRate.round()} bpm',
                ),
              if (activeCalories != null)
                _MetricTile(
                  icon: Icons.local_fire_department,
                  iconColor: metrics?.calories,
                  label: l10n.caloriesLabel,
                  value: '${activeCalories.round()} kcal',
                ),
            ],
          ),
          ..._routeSections(l10n, theme, scheme, unitSystem),
        ];
      // M15: indoor sessions keep the big moving-time card, with the three
      // machine numbers nested inside it.
      case ActivityFamily.machine:
        return [
          _PrimaryMetricCard(
            label: l10n.movingTimeLabel,
            value: durationValue,
            scheme: scheme,
            theme: theme,
            inner: [
              _InnerMetric(
                label: l10n.distanceFieldLabel,
                value: hasDistance ? CardioFormatter.distance(_distanceMeters!, unitSystem) : '—',
                edited: _distanceSource == 'MANUAL',
                onTap: _busy ? null : _editDistance,
              ),
              if (_avgCadence != null)
                _InnerMetric(
                    label: l10n.avgCadenceFieldLabel, value: '${_avgCadence!.round()} rpm'),
              if (_avgWatts != null)
                _InnerMetric(label: l10n.avgWattsFieldLabel, value: '${_avgWatts!.round()} W'),
            ],
          ),
          const SizedBox(height: 12),
          _MetricGrid(
            children: [
              if (_resistanceLevel != null)
                _MetricTile(
                  icon: Icons.tune,
                  iconColor: accent,
                  label: l10n.resistanceLevelFieldLabel,
                  value: '$_resistanceLevel',
                ),
              if (heartRate != null)
                _MetricTile(
                  icon: Icons.favorite,
                  iconColor: metrics?.heart,
                  label: l10n.heartRateFieldLabel,
                  value: '${heartRate.round()} bpm',
                ),
              _MetricTile(
                icon: Icons.local_fire_department,
                iconColor: metrics?.calories,
                label: l10n.deviceCaloriesFieldLabel,
                value: _deviceCalories == null ? '—' : '${_deviceCalories!.round()} kcal',
                edited: _caloriesSource == 'MANUAL',
                editedLabel: l10n.manuallyEditedBadgeLabel,
                onTap: _busy ? null : _editDeviceCalories,
              ),
            ],
          ),
          const SizedBox(height: 12),
          // "Az »útvonal nélkül« nem üres hely, hanem kimondott állapot" —
          // for an indoor session this is the normal case, so it reads as an
          // explanation in a neutral tone, never as an error.
          _NoRouteCard(title: l10n.noRouteCardTitle, body: l10n.noRouteCardBody),
        ];
      case ActivityFamily.game:
        return [
          _PrimaryMetricCard(
            label: l10n.playingTimeLabel,
            value: durationValue,
            scheme: scheme,
            theme: theme,
          ),
          const SizedBox(height: 12),
          _MetricGrid(
            children: [
              if (_venue != null)
                _MetricTile(
                  icon: _venue == 'INDOOR' ? Icons.home : Icons.park,
                  iconColor: accent,
                  label: l10n.venueSectionLabel,
                  value: _venue == 'INDOOR' ? l10n.venueIndoorLabel : l10n.venueOutdoorLabel,
                ),
              if (_intensity != null)
                _MetricTile(
                  icon: Icons.local_fire_department,
                  iconColor: metrics?.calories,
                  label: l10n.intensitySectionLabel,
                  value: '$_intensity/5',
                ),
              if (heartRate != null)
                _MetricTile(
                  icon: Icons.favorite,
                  iconColor: metrics?.heart,
                  label: l10n.heartRateFieldLabel,
                  value: '${heartRate.round()} bpm',
                ),
              if (_scorePoints != null)
                _MetricTile(
                  icon: Icons.scoreboard,
                  iconColor: accent,
                  label: l10n.scorePointsFieldLabel,
                  value: '$_scorePoints',
                ),
            ],
          ),
        ];
    }
  }

  /// The route/elevation-profile/splits block (C4a.6) — DISTANCE only, and
  /// only once a session actually finished with a GPS trail
  /// (`CardioSessionScreenState._finish()` is the only place that ever sets
  /// [_routePolyline]; a manually-logged or GPS-denied session has none).
  /// This is the gap the class doc's "Route-free, deliberately" note
  /// describes — closed here, not by removing that note (a session that
  /// predates C4a still has no route to show, so the doc's reasoning still
  /// holds for it).
  List<Widget> _routeSections(
    AppLocalizations l10n,
    ThemeData theme,
    ColorScheme scheme,
    UnitSystem unitSystem,
  ) {
    final polyline = _routePolyline;
    // The route card itself is drawn at the very top of the screen now
    // (M13's hero) — what's left here is what sits *under* the metric grid.
    if (polyline == null || polyline.isEmpty) return const [];

    final sections = <Widget>[];

    // Synthetic, index-based "dates" — the decoded polyline carries no
    // timestamps (only lat/lng/altitude per point, see `route_encoder.dart`),
    // and `TimeSeriesChart` needs *some* DateTime to order/label its X axis.
    // The profile's job is showing the route's *shape* (where it climbs/
    // descends), not a real time axis — splits and moving time already cover
    // precise timing elsewhere on this screen.
    if (_elevationGainMeters != null) {
      final segments = decodeRouteSegments(polyline);
      var index = 0;
      final elevationPoints = <TimeSeriesPoint>[
        for (final segment in segments)
          for (final (_, _, alt) in segment)
            TimeSeriesPoint(date: _startedAt.add(Duration(seconds: index++)), value: alt),
      ];
      if (elevationPoints.length >= 2) {
        sections.addAll([
          const SizedBox(height: 12),
          // M16 — the profile lives in its own card with the gain/loss
          // summary on the same line as the section label.
          _SectionCard(
            label: l10n.elevationProfileSectionLabel,
            trailing: '+${CardioFormatter.elevation(_elevationGainMeters!, unitSystem)}',
            child: TimeSeriesChart(
              points: elevationPoints,
              dateLabelBuilder: (_) => '',
              valueLabelBuilder: (v) => CardioFormatter.elevation(v, unitSystem),
              height: 120,
            ),
          ),
        ]);
      }
    }

    final splits = widget.session.splits;
    if (splits.isNotEmpty) {
      // M14's split bars are scaled against the slowest full split, so the
      // fastest km fills the track and the rest are read against it.
      final fullSplits = splits.where((s) => s.distanceMeters >= 999).toList();
      final slowest =
          fullSplits.isEmpty ? 1 : fullSplits.map((s) => s.durationSeconds).reduce(math.max);
      final fastest =
          fullSplits.isEmpty ? 1 : fullSplits.map((s) => s.durationSeconds).reduce(math.min);
      sections.addAll([
        const SizedBox(height: 12),
        _SectionCard(
          label: l10n.splitsSectionLabel,
          child: Column(
            children: [
              for (final s in splits)
                _SplitRow(
                  split: s,
                  unitSystem: unitSystem,
                  theme: theme,
                  scheme: scheme,
                  accent: activityTypeColor(_activityType, context),
                  slowestSeconds: slowest,
                  fastestSeconds: fastest,
                ),
            ],
          ),
        ),
      ]);
    }

    return sections;
  }
}

/// M13/M15/M16's header capsule — back button, title, and nothing else the
/// app can't actually do (the frames also draw share/edit buttons; sharing
/// isn't built, and every metric here is edited by tapping it directly).
class _SummaryHeaderBar extends StatelessWidget {
  const _SummaryHeaderBar({required this.title, required this.onBack});

  final String title;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      height: 54,
      padding: const EdgeInsets.symmetric(horizontal: 6),
      decoration: BoxDecoration(
        color: scheme.surfaceContainer.withValues(alpha: 0.94),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        children: [
          Material(
            color: scheme.surface,
            borderRadius: BorderRadius.circular(16),
            child: InkWell(
              onTap: onBack,
              borderRadius: BorderRadius.circular(16),
              child: SizedBox(
                width: 42,
                height: 42,
                child: Icon(Icons.arrow_back, size: 22, color: scheme.onSurfaceVariant),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              title,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.3,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// M13's identity row under the route: chip, activity, when/where, and the
/// watch pill when the numbers came from the wrist.
class _IdentityRow extends StatelessWidget {
  const _IdentityRow({
    required this.activityType,
    required this.title,
    required this.subtitle,
    this.watchLabel,
  });

  final String activityType;
  final String title;
  final String subtitle;
  final String? watchLabel;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      children: [
        ActivityChip(activityType: activityType, size: 44),
        const SizedBox(width: 11),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.3,
                ),
              ),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        if (watchLabel != null)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
            decoration: BoxDecoration(
              color: scheme.primary.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.watch, size: 14, color: scheme.primary),
                const SizedBox(width: 5),
                Text(
                  watchLabel!,
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                    color: scheme.primary,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

/// The three-across metric grid (M13/M16) — fixed columns, so the numbers
/// line up in a grid instead of reflowing like a `Wrap`.
class _MetricGrid extends StatelessWidget {
  const _MetricGrid({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final rows = <Widget>[];
    for (var i = 0; i < children.length; i += 3) {
      final row = children.skip(i).take(3).toList();
      rows.add(IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (var c = 0; c < 3; c++) ...[
              if (c > 0) const SizedBox(width: 9),
              // The last row can be short — empty cells keep the columns
              // aligned rather than stretching two tiles across the width.
              Expanded(child: c < row.length ? row[c] : const SizedBox.shrink()),
            ],
          ],
        ),
      ));
      if (i + 3 < children.length) rows.add(const SizedBox(height: 9));
    }
    return Column(children: rows);
  }
}

/// A titled card wrapping one block of content (splits, elevation profile) —
/// M14/M16's `SECTION LABEL` + optional right-hand summary value.
class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.label, required this.child, this.trailing});

  final String label;
  final Widget child;
  final String? trailing;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 15, 16, 15),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.2,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ),
              if (trailing != null)
                Text(
                  trailing!,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: scheme.onSurfaceVariant,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

/// M15's "Nincs útvonal" explanation — an indoor session never had a trail
/// to lose, so this is a statement, not an error.
class _NoRouteCard extends StatelessWidget {
  const _NoRouteCard({required this.title, required this.body});

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: scheme.surfaceContainer,
              borderRadius: BorderRadius.circular(18),
            ),
            child: Icon(Icons.route, size: 28, color: scheme.outlineVariant),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w800,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  body,
                  style: TextStyle(fontSize: 11.5, height: 1.5, color: scheme.outline),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// One of the small metrics nested inside [_PrimaryMetricCard] (M15).
class _InnerMetric {
  const _InnerMetric({
    required this.label,
    required this.value,
    this.edited = false,
    this.onTap,
  });

  final String label;
  final String value;
  final bool edited;
  final VoidCallback? onTap;
}

class _PrimaryMetricCard extends StatelessWidget {
  const _PrimaryMetricCard({
    required this.label,
    required this.value,
    required this.scheme,
    required this.theme,
    this.inner = const [],
  });

  final String label;
  final String value;
  final ColorScheme scheme;
  final ThemeData theme;
  final List<_InnerMetric> inner;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: scheme.surfaceContainerLow,
      borderRadius: BorderRadius.circular(26),
      clipBehavior: Clip.antiAlias,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.6,
                color: scheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 2),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                value,
                style: const TextStyle(
                  fontSize: 56,
                  height: 1.1,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -2,
                  fontFeatures: [FontFeature.tabularFigures()],
                ),
              ),
            ),
            if (inner.isNotEmpty) ...[
              const SizedBox(height: 14),
              IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (var i = 0; i < inner.length; i++) ...[
                      if (i > 0) const SizedBox(width: 9),
                      Expanded(child: _InnerMetricTile(metric: inner[i])),
                    ],
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _InnerMetricTile extends StatelessWidget {
  const _InnerMetricTile({required this.metric});

  final _InnerMetric metric;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.surfaceContainer,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: metric.onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  metric.value,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    fontFeatures: [FontFeature.tabularFigures()],
                  ),
                ),
              ),
              Row(
                children: [
                  Flexible(
                    child: Text(
                      metric.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                  if (metric.edited) ...[
                    const SizedBox(width: 4),
                    const Icon(Icons.edit, size: 11, color: Color(0xFFC49A6C)),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Celebrates whatever [types] the just-finished session broke. Deliberately
/// a plain banner, not the strength `WorkoutSuccessDialog`'s confetti
/// treatment — that dialog cascades many per-exercise chips built from
/// `ExerciseBlock`s, which a routeless cardio session has none of, and this
/// screen's whole tone (read-only carry-over, no gimmicks — see the class
/// doc) is calmer than a post-workout dialog. Reuses the same trophy icon +
/// amber accent as `exercise_session_card.dart`'s `_prBadge` for a
/// consistent "you just set a record" visual language app-wide.
class _NewRecordBanner extends StatelessWidget {
  const _NewRecordBanner({
    required this.types,
    required this.l10n,
    required this.theme,
    required this.scheme,
  });

  final List<CardioPrType> types;
  final AppLocalizations l10n;
  final ThemeData theme;
  final ColorScheme scheme;

  static const _amber = Color(0xFFD8B35A);

  String _label(CardioPrType type) => switch (type) {
        CardioPrType.longestDistance => l10n.cardioRecordLongestDistance,
        CardioPrType.longestMovingTime => l10n.cardioRecordLongestMovingTime,
        CardioPrType.greatestElevationGain => l10n.cardioRecordGreatestElevationGain,
      };

  @override
  Widget build(BuildContext context) {
    return Material(
      color: _amber.withValues(alpha: 0.14),
      borderRadius: BorderRadius.circular(AppRadius.card),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.emoji_events, color: _amber),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.cardioNewRecordBannerTitle,
                    style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    types.map(_label).join(' · '),
                    style: theme.textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MetricTile extends StatelessWidget {
  const _MetricTile({
    required this.label,
    required this.value,
    this.icon,
    this.iconColor,
    this.edited = false,
    this.editedLabel,
    this.onTap,
  });

  final String label;
  final String value;
  final IconData? icon;
  final Color? iconColor;
  final bool edited;
  final String? editedLabel;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.surfaceContainerLow,
      borderRadius: BorderRadius.circular(20),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  if (icon != null)
                    Icon(icon, size: 17, color: iconColor ?? scheme.onSurfaceVariant),
                  const Spacer(),
                  if (edited && editedLabel != null)
                    _EditedBadge(label: editedLabel!, scheme: scheme),
                ],
              ),
              const SizedBox(height: 6),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  value,
                  style: const TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -1,
                    fontFeatures: [FontFeature.tabularFigures()],
                  ),
                ),
              ),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w600,
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The "kézzel szerkesztve" tag (docs/cardio/design M14) — shown whenever
/// the field's `source` is `'MANUAL'`, which today is the *only* non-null
/// source any metric ever has (see the screen's class doc) — so this reads
/// as "you typed this in" rather than "this differs from a measurement",
/// but the mechanism is exactly R8's: a manual value always wins, and
/// always says so.
class _EditedBadge extends StatelessWidget {
  const _EditedBadge({required this.label, required this.scheme});

  final String label;
  final ColorScheme scheme;

  @override
  Widget build(BuildContext context) {
    const accent = Color(0xFFC49A6C);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
          color: accent.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(8)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.edit, size: 12, color: accent),
          const SizedBox(width: 4),
          Text(label,
              style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: accent)),
        ],
      ),
    );
  }
}

/// "Hogy ment?" — RPE + note, always visible and always editable (unlike
/// the old read-only screen, which only showed this section once already
/// rated). Autosaves per docs/cardio/59-cardio-implementation-plan.md C2.8:
/// no "Mentés" button, matching the live screen's per-field-autosave
/// convention rather than the mockup's single bottom Save button — a
/// deliberate simplification, since a separate "unsaved changes" state
/// would be new complexity this screen doesn't otherwise need.
class _FeedbackCard extends StatelessWidget {
  const _FeedbackCard({
    required this.l10n,
    required this.scheme,
    required this.theme,
    required this.rpe,
    required this.noteController,
    required this.noteFocusNode,
    required this.busy,
    required this.onRpeChanged,
  });

  final AppLocalizations l10n;
  final ColorScheme scheme;
  final ThemeData theme;
  final int? rpe;
  final TextEditingController noteController;
  final FocusNode noteFocusNode;
  final bool busy;
  final ValueChanged<int> onRpeChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: scheme.primary.withValues(alpha: 0.08),
        border: Border.all(color: scheme.primary.withValues(alpha: 0.3)),
        borderRadius: BorderRadius.circular(AppRadius.card),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l10n.postWorkoutFeedbackTitle, style: theme.textTheme.labelLarge),
          const SizedBox(height: 8),
          RpeSelector(
            value: rpe,
            onChanged: busy ? (_) {} : onRpeChanged,
            lowAnchorLabel: l10n.postWorkoutFeedbackAnchorEasy,
            highAnchorLabel: l10n.postWorkoutFeedbackAnchorMax,
          ),
          const SizedBox(height: 16),
          TextField(
            controller: noteController,
            focusNode: noteFocusNode,
            enabled: !busy,
            minLines: 1,
            maxLines: 3,
            decoration: InputDecoration(
              hintText: l10n.postWorkoutFeedbackNoteHint,
              border: const OutlineInputBorder(),
            ),
          ),
        ],
      ),
    );
  }
}

/// One row of the C4a.6 split list — "1 km · 5:12 /km · +12 m". Read-only,
/// plain text, same visual weight as `_MetricTile` but a full-width row
/// (a `Wrap` of many small tiles would be far less scannable than a list for
/// something inherently sequential like splits).
class _SplitRow extends StatelessWidget {
  const _SplitRow({
    required this.split,
    required this.unitSystem,
    required this.theme,
    required this.scheme,
    required this.accent,
    required this.slowestSeconds,
    required this.fastestSeconds,
  });

  final CardioSplit split;
  final UnitSystem unitSystem;
  final ThemeData theme;
  final ColorScheme scheme;
  final Color accent;

  /// The full splits' extremes, used to scale the bar and its color.
  final int slowestSeconds;
  final int fastestSeconds;

  @override
  Widget build(BuildContext context) {
    final duration = Duration(seconds: split.durationSeconds);
    // "Az utolsó split részleges, ezért nem tempót mutat, hanem a megtett
    // távot — így nem tűnik hirtelen belassulásnak" (M14).
    final partial = split.distanceMeters < 999;

    // Faster split = longer, lighter bar. One hue, two lightness steps —
    // never a second color family (M13's note).
    final span = (slowestSeconds - fastestSeconds).clamp(1, 1 << 30);
    final speed = partial ? 0.0 : ((slowestSeconds - split.durationSeconds) / span).clamp(0.0, 1.0);
    final barColor = partial
        ? scheme.outlineVariant
        : Color.lerp(accent.withValues(alpha: 0.55), accent, speed)!;
    final fraction = partial ? (split.distanceMeters / 1000).clamp(0.1, 1.0) : 0.55 + 0.45 * speed;

    return Padding(
      padding: const EdgeInsets.only(bottom: 9),
      child: Row(
        children: [
          SizedBox(
            width: 16,
            child: Text(
              '${split.splitIndex + 1}',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: partial ? scheme.outline : scheme.onSurfaceVariant,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: Container(
                height: 12,
                color: scheme.surfaceContainer,
                child: FractionallySizedBox(
                  alignment: Alignment.centerLeft,
                  widthFactor: fraction,
                  child: Container(color: barColor),
                ),
              ),
            ),
          ),
          const SizedBox(width: 11),
          Text(
            // A full km split's duration *is* its pace, so one number does
            // both jobs; a partial split shows how far it actually got.
            partial
                ? CardioFormatter.distance(split.distanceMeters, unitSystem)
                : CardioFormatter.duration(duration),
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w800,
              color: partial ? scheme.outline : scheme.onSurface,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }
}
