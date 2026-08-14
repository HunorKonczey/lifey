import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final unitSystem =
        (ref.watch(settingsControllerProvider).value ?? const UserSettings.defaults())
            .unitSystem;

    return Scaffold(
      appBar: AppBar(title: Text(activityTypeLabel(l10n, _activityType))),
      body: ListView(
        padding: EdgeInsets.fromLTRB(16, 12, 16, MediaQuery.paddingOf(context).bottom + 24),
        children: [
          Row(
            children: [
              ActivityChip(activityType: _activityType, size: 52),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      activityTypeLabel(l10n, _activityType),
                      style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
                    ),
                    Text(
                      _dateLabel.format(_startedAt.toLocal()),
                      style: theme.textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (widget.newRecords.isNotEmpty) ...[
            const SizedBox(height: 14),
            _NewRecordBanner(types: widget.newRecords, l10n: l10n, theme: theme, scheme: scheme),
          ],
          const SizedBox(height: 20),
          ..._metricSections(l10n, theme, scheme, unitSystem),
          const SizedBox(height: 10),
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
    );
  }

  List<Widget> _metricSections(
    AppLocalizations l10n,
    ThemeData theme,
    ColorScheme scheme,
    UnitSystem unitSystem,
  ) {
    final durationValue = _duration == null ? '—' : CardioFormatter.duration(_duration);
    final hasDistance = (_distanceMeters ?? 0) > 0;

    switch (_family) {
      case ActivityFamily.distance:
        final primaryLabel = hasDistance ? l10n.distanceFieldLabel : l10n.durationSectionLabel;
        final primaryValue =
            hasDistance ? CardioFormatter.distance(_distanceMeters!, unitSystem) : durationValue;
        final secondary = <Widget>[];
        if (hasDistance && _duration != null) {
          secondary.add(_MetricTile(label: l10n.durationSectionLabel, value: durationValue));
          final pace = CardioFormatter.pace(_distanceMeters!, _duration, unitSystem);
          if (pace != null) secondary.add(_MetricTile(label: l10n.paceLabel, value: pace));
        }
        if (_elevationGainMeters != null) {
          secondary.add(_MetricTile(
            label: l10n.elevationGainFieldLabel,
            value: CardioFormatter.elevation(_elevationGainMeters!, unitSystem),
          ));
        }
        return [
          _PrimaryMetricCard(
            label: primaryLabel,
            value: primaryValue,
            edited: hasDistance && _distanceSource == 'MANUAL',
            editedLabel: l10n.manuallyEditedBadgeLabel,
            scheme: scheme,
            theme: theme,
            onTap: _busy ? null : _editDistance,
          ),
          if (secondary.isNotEmpty) ...[
            const SizedBox(height: 10),
            Wrap(spacing: 10, runSpacing: 10, children: secondary),
          ],
          ..._routeSections(l10n, theme, scheme, unitSystem),
        ];
      case ActivityFamily.machine:
        final secondary = <Widget>[
          _MetricTile(
            label: l10n.distanceFieldLabel,
            value: hasDistance ? CardioFormatter.distance(_distanceMeters!, unitSystem) : '—',
            edited: _distanceSource == 'MANUAL',
            editedLabel: l10n.manuallyEditedBadgeLabel,
            onTap: _busy ? null : _editDistance,
          ),
          if (_avgWatts != null)
            _MetricTile(label: l10n.avgWattsFieldLabel, value: '${_avgWatts!.round()} W'),
          if (_avgCadence != null)
            _MetricTile(label: l10n.avgCadenceFieldLabel, value: '${_avgCadence!.round()} rpm'),
          if (_resistanceLevel != null)
            _MetricTile(label: l10n.resistanceLevelFieldLabel, value: '$_resistanceLevel'),
          _MetricTile(
            label: l10n.deviceCaloriesFieldLabel,
            value: _deviceCalories == null ? '—' : '${_deviceCalories!.round()} kcal',
            edited: _caloriesSource == 'MANUAL',
            editedLabel: l10n.manuallyEditedBadgeLabel,
            onTap: _busy ? null : _editDeviceCalories,
          ),
        ];
        return [
          _PrimaryMetricCard(
            label: l10n.movingTimeLabel,
            value: durationValue,
            scheme: scheme,
            theme: theme,
          ),
          const SizedBox(height: 10),
          Wrap(spacing: 10, runSpacing: 10, children: secondary),
        ];
      case ActivityFamily.game:
        final secondary = <Widget>[
          if (_venue != null)
            _MetricTile(
              label: l10n.venueSectionLabel,
              value: _venue == 'INDOOR' ? l10n.venueIndoorLabel : l10n.venueOutdoorLabel,
            ),
          if (_intensity != null) _MetricTile(label: l10n.intensitySectionLabel, value: '$_intensity/5'),
          if (_scorePoints != null)
            _MetricTile(label: l10n.scorePointsFieldLabel, value: '$_scorePoints'),
        ];
        return [
          _PrimaryMetricCard(
            label: l10n.playingTimeLabel,
            value: durationValue,
            scheme: scheme,
            theme: theme,
          ),
          if (secondary.isNotEmpty) ...[
            const SizedBox(height: 10),
            Wrap(spacing: 10, runSpacing: 10, children: secondary),
          ],
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
    if (polyline == null || polyline.isEmpty) return const [];

    final sections = <Widget>[
      const SizedBox(height: 16),
      RoutePainter(polyline: polyline),
    ];

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
          const SizedBox(height: 20),
          Text(
            l10n.elevationProfileSectionLabel,
            style: theme.textTheme.labelSmall
                ?.copyWith(color: scheme.onSurfaceVariant, letterSpacing: 1.2, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          TimeSeriesChart(
            points: elevationPoints,
            dateLabelBuilder: (_) => '',
            valueLabelBuilder: (v) => CardioFormatter.elevation(v, unitSystem),
            height: 140,
          ),
        ]);
      }
    }

    final splits = widget.session.splits;
    if (splits.isNotEmpty) {
      sections.addAll([
        const SizedBox(height: 20),
        Text(
          l10n.splitsSectionLabel,
          style: theme.textTheme.labelSmall
              ?.copyWith(color: scheme.onSurfaceVariant, letterSpacing: 1.2, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        ...splits.map((s) => _SplitRow(split: s, unitSystem: unitSystem, theme: theme, scheme: scheme)),
      ]);
    }

    return sections;
  }
}

class _PrimaryMetricCard extends StatelessWidget {
  const _PrimaryMetricCard({
    required this.label,
    required this.value,
    required this.scheme,
    required this.theme,
    this.edited = false,
    this.editedLabel,
    this.onTap,
  });

  final String label;
  final String value;
  final ColorScheme scheme;
  final ThemeData theme;
  final bool edited;
  final String? editedLabel;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: scheme.surfaceContainerLow,
      borderRadius: BorderRadius.circular(AppRadius.card),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      label,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                        letterSpacing: 1.2,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  if (edited) _EditedBadge(label: editedLabel!, scheme: scheme),
                ],
              ),
              const SizedBox(height: 4),
              Text(value, style: theme.textTheme.displaySmall?.copyWith(fontWeight: FontWeight.w800)),
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
    this.edited = false,
    this.editedLabel,
    this.onTap,
  });

  final String label;
  final String value;
  final bool edited;
  final String? editedLabel;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Material(
      color: scheme.surfaceContainerLow,
      borderRadius: BorderRadius.circular(AppRadius.input),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minWidth: 100),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(value, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
              Text(label, style: theme.textTheme.labelSmall?.copyWith(color: scheme.onSurfaceVariant)),
              if (edited) ...[
                const SizedBox(height: 4),
                _EditedBadge(label: editedLabel!, scheme: scheme),
              ],
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
      decoration: BoxDecoration(color: accent.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(8)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.edit, size: 12, color: accent),
          const SizedBox(width: 4),
          Text(label, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: accent)),
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
  });

  final CardioSplit split;
  final UnitSystem unitSystem;
  final ThemeData theme;
  final ColorScheme scheme;

  @override
  Widget build(BuildContext context) {
    final duration = Duration(seconds: split.durationSeconds);
    final pace = CardioFormatter.pace(split.distanceMeters, duration, unitSystem);
    final elevationDelta = split.elevationDeltaM;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          SizedBox(
            width: 28,
            child: Text(
              '${split.splitIndex + 1}',
              style: theme.textTheme.labelLarge?.copyWith(color: scheme.onSurfaceVariant),
            ),
          ),
          Expanded(
            child: Text(CardioFormatter.distance(split.distanceMeters, unitSystem)),
          ),
          Expanded(
            child: Text(pace ?? '—', textAlign: TextAlign.center),
          ),
          SizedBox(
            width: 64,
            child: Text(
              elevationDelta == null
                  ? '—'
                  : '${elevationDelta >= 0 ? '+' : '−'}${CardioFormatter.elevation(elevationDelta.abs(), unitSystem)}',
              textAlign: TextAlign.end,
              style: theme.textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
            ),
          ),
        ],
      ),
    );
  }
}
