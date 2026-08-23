import 'dart:async';
import 'dart:math' as math;

import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/format/cardio_formatter.dart';
import '../../../core/location/location_service.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/widgets/activity_chip.dart';
import '../../../shared/widgets/app_snackbar.dart';
import '../../../shared/widgets/charts/pace_bar_chart.dart';
import '../../../shared/widgets/charts/time_series_chart.dart';
import '../../settings/application/settings_controller.dart';
import '../../settings/domain/user_settings.dart';
import '../application/game_setup_preferences.dart';
import '../application/workout_session_controller.dart';
import '../domain/activity_type.dart';
import '../domain/cardio_personal_record.dart';
import '../domain/hr_zone_breakdown.dart';
import '../domain/route_encoder.dart';
import '../data/cardio_track_point_repository.dart';
import '../domain/cardio_interval_plan.dart';
import '../domain/elevation_profile.dart';
import '../domain/track_filter.dart';
import '../domain/waypoint_track_match.dart';
import '../domain/weather_condition.dart';
import '../domain/workout_session.dart';
import 'widgets/elevation_profile_chart.dart';
import 'widgets/game_setup_sheet.dart';
import 'widgets/hr_zone_panel.dart';
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
  const CardioSummaryScreen({
    super.key,
    required this.session,
    this.newRecords = const [],
    this.previousBests = CardioPrBaseline.empty,
  });

  final WorkoutSession session;

  /// Cardio records [session] just broke, detected by
  /// `CardioSessionScreen._finish()` right before handing off here — always
  /// empty when this screen is reached by reopening an already-finished
  /// session (`open_workout_screens.dart`), since re-viewing a past session
  /// isn't the moment it earned anything. See `cardio_personal_record.dart`.
  final List<CardioPrType> newRecords;

  /// What each record stood at *before* this session, so the celebration can
  /// name what was replaced ("previous: 24:36 · 12 October" — docs/cardio/61
  /// §2 M36). Empty when [newRecords] is, and when reopening a past session.
  final CardioPrBaseline previousBests;

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

  /// M39's "Mind a 10 szakasz" expander state — view-only, never persisted.
  bool _intervalSectionsExpanded = false;
  String? _caloriesSource;

  // Read-only carry-over — no provenance field exists for any of these yet
  // (see the class doc), so they're never edited on this screen, just
  // preserved byte-for-byte across every write this screen makes.
  double? _elevationGainMeters;

  /// The highest point of the local trail, computed once at
  /// `CardioSessionScreenState._finish()` and read-only carry-over here
  /// (docs/cardio/60 C8.5, Q-D6) — same "no edit path, must round-trip
  /// through `_persistCardio` or it's erased" shape as [_elevationGainMeters].
  double? _maxAltitudeMeters;
  double? _avgCadence;
  double? _avgWatts;
  int? _resistanceLevel;
  String? _venue;
  String? _gameFormat;
  int? _intensity;
  int? _scorePoints;
  int? _scoreAssists;
  int? _scoreRebounds;

  // C4a.6 — the closing route, also read-only carry-over here (this screen
  // has no route re-processing UI, only `CardioSessionScreenState._finish()`
  // ever produces these). Must still round-trip through every
  // `_persistCardio` write below — `updateLiveCardioMetrics` replaces the
  // whole `CardioMetrics` row, so omitting these here would silently erase
  // the route the moment someone edits, say, the distance on this screen.
  String? _routePolyline;
  int? _routePointCount;

  /// HIKING-only (docs/cardio/60 C8.5, M42) — the one cardio field that's
  /// only ever hand-entered, so its "edited" badge reads "kézzel" (M42),
  /// not "szerkesztve" the way [_distanceMeters]'s does: there's no measured
  /// baseline it could be overriding.
  double? _backpackWeightKg;

  /// Hike-only weather snapshot (docs/cardio/60 C8.6) — same hand-entered,
  /// no-`*Source`-tag shape as [_backpackWeightKg].
  String? _weatherCondition;
  double? _weatherTempC;
  double? _weatherWindKph;
  double? _weatherPrecipMm;

  // C8.3 — the real, local-track-derived elevation profile. Null until
  // `_loadElevationProfile` resolves, and possibly forever null after that
  // (no local points left, or none ever existed): `_elevationProfileSimplified`
  // is what tells the difference apart from "still loading".
  ElevationProfile? _elevationProfile;
  bool _elevationProfileSimplified = false;

  /// Index into `_elevationProfile!.allPoints` — never persisted, a pure
  // view state, same as `_selectedSplitIndex` right above it.
  int? _selectedElevationPointIndex;

  /// The same filtered local trail [_loadElevationProfile] builds
  /// `_elevationProfile` from — kept around (C8.4) so the waypoint list can
  /// match each `CardioWaypoint` against it (`matchWaypointsToTrail`) without
  /// replaying the track points a second time. Empty, not null, once loading
  /// has resolved with nothing to show (mirrors `_elevationProfileSimplified`'s
  /// "loading vs. genuinely empty" distinction via that same flag).
  List<TrackFilterTrailPoint> _localTrail = const [];

  /// Which split the reader has tapped, if any (C6.4, M33). Lives here rather
  /// than inside either widget because it drives *both* the list row and the
  /// chart bar — that simultaneity is the whole point: nobody has to learn
  /// that the two are connected.
  int? _selectedSplitIndex;

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
    _maxAltitudeMeters = cardio?.maxAltitudeMeters;
    _backpackWeightKg = cardio?.backpackWeightKg;
    _weatherCondition = cardio?.weatherCondition;
    _weatherTempC = cardio?.weatherTempC;
    _weatherWindKph = cardio?.weatherWindKph;
    _weatherPrecipMm = cardio?.weatherPrecipMm;
    _avgCadence = cardio?.avgCadence;
    _avgWatts = cardio?.avgWatts;
    _resistanceLevel = cardio?.resistanceLevel;
    _venue = cardio?.venue;
    _gameFormat = cardio?.gameFormat;
    _intensity = cardio?.intensity;
    _scorePoints = cardio?.scorePoints;
    _scoreAssists = cardio?.scoreAssists;
    _scoreRebounds = cardio?.scoreRebounds;
    _routePolyline = cardio?.routePolyline;
    _routePointCount = cardio?.routePointCount;

    _rpe = s.rpe;
    _noteController = TextEditingController(text: s.feedbackNote ?? '');
    _noteFocusNode = FocusNode()..addListener(_onNoteFocusChange);

    // One celebration for the whole session, however many records it broke
    // (M36) — scheduled once, from initState, so reopening a past session
    // (which arrives with no records) never triggers it.
    if (widget.newRecords.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _celebrateRecords());
    }

    // C8.3: only DISTANCE ever has a route/elevation profile at all
    // (MACHINE/GAME never track location) — same gate `_routeSections` uses.
    if (_family == ActivityFamily.distance) {
      unawaited(_loadElevationProfile());
    }
  }

  /// Replays this session's local raw track points (docs/cardio/54 §4.1)
  // through the same filter gates the live screen applies
  // (`CardioSessionScreenState._seedTrackPointSeqAndSync`'s identical
  // pattern) and builds the real profile from the result. Falls back to
  // nothing — the caller keeps rendering the old polyline-based
  // approximation and marks it "EGYSZERŰSÍTETT" — whenever there are no
  // local points left to replay (pruned after 90 days, or this session was
  // never recorded on this device) or the trail carries no altitude at all.
  Future<void> _loadElevationProfile() async {
    final points = await ref.read(cardioTrackPointRepositoryProvider).pointsForSession(_clientId);
    if (!mounted) return;
    if (points.isEmpty) {
      setState(() => _elevationProfileSimplified = true);
      return;
    }

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
    final profile = buildElevationProfile(filter.trail);
    if (!mounted) return;
    setState(() {
      _elevationProfile = profile;
      _elevationProfileSimplified = profile == null;
      _localTrail = filter.trail;
    });
  }

  /// M36: **one** dialog, **one** haptic, **one** list — never one
  /// celebration per record. Four records on a single run is the case this
  /// exists for; four dialogs in a row would turn the best moment of the run
  /// into four taps to dismiss.
  Future<void> _celebrateRecords() async {
    if (!mounted) return;
    final l10n = AppLocalizations.of(context)!;
    final unitSystem = (ref.read(settingsControllerProvider).value ??
            const UserSettings.defaults())
        .unitSystem;
    HapticFeedback.mediumImpact();
    await showDialog<void>(
      context: context,
      builder: (_) => _CardioRecordCelebrationDialog(
        types: widget.newRecords,
        session: widget.session,
        previousBests: widget.previousBests,
        unitSystem: unitSystem,
        label: (type) => _recordLabel(l10n, type),
      ),
    );
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
    int? scorePoints,
    int? scoreAssists,
    int? scoreRebounds,
    String? venue,
    String? gameFormat,
    Value<double?> backpackWeightKg = const Value.absent(),
    Value<String?> weatherCondition = const Value.absent(),
    Value<double?> weatherTempC = const Value.absent(),
    Value<double?> weatherWindKph = const Value.absent(),
    Value<double?> weatherPrecipMm = const Value.absent(),
  }) async {
    final l10n = AppLocalizations.of(context)!;
    final newDistance = distanceMeters ?? _distanceMeters;
    final newDistanceSource = distanceSource ?? _distanceSource;
    final newCalories = deviceCalories ?? _deviceCalories;
    final newCaloriesSource = caloriesSource ?? _caloriesSource;
    final newPoints = scorePoints ?? _scorePoints;
    final newAssists = scoreAssists ?? _scoreAssists;
    final newRebounds = scoreRebounds ?? _scoreRebounds;
    final newVenue = venue ?? _venue;
    final newFormat = gameFormat ?? _gameFormat;
    // A plain optional param can't tell "unchanged" apart from "clear it" —
    // every other field here happens to never need that distinction, but a
    // backpack weight genuinely can be removed after being set.
    final newBackpackWeightKg =
        backpackWeightKg.present ? backpackWeightKg.value : _backpackWeightKg;
    // The weather sheet always submits all four together (one snapshot, one
    // edit) — same absent-preserving `Value` shape, so a distance/calorie
    // edit elsewhere on this screen can't accidentally wipe it.
    final newWeatherCondition =
        weatherCondition.present ? weatherCondition.value : _weatherCondition;
    final newWeatherTempC = weatherTempC.present ? weatherTempC.value : _weatherTempC;
    final newWeatherWindKph = weatherWindKph.present ? weatherWindKph.value : _weatherWindKph;
    final newWeatherPrecipMm = weatherPrecipMm.present ? weatherPrecipMm.value : _weatherPrecipMm;
    setState(() => _busy = true);
    try {
      await ref.read(workoutSessionControllerProvider.notifier).updateLiveCardioMetrics(
            _clientId,
            startedAt: _startedAt,
            cardio: CardioMetrics(
              distanceMeters: newDistance,
              elevationGainMeters: _elevationGainMeters,
              maxAltitudeMeters: _maxAltitudeMeters,
              backpackWeightKg: newBackpackWeightKg,
              weatherCondition: newWeatherCondition,
              weatherTempC: newWeatherTempC,
              weatherWindKph: newWeatherWindKph,
              weatherPrecipMm: newWeatherPrecipMm,
              avgCadence: _avgCadence,
              avgWatts: _avgWatts,
              resistanceLevel: _resistanceLevel,
              deviceCalories: newCalories,
              venue: newVenue,
              gameFormat: newFormat,
              intensity: _intensity,
              scorePoints: newPoints,
              scoreAssists: newAssists,
              scoreRebounds: newRebounds,
              hrZone1Seconds: widget.session.cardio?.hrZone1Seconds,
              hrZone2Seconds: widget.session.cardio?.hrZone2Seconds,
              hrZone3Seconds: widget.session.cardio?.hrZone3Seconds,
              hrZone4Seconds: widget.session.cardio?.hrZone4Seconds,
              hrZone5Seconds: widget.session.cardio?.hrZone5Seconds,
              best1kSeconds: widget.session.cardio?.best1kSeconds,
              best5kSeconds: widget.session.cardio?.best5kSeconds,
              best10kSeconds: widget.session.cardio?.best10kSeconds,
              maxHeartRate: widget.session.cardio?.maxHeartRate,
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
        _scorePoints = newPoints;
        _scoreAssists = newAssists;
        _scoreRebounds = newRebounds;
        _venue = newVenue;
        _gameFormat = newFormat;
        _backpackWeightKg = newBackpackWeightKg;
        _weatherCondition = newWeatherCondition;
        _weatherTempC = newWeatherTempC;
        _weatherWindKph = newWeatherWindKph;
        _weatherPrecipMm = newWeatherPrecipMm;
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

  /// The box score's edit path on the summary (C9.2, M44's "az összegzésen és
  /// a kézi lapon ... `edit` szerkesztés móddal") — the same tap-the-tile
  /// pattern the distance and device-calorie tiles already use, rather than a
  /// second stepper: after the match the job is correcting a miscount, not
  /// counting live.
  Future<void> _editScore({
    required String title,
    required int? current,
    required Future<void> Function(int value) persist,
  }) async {
    if (_busy) return;
    final l10n = AppLocalizations.of(context)!;
    final result = await promptNumber(
      context,
      l10n,
      title: title,
      suffix: '',
      initialText: current?.toString() ?? '',
    );
    if (result == null || result < 0 || !mounted) return;
    await persist(result.round());
  }

  /// M45's own promise — "a beállítás utólag is módosítható" — made real on
  /// the summary. Both selectors are the *same widgets* the start sheet uses,
  /// so the two surfaces can't drift apart.
  Future<void> _editGameSetup() async {
    if (_busy) return;
    final l10n = AppLocalizations.of(context)!;
    final changed = await showModalBottomSheet<bool>(
      context: context,
      useRootNavigator: true,
      showDragHandle: true,
      builder: (sheetContext) => StatefulBuilder(
        builder: (sheetContext, setSheetState) => Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l10n.gameFormatSectionLabel,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.2,
                  color: Theme.of(sheetContext).colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 8),
              GameFormatSelector(
                value: GameFormat.fromCode(_gameFormat) ?? GameSetup.defaults.format,
                onChanged: (format) {
                  setSheetState(() => _gameFormat = format.code);
                  unawaited(_persistCardio(gameFormat: format.code));
                },
              ),
              const SizedBox(height: 16),
              Text(
                l10n.venueSectionLabel,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.2,
                  color: Theme.of(sheetContext).colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 8),
              GameVenueSelector(
                venue: _venue ?? GameSetup.defaults.venue,
                onChanged: (venue) {
                  setSheetState(() => _venue = venue);
                  unawaited(_persistCardio(venue: venue));
                },
              ),
            ],
          ),
        ),
      ),
    );
    if (changed == true && mounted) setState(() {});
  }

  /// HIKING-only (docs/cardio/60 C8.5, M42) — the only cardio field where the
  /// user *is* the source; there's no "MEASURED" state to compare against, so
  /// unlike [_editDistance] this has no `*Source` tag to set.
  Future<void> _editBackpackWeightKg() async {
    if (_busy) return;
    final l10n = AppLocalizations.of(context)!;
    final unitSystem =
        (ref.read(settingsControllerProvider).value ?? const UserSettings.defaults()).unitSystem;
    final imperial = unitSystem == UnitSystem.imperial;
    const kgPerLb = 0.45359237;
    final current = _backpackWeightKg;
    final result = await promptNumber(
      context,
      l10n,
      title: l10n.editBackpackWeightDialogTitle,
      suffix: imperial ? 'lb' : 'kg',
      initialText: current == null
          ? ''
          : (imperial ? current / kgPerLb : current).toStringAsFixed(1),
    );
    if (result == null || result < 0 || !mounted) return;
    await _persistCardio(backpackWeightKg: Value(imperial ? result * kgPerLb : result));
  }

  /// HIKING-only (docs/cardio/60 C8.6, Q-C8.1: manual entry, no external
  /// API) — the four fields are one snapshot, so they're edited and
  /// persisted together in a single sheet + [_persistCardio] call, unlike
  /// [_editBackpackWeightKg]'s single-field [promptNumber] dialog.
  /// `TextFormField`s with plain local variables, not owned controllers —
  /// same reasoning as [promptNumber]'s own doc comment.
  Future<void> _editWeather() async {
    if (_busy) return;
    final l10n = AppLocalizations.of(context)!;
    final unitSystem =
        (ref.read(settingsControllerProvider).value ?? const UserSettings.defaults()).unitSystem;
    final imperial = unitSystem == UnitSystem.imperial;
    const kphPerMph = 1.609344;
    const mmPerInch = 25.4;

    String? condition = _weatherCondition;
    var tempText = _weatherTempC == null
        ? ''
        : (imperial ? (_weatherTempC! * 9 / 5 + 32) : _weatherTempC!).round().toString();
    var windText = _weatherWindKph == null
        ? ''
        : (imperial ? _weatherWindKph! / kphPerMph : _weatherWindKph!).round().toString();
    var precipText = _weatherPrecipMm == null
        ? ''
        : (imperial ? _weatherPrecipMm! / mmPerInch : _weatherPrecipMm!)
            .toStringAsFixed(imperial ? 2 : 0);

    final saved = await showModalBottomSheet<bool>(
      context: context,
      useRootNavigator: true,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (sheetContext) => StatefulBuilder(
        builder: (sheetContext, setSheetState) => Padding(
          padding: EdgeInsets.fromLTRB(
              20, 4, 20, 28 + MediaQuery.of(sheetContext).viewInsets.bottom),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(l10n.editWeatherDialogTitle,
                    style: Theme.of(sheetContext).textTheme.titleLarge),
                const SizedBox(height: 16),
                Text(l10n.weatherConditionSectionLabel,
                    style: Theme.of(sheetContext).textTheme.labelLarge),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final code in kWeatherConditions)
                      ChoiceChip(
                        label: Text(weatherConditionLabel(l10n, code)),
                        avatar: Icon(weatherConditionIcon(code), size: 18),
                        selected: condition == code,
                        onSelected: (_) =>
                            setSheetState(() => condition = condition == code ? null : code),
                      ),
                  ],
                ),
                const SizedBox(height: 16),
                TextFormField(
                  initialValue: tempText,
                  keyboardType: const TextInputType.numberWithOptions(signed: true),
                  inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[-\d.,]'))],
                  onChanged: (v) => tempText = v,
                  decoration: InputDecoration(
                    labelText: l10n.weatherTemperatureFieldLabel,
                    suffixText: imperial ? '°F' : '°C',
                    isDense: true,
                    border: const OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 10),
                TextFormField(
                  initialValue: windText,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  onChanged: (v) => windText = v,
                  decoration: InputDecoration(
                    labelText: l10n.weatherWindFieldLabel,
                    suffixText: imperial ? 'mph' : 'km/h',
                    isDense: true,
                    border: const OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 10),
                TextFormField(
                  initialValue: precipText,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[\d.,]'))],
                  onChanged: (v) => precipText = v,
                  decoration: InputDecoration(
                    labelText: l10n.weatherPrecipFieldLabel,
                    suffixText: imperial ? 'in' : 'mm',
                    isDense: true,
                    border: const OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 20),
                FilledButton(
                  onPressed: () => Navigator.of(sheetContext).pop(true),
                  child: Text(l10n.saveButton),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    if (saved != true || !mounted) return;

    double? parse(String text) => double.tryParse(text.replaceAll(',', '.').trim());
    final tempInput = parse(tempText);
    final weatherTempC = tempInput == null ? null : (imperial ? (tempInput - 32) * 5 / 9 : tempInput);
    final windInput = parse(windText);
    final weatherWindKph = windInput == null ? null : (imperial ? windInput * kphPerMph : windInput);
    final precipInput = parse(precipText);
    final weatherPrecipMm =
        precipInput == null ? null : (imperial ? precipInput * mmPerInch : precipInput);

    await _persistCardio(
      weatherCondition: Value(condition),
      weatherTempC: Value(weatherTempC),
      weatherWindKph: Value(weatherWindKph),
      weatherPrecipMm: Value(weatherPrecipMm),
    );
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

  /// The header back arrow's handler — reached whether this screen just
  /// replaced a live [CardioSessionScreen] (`_finish()` pushed it via
  /// `pushReplacement` onto an imperative `Navigator`, layered on top of the
  /// go_router shell — its own `context.go('/workouts')` call primes the
  /// Sessions tab *behind* this screen, but leaves this screen itself on top
  /// until it's dismissed) or a reopened already-finished session
  /// (`open_workout_screens.dart`). No separate "Done" button any more — the
  /// back arrow is the only way out, and it always lands on the completed
  /// Sessions list rather than wherever it's popped to.
  ///
  /// Both steps below are needed, and `go()` alone was the bug: this screen is
  /// a **pageless** route — pushed straight onto the root `Navigator`, not
  /// through go_router — so it sits *above* go_router's own page stack.
  /// Changing the location rebuilds those pages, but the shell page directly
  /// underneath this route stays exactly where it is, so nothing ever pops
  /// this screen. After `_finish()` the location is already `/workouts` on top
  /// of that, making the call a plain no-op: tapping back did nothing at all.
  /// So `go()` for the destination *behind* us, and a pop to actually leave.
  void _done() {
    ref.read(workoutsSessionsTabRequestProvider.notifier).request();
    // Captured before `go()`: this widget stays mounted through it (exactly
    // the point above), but reading the navigator first keeps the two steps
    // independent of that.
    final navigator = Navigator.of(context);
    if (GoRouter.maybeOf(context) != null) {
      context.go('/workouts');
    }
    // False only in a test/host harness that pumped this screen as `home` —
    // there `go()` (or nothing) is all there is to do.
    if (navigator.canPop()) navigator.pop();
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
                onBack: _done,
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
                        child: RoutePainter(
                          polyline: polyline,
                          height: 262,
                          waypoints: _activityType == 'HIKING' ? widget.session.waypoints : const [],
                        ),
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
              // Q-D6: the peak marker+caption already lives inside the
              // elevation profile chart (C8.3) — this is the number's *other*
              // home, the one that survives the degraded (no local track)
              // view where the chart itself falls back to the old
              // approximation and has no peak to mark.
              if (_maxAltitudeMeters != null)
                _MetricTile(
                  icon: Icons.landscape,
                  iconColor: metrics?.weight,
                  label: l10n.maxAltitudeFieldLabel,
                  value: CardioFormatter.elevation(_maxAltitudeMeters!, unitSystem),
                ),
              // M42: backpack weight is hike-only, and the only field the
              // user is the sole source for — always tappable, even before
              // anything's been entered (M11's "koppints" affordance, same
              // shape as the distance tile above it).
              if (_activityType == 'HIKING')
                _MetricTile(
                  icon: Icons.backpack,
                  iconColor: accent,
                  label: l10n.backpackWeightFieldLabel,
                  value: _backpackWeightKg == null
                      ? '—'
                      : CardioFormatter.weight(_backpackWeightKg!, unitSystem),
                  edited: _backpackWeightKg != null,
                  editedLabel: l10n.handEnteredBadgeLabel,
                  onTap: _busy ? null : _editBackpackWeightKg,
                ),
              // Cadence is running's metric only (C6.5): a walk or a hike
              // never shows it, even when a watch happened to measure steps —
              // the tile appears solely when a sensor genuinely reported it
              // for a run. Steps per minute here, not the indoor bike's rpm
              // (the MACHINE branch below keeps that one).
              if (_activityType == 'RUNNING' && _avgCadence != null)
                _MetricTile(
                  icon: Icons.directions_run,
                  iconColor: accent,
                  label: l10n.avgCadenceFieldLabel,
                  value: '${_avgCadence!.round()} spm',
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
          ..._bestEffortSection(l10n, theme, unitSystem),
          ..._weatherSection(l10n, unitSystem),
          ..._routeSections(l10n, theme, scheme, unitSystem),
          // Q-D7: one component for every cardio type, placed per family —
          // after the splits for DISTANCE, so the pace story finishes before
          // the physiological one starts.
          ..._hrZoneSection(l10n),
        ];
      // M39: with power, total work is the hero and moving time joins the
      // grid; without it, M15's moving-time card keeps the top slot (the
      // frame's own "watt-adat nélkül" state — a 0 kJ would read as a
      // measured zero rather than as "this machine doesn't report watts").
      case ActivityFamily.machine:
        final totalWorkKj = CardioFormatter.totalWorkKj(_avgWatts, widget.session.movingSeconds);
        return [
          if (totalWorkKj != null)
            _TotalWorkCard(
              totalWorkKj: totalWorkKj,
              avgWatts: _avgWatts!,
              maxWatts: widget.session.cardio?.maxWatts,
              accent: metrics?.calories ?? accent,
            )
          else
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
              ],
            ),
          const SizedBox(height: 12),
          _MetricGrid(
            children: [
              // Moving time is only a grid cell when the work card took the
              // top slot — it never disappears, it just stops being the hero.
              if (totalWorkKj != null)
                _MetricTile(
                  icon: Icons.schedule,
                  iconColor: metrics?.protein,
                  label: l10n.movingTimeLabel,
                  value: durationValue,
                ),
              if (totalWorkKj != null && hasDistance)
                _MetricTile(
                  icon: Icons.straighten,
                  iconColor: accent,
                  label: l10n.distanceFieldLabel,
                  value: CardioFormatter.distance(_distanceMeters!, unitSystem),
                  edited: _distanceSource == 'MANUAL',
                  editedLabel: l10n.manuallyEditedBadgeLabel,
                  onTap: _busy ? null : _editDistance,
                ),
              if (totalWorkKj != null && _avgCadence != null)
                _MetricTile(
                  icon: Icons.autorenew,
                  iconColor: metrics?.protein,
                  label: l10n.avgCadenceFieldLabel,
                  value: '${_avgCadence!.round()} rpm',
                ),
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
            ],
          ),
          ..._intervalSectionsSection(l10n, theme, scheme),
          const SizedBox(height: 12),
          // M39's key card: one card, two sides, a line between them. Two
          // separate cards tested worse — they read as two equal numbers, and
          // the suspicion that they get added up survived.
          _CalorieCard(
            activeCalories: activeCalories,
            machineCalories: _deviceCalories,
            machineEdited: _caloriesSource == 'MANUAL',
            onEditMachine: _busy ? null : _editDeviceCalories,
            l10n: l10n,
            accent: metrics?.calories ?? accent,
          ),
          const SizedBox(height: 12),
          // "Az »útvonal nélkül« nem üres hely, hanem kimondott állapot" —
          // for an indoor session this is the normal case, so it reads as an
          // explanation in a neutral tone, never as an error.
          _NoRouteCard(title: l10n.noRouteCardTitle, body: l10n.noRouteCardBody),
          ..._hrZoneSection(l10n),
        ];
      case ActivityFamily.game:
        return [
          _PrimaryMetricCard(
            label: l10n.playingTimeLabel,
            value: durationValue,
            scheme: scheme,
            theme: theme,
          ),
          // GAME puts the zones straight after the dominant number (Q-D7):
          // on a match the zone spread *is* the story, so it outranks the
          // venue/intensity/score grid below it.
          ..._hrZoneSection(l10n),
          const SizedBox(height: 12),
          _MetricGrid(
            children: [
              if (_venue != null)
                _MetricTile(
                  icon: _venue == 'INDOOR' ? Icons.home_work : Icons.park,
                  iconColor: accent,
                  label: l10n.venueSectionLabel,
                  value: _venue == 'INDOOR' ? l10n.venueIndoorLabel : l10n.venueOutdoorLabel,
                  onTap: _busy ? null : _editGameSetup,
                ),
              if (_gameFormat != null)
                _MetricTile(
                  icon: Icons.grid_view,
                  iconColor: accent,
                  label: l10n.gameFormatSectionLabel,
                  value: gameFormatLabel(
                    l10n,
                    GameFormat.fromCode(_gameFormat) ?? GameSetup.defaults.format,
                  ),
                  onTap: _busy ? null : _editGameSetup,
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
              // Editable since C9.2: a live stepper collects miscounts, so the
              // summary has to be able to fix them. A never-counted stat stays
              // absent rather than showing a zero nobody entered.
              // C9.4 — an outdoor match that recorded GPS shows its distance.
              // An indoor one has none: not a dash, not a zero, no tile at
              // all ("nem letiltva, hanem nem létezik"). **No pace tile ever**
              // for a match — the setup sheet's promise says why, and adding
              // one here would contradict it (docs/cardio/51 §3.4).
              if (hasDistance)
                _MetricTile(
                  icon: Icons.straighten,
                  iconColor: accent,
                  label: l10n.distanceFieldLabel,
                  value: CardioFormatter.distance(_distanceMeters!, unitSystem),
                ),
              if (_scorePoints != null)
                _MetricTile(
                  icon: Icons.scoreboard,
                  iconColor: accent,
                  label: _activityType == 'BASKETBALL'
                      ? l10n.boxScorePointsLabel
                      : l10n.boxScoreGoalsLabel,
                  value: '$_scorePoints',
                  onTap: _busy
                      ? null
                      : () => _editScore(
                            title: l10n.boxScorePointsLabel,
                            current: _scorePoints,
                            persist: (v) => _persistCardio(scorePoints: v),
                          ),
                ),
              if (_scoreRebounds != null)
                _MetricTile(
                  icon: Icons.replay,
                  iconColor: accent,
                  label: l10n.boxScoreReboundsLabel,
                  value: '$_scoreRebounds',
                  onTap: _busy
                      ? null
                      : () => _editScore(
                            title: l10n.boxScoreReboundsLabel,
                            current: _scoreRebounds,
                            persist: (v) => _persistCardio(scoreRebounds: v),
                          ),
                ),
              if (_scoreAssists != null)
                _MetricTile(
                  icon: Icons.handshake,
                  iconColor: accent,
                  label: l10n.boxScoreAssistsLabel,
                  value: '$_scoreAssists',
                  onTap: _busy
                      ? null
                      : () => _editScore(
                            title: l10n.boxScoreAssistsLabel,
                            current: _scoreAssists,
                            persist: (v) => _persistCardio(scoreAssists: v),
                          ),
                ),
            ],
          ),
        ];
    }
  }

  /// M43's zone panel, wrapped in the same section card every other block on
  /// this screen uses (C9.1). **Absent entirely when the session carries no
  /// zone data** — the common case, and an empty five-row panel would be a
  /// worse answer than no panel: nothing here is ever estimated.
  /// M39's executed-sections card. Only ever built for a ride that actually
  /// played a plan — a plain ride has no INTERVAL splits and shows no list,
  /// which is the frame's own "terv nélkül" state.
  ///
  /// The header chip counts sections rather than naming the plan's shape
  /// ("4×(4+3)"): nothing links a session to a plan (docs/cardio/60 D-C7.1),
  /// and reconstructing the shape from what was ridden would be a guess that
  /// a single skipped section turns into a lie.
  List<Widget> _intervalSectionsSection(
    AppLocalizations l10n,
    ThemeData theme,
    ColorScheme scheme,
  ) {
    final sections = widget.session.splits
        .where((s) => s.splitType == CardioSplitType.interval)
        .toList();
    if (sections.isEmpty) return const [];

    final accent = activityTypeColor(_activityType, context);
    // Long plans collapse: the first six rows carry the shape, and the rest
    // are one tap away rather than a screenful of scrolling.
    const collapsedCount = 6;
    final showAll = _intervalSectionsExpanded || sections.length <= collapsedCount;
    final visible = showAll ? sections : sections.take(collapsedCount).toList();

    return [
      const SizedBox(height: 12),
      _SectionCard(
        label: l10n.intervalSectionsSectionLabel,
        trailingWidget: _IntervalCountChip(
          label: l10n.intervalSectionsCountChip(sections.length),
          accent: accent,
        ),
        child: Column(
          children: [
            for (var i = 0; i < visible.length; i++)
              _IntervalSectionRow(
                number: i + 1,
                split: visible[i],
                accent: accent,
                l10n: l10n,
              ),
            if (!showAll)
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: () => setState(() => _intervalSectionsExpanded = true),
                  icon: const Icon(Icons.expand_more, size: 18),
                  label: Text(l10n.intervalSectionsShowAll(sections.length)),
                ),
              ),
          ],
        ),
      ),
    ];
  }

  List<Widget> _hrZoneSection(AppLocalizations l10n) {
    final breakdown = HrZoneBreakdown.fromSession(widget.session);
    if (breakdown == null) return const [];
    return [
      const SizedBox(height: 12),
      Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(16, 15, 16, 15),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(22),
        ),
        child: HrZonePanel(breakdown: breakdown),
      ),
    ];
  }

  /// M34's "BEST EFFORTS" card, under the metric grid (C6.7). One row per
  /// sub-distance the run actually contains.
  ///
  /// A distance the run never reached **does not appear at all** — not greyed,
  /// not "not enough distance": on a 4 km run the 10 km best effort isn't
  /// missing data, it's not a concept (M34). That falls out of the values
  /// being null, which is exactly why C6.2 stores null there and never 0.
  List<Widget> _bestEffortSection(
    AppLocalizations l10n,
    ThemeData theme,
    UnitSystem unitSystem,
  ) {
    final cardio = widget.session.cardio;
    if (cardio == null) return const [];
    final rows = <_BestEffortRow>[
      for (final (type, seconds, meters) in [
        (CardioPrType.fastest1k, cardio.best1kSeconds, 1000.0),
        (CardioPrType.fastest5k, cardio.best5kSeconds, 5000.0),
        (CardioPrType.fastest10k, cardio.best10kSeconds, 10000.0),
      ])
        if (seconds != null)
          _BestEffortRow(
            label: _recordLabel(l10n, type),
            duration: Duration(seconds: seconds),
            // Only this is comparable across the three rows — a longer
            // distance always takes more absolute time (M34).
            pace: CardioFormatter.pace(meters, Duration(seconds: seconds), unitSystem),
            isRecord: widget.newRecords.contains(type),
          ),
    ];
    if (rows.isEmpty) return const [];

    return [
      const SizedBox(height: 12),
      _SectionCard(
        label: l10n.bestEffortsSectionLabel,
        child: Column(
          children: [
            for (final row in rows)
              _BestEffortTile(
                row: row,
                subtitle: l10n.bestEffortOnRouteSubtitle,
                recordBadge: l10n.cardioRecordBadge,
                theme: theme,
              ),
          ],
        ),
      ),
    ];
  }

  String _recordLabel(AppLocalizations l10n, CardioPrType type) => switch (type) {
        CardioPrType.longestDistance => l10n.cardioRecordLongestDistance,
        CardioPrType.longestMovingTime => l10n.cardioRecordLongestMovingTime,
        CardioPrType.greatestElevationGain => l10n.cardioRecordGreatestElevationGain,
        CardioPrType.fastest1k => l10n.cardioRecordFastest1k,
        CardioPrType.fastest5k => l10n.cardioRecordFastest5k,
        CardioPrType.fastest10k => l10n.cardioRecordFastest10k,
        CardioPrType.greatestTotalWork => l10n.cardioRecordGreatestTotalWork,
        CardioPrType.greatestMaxAltitude => l10n.cardioRecordGreatestMaxAltitude,
      };

  /// M42's "IDŐJÁRÁS INDULÁSKOR" card (docs/cardio/60 C8.6) — HIKING only.
  /// Shown whenever any of the four fields is set (a partial snapshot is
  /// still a snapshot, missing sub-values read "—"); otherwise a compact,
  /// still-tappable "no weather data" row takes its place — unlike the M42
  /// mockup's static version, tappable here so a session missing weather can
  /// still get it added afterward, the same "add it later" affordance every
  /// other hand-entered field on this screen already has.
  List<Widget> _weatherSection(AppLocalizations l10n, UnitSystem unitSystem) {
    if (_activityType != 'HIKING') return const [];
    final hasData = _weatherCondition != null ||
        _weatherTempC != null ||
        _weatherWindKph != null ||
        _weatherPrecipMm != null;
    return [
      const SizedBox(height: 12),
      if (hasData)
        _WeatherCard(
          condition: _weatherCondition,
          tempC: _weatherTempC,
          windKph: _weatherWindKph,
          precipMm: _weatherPrecipMm,
          unitSystem: unitSystem,
          snapshotTime: _startedAt,
          l10n: l10n,
          onTap: _busy ? null : _editWeather,
        )
      else
        _WeatherEmptyRow(message: l10n.weatherNoDataMessage, onTap: _busy ? null : _editWeather),
    ];
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
      final profile = _elevationProfile;
      if (profile != null) {
        // C8.3: the real profile, built from this device's local track —
        // cumulative distance on the X axis, actual signal gaps as shaded
        // bands, a peak marker, and a tap-to-select point (M40).
        sections.addAll([
          const SizedBox(height: 12),
          _ElevationProfileCard(
            profile: profile,
            selectedIndex: _selectedElevationPointIndex,
            elevationGainMeters: _elevationGainMeters!,
            unitSystem: unitSystem,
            l10n: l10n,
            onPointTap: (i) => setState(
              () => _selectedElevationPointIndex =
                  _selectedElevationPointIndex == i ? null : i,
            ),
          ),
        ]);
      } else {
        // The C4a.6-era approximation: the stored (simplified, lossy)
        // polyline's own altitude channel, plotted against a synthetic
        // per-second index rather than real distance — kept only as the
        // fallback for a session whose local track points are gone
        // (docs/cardio/60 C8.3's own "törölt pontok" case), flagged as such
        // once `_loadElevationProfile` has actually confirmed there's
        // nothing better to show.
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
            _SectionCard(
              label: l10n.elevationProfileSectionLabel,
              trailingWidget: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_elevationProfileSimplified) ...[
                    _SimplifiedBadge(label: l10n.elevationProfileSimplifiedBadge),
                    const SizedBox(width: 6),
                  ],
                  Text(
                    '+${CardioFormatter.elevation(_elevationGainMeters!, unitSystem)}',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ],
              ),
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
    }

    // M42's ÚTPONTOK list — HIKING only. Each row's distance/altitude/elapsed
    // is derived by matching the waypoint against the same local track the
    // elevation profile reads from (docs/cardio/60 C8.4) — a waypoint stores
    // only where it was marked, never those three numbers.
    final waypoints = widget.session.waypoints;
    if (_activityType == 'HIKING' && waypoints.isNotEmpty) {
      final matched = matchWaypointsToTrail(waypoints, _localTrail);
      final accent = activityTypeColor(_activityType, context);
      sections.addAll([
        const SizedBox(height: 12),
        _SectionCard(
          label: l10n.waypointsSectionLabel,
          trailingWidget: _IntervalCountChip(
            label: l10n.waypointsCountChip(matched.length),
            accent: accent,
          ),
          child: Column(
            children: [
              for (final m in matched) _WaypointRow(matched: m, unitSystem: unitSystem),
            ],
          ),
        ),
      ]);
    }

    // Per-km splits only: an executed interval section is stored in the same
    // list (docs/cardio/60 D-C7.1) but has no distance and no pace, so it
    // belongs in its own card (M39, C7.6) rather than in a km chart it would
    // read as a 0-length kilometre in. A DISTANCE split always carries a
    // distance — hence the `?? 0` fallbacks below being unreachable in
    // practice, and harmless (a 0 reads as a partial split) if they aren't.
    final splits = widget.session.splits
        .where((s) => s.splitType == CardioSplitType.distance)
        .toList();
    if (splits.isNotEmpty) {
      // M14's split bars are scaled against the slowest full split, so the
      // fastest km fills the track and the rest are read against it.
      final fullSplits = splits.where((s) => (s.distanceMeters ?? 0) >= 999).toList();
      final slowest =
          fullSplits.isEmpty ? 1 : fullSplits.map((s) => s.durationSeconds).reduce(math.max);
      final fastest =
          fullSplits.isEmpty ? 1 : fullSplits.map((s) => s.durationSeconds).reduce(math.min);
      final accent = activityTypeColor(_activityType, context);
      // The chart and the list are fed from this one list — "egy adat két
      // nézete" (M33) is a structural claim here, not just a caption.
      final hasElevation = splits.any((s) => s.elevationDeltaM != null);

      // One split is a list, not a chart: a single bar has nothing to be
      // compared against, and the average line would run through its middle.
      if (splits.length >= 2) {
        sections.addAll([
          const SizedBox(height: 12),
          _SectionCard(
            label: l10n.paceSectionLabel,
            trailingWidget: _FasterPill(label: l10n.paceChartFasterLabel),
            child: Column(
              children: [
                PaceBarChart(
                  bars: [
                    for (final s in splits)
                      PaceBar(
                        durationSeconds: s.durationSeconds,
                        partial: (s.distanceMeters ?? 0) < 999,
                        label: CardioFormatter.duration(Duration(seconds: s.durationSeconds)),
                      ),
                  ],
                  accent: accent,
                  selectedIndex: _selectedSplitIndex,
                  onBarTap: (index) => setState(
                    () => _selectedSplitIndex = _selectedSplitIndex == index ? null : index,
                  ),
                ),
                const SizedBox(height: 10),
                _PaceChartAxis(
                  averageLabel: _averagePaceLabel(l10n, fullSplits, unitSystem),
                  totalLabel: CardioFormatter.distance(
                    splits.fold<double>(0, (sum, s) => sum + (s.distanceMeters ?? 0)),
                    unitSystem,
                  ),
                ),
              ],
            ),
          ),
        ]);
      }

      sections.addAll([
        const SizedBox(height: 12),
        _SectionCard(
          label: l10n.splitsSectionLabel,
          trailing: hasElevation ? null : l10n.splitsNoElevationDataLabel,
          child: Column(
            children: [
              for (final (index, s) in splits.indexed)
                _SplitRow(
                  split: s,
                  unitSystem: unitSystem,
                  theme: theme,
                  scheme: scheme,
                  accent: accent,
                  slowestSeconds: slowest,
                  fastestSeconds: fastest,
                  showElevation: hasElevation,
                  selected: _selectedSplitIndex == index,
                  onTap: () => setState(
                    () => _selectedSplitIndex = _selectedSplitIndex == index ? null : index,
                  ),
                ),
              if (splits.length >= 2) ...[
                const SizedBox(height: 4),
                _SplitSelectionHint(text: l10n.splitSelectionHint),
              ],
            ],
          ),
        ),
      ]);
    }

    return sections;
  }

  /// The dashed average line's value, in pace terms — computed over the full
  /// splits only, for the same reason the chart excludes the partial tail
  /// from its scale.
  String? _averagePaceLabel(
    AppLocalizations l10n,
    List<CardioSplit> fullSplits,
    UnitSystem unitSystem,
  ) {
    if (fullSplits.isEmpty) return null;
    final meters = fullSplits.fold<double>(0, (sum, s) => sum + (s.distanceMeters ?? 0));
    final seconds = fullSplits.fold<int>(0, (sum, s) => sum + s.durationSeconds);
    final pace = CardioFormatter.pace(meters, Duration(seconds: seconds), unitSystem);
    return pace == null ? null : l10n.paceChartAverageLabel(pace);
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
  const _SectionCard({
    required this.label,
    required this.child,
    this.trailing,
    this.trailingWidget,
  });

  final String label;
  final Widget child;
  final String? trailing;

  /// Takes the same slot as [trailing] for a header that needs more than a
  /// number (M33's "↑ faster" pill).
  final Widget? trailingWidget;

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
              if (trailingWidget != null)
                trailingWidget!
              else if (trailing != null)
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
/// M36's celebration: the count in the header, then one row per record with
/// the value it replaced and by how much.
///
/// M36 also draws an "Open summary" primary button; there is deliberately no
/// such button here, because this dialog already opens *on top of* the
/// summary — the frame was drawn for a celebration reached from elsewhere.
class _CardioRecordCelebrationDialog extends StatelessWidget {
  const _CardioRecordCelebrationDialog({
    required this.types,
    required this.session,
    required this.previousBests,
    required this.unitSystem,
    required this.label,
  });

  final List<CardioPrType> types;
  final WorkoutSession session;
  final CardioPrBaseline previousBests;
  final UnitSystem unitSystem;
  final String Function(CardioPrType type) label;

  static const _amber = Color(0xFFD8B35A);
  static final _previousDate = DateFormat.MMMMd();

  /// Each type's own unit — a distance record reads in km, a time record in
  /// minutes, an elevation record in metres.
  String _format(CardioPrType type, double value) => switch (type) {
        CardioPrType.longestDistance => CardioFormatter.distance(value, unitSystem),
        CardioPrType.greatestElevationGain ||
        CardioPrType.greatestMaxAltitude =>
          CardioFormatter.elevation(value, unitSystem),
        CardioPrType.longestMovingTime ||
        CardioPrType.fastest1k ||
        CardioPrType.fastest5k ||
        CardioPrType.fastest10k =>
          CardioFormatter.duration(Duration(seconds: value.round())),
        // Already in kJ — `valueIn` derives it via CardioFormatter.totalWorkKj,
        // so this only rounds for display, no unit conversion needed.
        CardioPrType.greatestTotalWork => '${value.round()} kJ',
      };

  /// The improvement, always written as a gain: a best-effort record moves
  /// *down*, so its delta is shown as seconds saved rather than as a negative
  /// number the reader has to interpret.
  String? _delta(CardioPrType type, double value, double previous) {
    if (type.lowerIsBetter) {
      final saved = (previous - value).round();
      return saved <= 0 ? null : '−${CardioFormatter.duration(Duration(seconds: saved))}';
    }
    final gained = value - previous;
    if (gained <= 0) return null;
    return '+${_format(type, gained)}';
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return AlertDialog(
      icon: const Icon(Icons.emoji_events, color: _amber, size: 32),
      title: Text(
        l10n.cardioRecordCelebrationTitle(types.length),
        textAlign: TextAlign.center,
        style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final type in types)
              Builder(builder: (context) {
                final value = type.valueIn(session);
                final previous = previousBests[type];
                if (value == null) return const SizedBox.shrink();
                final delta = previous == null ? null : _delta(type, value, previous.value);
                return Padding(
                  padding: const EdgeInsets.only(bottom: 14),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              label(type),
                              style: theme.textTheme.titleSmall
                                  ?.copyWith(fontWeight: FontWeight.w800),
                            ),
                            if (previous != null)
                              Text(
                                l10n.cardioRecordPrevious(
                                  _format(type, previous.value),
                                  _previousDate.format(previous.at),
                                ),
                                style: theme.textTheme.bodySmall
                                    ?.copyWith(color: scheme.outline),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            _format(type, value),
                            style: const TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w800,
                              fontFeatures: [FontFeature.tabularFigures()],
                            ),
                          ),
                          if (delta != null)
                            Text(
                              delta,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: scheme.primary,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                );
              }),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.cardioRecordCelebrationClose),
        ),
      ],
    );
  }
}

/// One line of M34's best-efforts card.
class _BestEffortRow {
  const _BestEffortRow({
    required this.label,
    required this.duration,
    required this.pace,
    required this.isRecord,
  });

  final String label;
  final Duration duration;

  /// Null only when the pace can't be derived — never in practice here,
  /// since every row has both a distance and a time by construction.
  final String? pace;
  final bool isRecord;
}

/// M34's row: distance · time · normalized pace. A record row is marked with
/// an amber wash, border and trophy pill rather than a different background
/// colour — the same "highlighted row" pattern the statistics record list
/// uses, so a record reads as *this* row emphasized, not as another kind of
/// row.
class _BestEffortTile extends StatelessWidget {
  const _BestEffortTile({
    required this.row,
    required this.subtitle,
    required this.recordBadge,
    required this.theme,
  });

  final _BestEffortRow row;
  final String subtitle;
  final String recordBadge;
  final ThemeData theme;

  static const _amber = Color(0xFFD8B35A);

  @override
  Widget build(BuildContext context) {
    final scheme = theme.colorScheme;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: row.isRecord ? _amber.withValues(alpha: 0.12) : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        border: row.isRecord ? Border.all(color: _amber.withValues(alpha: 0.34)) : null,
      ),
      child: Row(
        children: [
          SizedBox(
            width: 44,
            child: Text(
              row.label,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  CardioFormatter.duration(row.duration),
                  style: const TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.w800,
                    fontFeatures: [FontFeature.tabularFigures()],
                  ),
                ),
                const SizedBox(height: 1),
                // The trophy pill sits on the subtitle line rather than
                // beside the time: on a 360 px phone "49:40" + the pill +
                // the pace don't fit one row, and an ellipsized record time
                // would be worse than a pill one line lower.
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        subtitle,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 10, color: scheme.outline),
                      ),
                    ),
                    if (row.isRecord) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 1),
                        decoration: BoxDecoration(
                          color: _amber,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          recordBadge,
                          style: const TextStyle(
                            fontSize: 9.5,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF161611),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          if (row.pace != null)
            Text(
              row.pace!,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w800,
                color: row.isRecord ? _amber : scheme.onSurfaceVariant,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
        ],
      ),
    );
  }
}

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
        CardioPrType.fastest1k => l10n.cardioRecordFastest1k,
        CardioPrType.fastest5k => l10n.cardioRecordFastest5k,
        CardioPrType.fastest10k => l10n.cardioRecordFastest10k,
        CardioPrType.greatestTotalWork => l10n.cardioRecordGreatestTotalWork,
        CardioPrType.greatestMaxAltitude => l10n.cardioRecordGreatestMaxAltitude,
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

/// One row of the split list — index · bar · time · elevation delta. Its
/// depth is the answer to docs/cardio/60 Q-D1: distance, pace and elevation,
/// **no heart rate** — a fourth number would force 10.5 px type into a 390 px
/// row. Splits are never hand-editable; the session's distance is, and the
/// splits recompute from it.
///
/// Tapping selects, which lights up this row *and* its bar in the chart above
/// (M33). A `Wrap` of small tiles would be far less scannable than a list for
/// something inherently sequential.
class _SplitRow extends StatelessWidget {
  const _SplitRow({
    required this.split,
    required this.unitSystem,
    required this.theme,
    required this.scheme,
    required this.accent,
    required this.slowestSeconds,
    required this.fastestSeconds,
    required this.showElevation,
    required this.selected,
    required this.onTap,
  });

  final CardioSplit split;
  final UnitSystem unitSystem;
  final ThemeData theme;
  final ColorScheme scheme;
  final Color accent;

  /// The full splits' extremes, used to scale the bar and its color.
  final int slowestSeconds;
  final int fastestSeconds;

  /// False when *no* split in the run recorded an altitude change — the card
  /// says so once instead of every row ending in an unexplained blank.
  final bool showElevation;

  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final duration = Duration(seconds: split.durationSeconds);
    // "Az utolsó split részleges, ezért nem tempót mutat, hanem a megtett
    // távot — így nem tűnik hirtelen belassulásnak" (M14).
    final partial = (split.distanceMeters ?? 0) < 999;

    // Faster split = longer, lighter bar. One hue, two lightness steps —
    // never a second color family (M13's note).
    final span = (slowestSeconds - fastestSeconds).clamp(1, 1 << 30);
    final speed = partial ? 0.0 : ((slowestSeconds - split.durationSeconds) / span).clamp(0.0, 1.0);
    final barColor = partial
        ? scheme.outlineVariant
        : Color.lerp(accent.withValues(alpha: 0.55), accent, speed)!;
    final fraction =
        partial ? ((split.distanceMeters ?? 0) / 1000).clamp(0.1, 1.0) : 0.55 + 0.45 * speed;

    final elevation = split.elevationDeltaM;

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        // The selected row widens past the card's padding rather than just
        // changing color — M33's negative-margin treatment.
        margin: const EdgeInsets.only(bottom: 9),
        padding: selected
            ? const EdgeInsets.symmetric(horizontal: 8, vertical: 6)
            : const EdgeInsets.symmetric(vertical: 6),
        transform: selected ? Matrix4.translationValues(-8, 0, 0) : null,
        width: selected ? double.infinity : null,
        decoration: selected
            ? BoxDecoration(
                color: scheme.surfaceContainer,
                borderRadius: BorderRadius.circular(12),
              )
            : null,
        child: Row(
          children: [
            SizedBox(
              width: 16,
              child: Text(
                '${split.splitIndex + 1}',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: selected
                      ? accent
                      : (partial ? scheme.outline : scheme.onSurfaceVariant),
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
                  ? CardioFormatter.distance(split.distanceMeters ?? 0, unitSystem)
                  : CardioFormatter.duration(duration),
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w800,
                color: selected ? accent : (partial ? scheme.outline : scheme.onSurface),
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
            if (showElevation) ...[
              const SizedBox(width: 10),
              SizedBox(
                width: 38,
                child: Text(
                  // Signed, and rounded to whole units — a split's net climb
                  // is never precise enough for decimals, and the sign is the
                  // information ("+12" reads instantly as a hill).
                  elevation == null
                      ? ''
                      : (elevation >= 0 ? '+' : '−') +
                          CardioFormatter.elevation(elevation.abs(), unitSystem),
                  textAlign: TextAlign.right,
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                    color: scheme.onSurfaceVariant,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// M33's header pill on the pace card: an upward arrow plus "faster", which
/// is the one thing a reader must know before the chart makes sense — the
/// scale is inverted, so a taller bar is a quicker split.
class _FasterPill extends StatelessWidget {
  const _FasterPill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: scheme.surfaceContainer,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.arrow_upward, size: 11, color: scheme.onSurfaceVariant),
          const SizedBox(width: 3),
          Text(
            label,
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
              color: scheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

/// The line under the pace chart: what the dashed average line is worth, and
/// how far the run went in total.
class _PaceChartAxis extends StatelessWidget {
  const _PaceChartAxis({required this.averageLabel, required this.totalLabel});

  final String? averageLabel;
  final String totalLabel;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final style = TextStyle(
      fontSize: 10,
      fontWeight: FontWeight.w600,
      color: scheme.onSurfaceVariant,
      fontFeatures: const [FontFeature.tabularFigures()],
    );
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(averageLabel ?? '', style: style),
        Text(totalLabel, style: style),
      ],
    );
  }
}

/// M33's closing line under the split list, stating outright that the list
/// and the chart are the same data — cheaper than expecting the reader to
/// discover it by tapping.
class _SplitSelectionHint extends StatelessWidget {
  const _SplitSelectionHint({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(Icons.touch_app_outlined, size: 13, color: scheme.outline),
        const SizedBox(width: 7),
        Expanded(
          child: Text(
            text,
            style: TextStyle(fontSize: 10.5, height: 1.35, color: scheme.outline),
          ),
        ),
      ],
    );
  }
}

/// M39's hero: the work actually done, derived from average power and the
/// time it was held ([CardioFormatter.totalWorkKj]) — never stored, so it can
/// never disagree with the two numbers beside it (docs/cardio/51 §3.3).
class _TotalWorkCard extends StatelessWidget {
  const _TotalWorkCard({
    required this.totalWorkKj,
    required this.avgWatts,
    required this.maxWatts,
    required this.accent,
  });

  final int totalWorkKj;
  final double avgWatts;
  final double? maxWatts;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.bolt, size: 18, color: accent),
                const SizedBox(height: 6),
                Text(
                  '$totalWorkKj',
                  style: const TextStyle(
                    fontSize: 40,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -1.6,
                    height: 1.05,
                    fontFeatures: [FontFeature.tabularFigures()],
                  ),
                ),
                Text(
                  'kJ ${l10n.totalWorkLabel}',
                  style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700),
                ),
                Text(
                  l10n.totalWorkSourceHint,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.speed, size: 18, color: scheme.onSurfaceVariant),
                const SizedBox(height: 6),
                Text(
                  '${avgWatts.round()}',
                  style: const TextStyle(
                    fontSize: 40,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -1.6,
                    height: 1.05,
                    fontFeatures: [FontFeature.tabularFigures()],
                  ),
                ),
                Text(
                  l10n.avgWattsFieldLabel,
                  style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700),
                ),
                if (maxWatts != null)
                  Text(
                    l10n.maxWattsShortLabel(maxWatts!.round()),
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: scheme.onSurfaceVariant,
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

/// M39's calorie card — **one card, two sides, a line between them**.
///
/// The left side is the app's own estimate, in the calorie accent at full
/// contrast, and it is the one that counts towards the day. The right side is
/// what the machine displayed, in a secondary tone: informative, never added
/// (docs/cardio/51 Q4). Two separate cards were tried and were worse — they
/// read as two equal numbers, and the suspicion that something sums them
/// survived.
class _CalorieCard extends StatelessWidget {
  const _CalorieCard({
    required this.activeCalories,
    required this.machineCalories,
    required this.machineEdited,
    required this.onEditMachine,
    required this.l10n,
    required this.accent,
  });

  final double? activeCalories;
  final double? machineCalories;
  final bool machineEdited;
  final VoidCallback? onEditMachine;
  final AppLocalizations l10n;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: _CalorieSide(
                    icon: Icons.local_fire_department,
                    label: l10n.activeCaloriesLabel,
                    value: activeCalories,
                    hint: l10n.activeCaloriesHint,
                    valueColor: accent,
                    labelColor: accent,
                    hintColor: scheme.onSurfaceVariant,
                  ),
                ),
                // The line is the whole point: it separates two facts instead
                // of listing two comparable numbers.
                VerticalDivider(width: 25, thickness: 1, color: scheme.outlineVariant),
                Expanded(
                  child: InkWell(
                    onTap: onEditMachine,
                    borderRadius: BorderRadius.circular(12),
                    child: _CalorieSide(
                      icon: Icons.monitor,
                      label: l10n.machineCaloriesLabel,
                      value: machineCalories,
                      hint: l10n.machineCaloriesHint,
                      valueColor: scheme.onSurfaceVariant,
                      labelColor: scheme.onSurfaceVariant,
                      hintColor: scheme.onSurfaceVariant,
                      badge: machineEdited ? l10n.manuallyEditedBadgeLabel : null,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.info_outline, size: 15, color: scheme.onSurfaceVariant),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  l10n.machineCaloriesFootnote,
                  style: TextStyle(
                    fontSize: 11,
                    height: 1.45,
                    fontWeight: FontWeight.w500,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CalorieSide extends StatelessWidget {
  const _CalorieSide({
    required this.icon,
    required this.label,
    required this.value,
    required this.hint,
    required this.valueColor,
    required this.labelColor,
    required this.hintColor,
    this.badge,
  });

  final IconData icon;
  final String label;
  final double? value;
  final String hint;
  final Color valueColor;
  final Color labelColor;
  final Color hintColor;
  final String? badge;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 14, color: labelColor),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                label,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.1,
                  color: labelColor,
                ),
              ),
            ),
            if (badge != null) ...[
              const SizedBox(width: 5),
              Text(
                badge!,
                style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: hintColor),
              ),
            ],
          ],
        ),
        const SizedBox(height: 4),
        Text(
          value == null ? '—' : '${value!.round()}',
          style: TextStyle(
            fontSize: 30,
            fontWeight: FontWeight.w800,
            letterSpacing: -1.2,
            height: 1.1,
            color: valueColor,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
        Text(
          hint,
          style: TextStyle(
            fontSize: 10.5,
            height: 1.4,
            fontWeight: FontWeight.w500,
            color: hintColor,
          ),
        ),
      ],
    );
  }
}

/// One executed interval section (M39): the same row shape as a running km
/// split, with two differences — the section's own intensity stands where the
/// kilometre would, and the bar's length shows that intensity rather than a
/// pace.
/// One row of the ÚTPONTOK list (docs/cardio/60 C8.4, M42): sorszám · táv ·
/// magasság · idő. The last three read "—" whenever [MatchedWaypoint]
/// couldn't derive them (no local track left to match against) — the
/// waypoint's own stored altitude is used when it's the only altitude
/// available (see `matchWaypointsToTrail`'s fallback).
/// M42's "IDŐJÁRÁS INDULÁSKOR" card — a condition icon plus three inline
/// readouts (docs/cardio/60 C8.6). Whichever of the four fields is missing
/// reads "—" rather than being omitted, so a partial snapshot (e.g.
/// temperature entered, precipitation skipped) doesn't silently reflow the
/// other two.
class _WeatherCard extends StatelessWidget {
  const _WeatherCard({
    required this.condition,
    required this.tempC,
    required this.windKph,
    required this.precipMm,
    required this.unitSystem,
    required this.snapshotTime,
    required this.l10n,
    required this.onTap,
  });

  static final _timeLabel = DateFormat('HH:mm');

  final String? condition;
  final double? tempC;
  final double? windKph;
  final double? precipMm;
  final UnitSystem unitSystem;
  final DateTime snapshotTime;
  final AppLocalizations l10n;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.surfaceContainerLow,
      borderRadius: BorderRadius.circular(22),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      l10n.weatherSectionLabel,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.2,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                  Text(
                    l10n.weatherSnapshotCaption(_timeLabel.format(snapshotTime.toLocal())),
                    style: TextStyle(
                        fontSize: 10.5, fontWeight: FontWeight.w600, color: scheme.onSurfaceVariant),
                  ),
                ],
              ),
              const SizedBox(height: 13),
              Row(
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: scheme.secondary.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Icon(weatherConditionIcon(condition), color: scheme.secondary, size: 28),
                  ),
                  const SizedBox(width: 13),
                  Expanded(
                    child: Row(
                      children: [
                        Expanded(
                          child: _WeatherReadout(
                            value: tempC == null ? '—' : CardioFormatter.temperature(tempC!, unitSystem),
                            label: l10n.weatherTemperatureReadoutLabel,
                          ),
                        ),
                        Expanded(
                          child: _WeatherReadout(
                            value:
                                windKph == null ? '—' : CardioFormatter.windSpeed(windKph!, unitSystem),
                            label: l10n.weatherWindReadoutLabel,
                          ),
                        ),
                        Expanded(
                          child: _WeatherReadout(
                            value: precipMm == null
                                ? '—'
                                : CardioFormatter.precipitation(precipMm!, unitSystem),
                            label: l10n.weatherPrecipReadoutLabel,
                          ),
                        ),
                      ],
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

class _WeatherReadout extends StatelessWidget {
  const _WeatherReadout({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          value,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            fontFeatures: [FontFeature.tabularFigures()],
          ),
        ),
        Text(
          label,
          style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w600, color: scheme.onSurfaceVariant),
        ),
      ],
    );
  }
}

/// The empty-state row (M42: "Nincs időjárás-adat") — tappable, so it also
/// serves as the add-weather entry point (see [_weatherSection]'s doc).
class _WeatherEmptyRow extends StatelessWidget {
  const _WeatherEmptyRow({required this.message, required this.onTap});

  final String message;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.surfaceContainerLow,
      borderRadius: BorderRadius.circular(18),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              Icon(Icons.cloud_off, size: 19, color: scheme.onSurfaceVariant),
              const SizedBox(width: 11),
              Expanded(
                child: Text(
                  message,
                  style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: scheme.onSurfaceVariant),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _WaypointRow extends StatelessWidget {
  const _WaypointRow({required this.matched, required this.unitSystem});

  final MatchedWaypoint matched;
  final UnitSystem unitSystem;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final distance = matched.distanceMeters == null
        ? '—'
        : CardioFormatter.distance(matched.distanceMeters!, unitSystem);
    final altitude = matched.altitudeMeters == null
        ? '—'
        : CardioFormatter.elevation(matched.altitudeMeters!, unitSystem);
    final elapsed = matched.elapsedSeconds == null
        ? '—'
        : CardioFormatter.duration(Duration(seconds: matched.elapsedSeconds!));
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          SizedBox(
            width: 22,
            child: Text(
              '${matched.waypoint.waypointIndex + 1}',
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w800,
                color: scheme.onSurfaceVariant,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
          Expanded(
            child: Text(
              '$distance · $altitude · $elapsed',
              style: const TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                fontFeatures: [FontFeature.tabularFigures()],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _IntervalSectionRow extends StatelessWidget {
  const _IntervalSectionRow({
    required this.number,
    required this.split,
    required this.accent,
    required this.l10n,
  });

  final int number;
  final CardioSplit split;
  final Color accent;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final intensity = split.intensity;
    final hard = intensity == IntervalIntensity.hard;
    final fraction = switch (intensity) {
      IntervalIntensity.hard => 1.0,
      IntervalIntensity.moderate => 0.65,
      _ => 0.35,
    };
    final label = switch (intensity) {
      IntervalIntensity.hard => l10n.intervalIntensityHard,
      IntervalIntensity.moderate => l10n.intervalIntensityModerate,
      _ => l10n.intervalIntensityEasy,
    };

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          SizedBox(
            width: 16,
            child: Text(
              '$number',
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w800,
                color: scheme.onSurfaceVariant,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
          SizedBox(
            width: 66,
            child: Text(
              label,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
                color: hard ? accent : scheme.onSurfaceVariant,
              ),
            ),
          ),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(5),
              child: LinearProgressIndicator(
                value: fraction,
                minHeight: 10,
                backgroundColor: scheme.surfaceContainerHighest,
                valueColor: AlwaysStoppedAnimation(
                  hard ? accent : accent.withValues(alpha: fraction),
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          SizedBox(
            width: 40,
            child: Text(
              CardioFormatter.duration(Duration(seconds: split.durationSeconds)),
              textAlign: TextAlign.right,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                fontFeatures: [FontFeature.tabularFigures()],
              ),
            ),
          ),
          if (split.avgWatts != null)
            SizedBox(
              width: 48,
              child: Text(
                '${split.avgWatts!.round()} W',
                textAlign: TextAlign.right,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: scheme.onSurfaceVariant,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// The section count in the interval card's header — the same chip shape M39
/// uses for its `repeat` badge.
class _IntervalCountChip extends StatelessWidget {
  const _IntervalCountChip({required this.label, required this.accent});

  final String label;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.repeat, size: 12, color: accent),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, color: accent),
          ),
        ],
      ),
    );
  }
}

/// M40's real elevation-profile card: the chart, a fixed "csúcs" caption
/// under the axis, and — only once a point has been tapped — a three-number
/// readout row at the bottom of the card. No floating tooltip, per M40's own
/// explicit call: on a 390 px screen it would either overflow or cover the
/// curve.
class _ElevationProfileCard extends StatelessWidget {
  const _ElevationProfileCard({
    required this.profile,
    required this.selectedIndex,
    required this.elevationGainMeters,
    required this.unitSystem,
    required this.l10n,
    required this.onPointTap,
  });

  final ElevationProfile profile;
  final int? selectedIndex;
  final double elevationGainMeters;
  final UnitSystem unitSystem;
  final AppLocalizations l10n;
  final ValueChanged<int> onPointTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final peak = profile.peak!;
    final index = selectedIndex;
    final selected = index != null && index < profile.allPoints.length
        ? profile.allPoints[index]
        : null;

    return _SectionCard(
      label: l10n.elevationProfileSectionLabel,
      trailingWidget: selected != null
          ? _SelectedPointChip(
              label: l10n.elevationProfileSelectedPointChip(
                CardioFormatter.distance(selected.cumulativeDistanceMeters, unitSystem),
              ),
              accent: scheme.primary,
            )
          : Text(
              '+${CardioFormatter.elevation(elevationGainMeters, unitSystem)}',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: scheme.onSurfaceVariant,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ElevationProfileChart(
            profile: profile,
            selectedIndex: selectedIndex,
            onPointTap: onPointTap,
            gapLabel: l10n.elevationProfileGapLabel,
          ),
          const SizedBox(height: 6),
          Text(
            l10n.elevationProfilePeakCaption(
              CardioFormatter.elevation(peak.altitudeMeters, unitSystem),
              CardioFormatter.distance(peak.cumulativeDistanceMeters, unitSystem),
            ),
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: scheme.onSurfaceVariant,
            ),
          ),
          if (selected != null) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _ElevationReadout(
                    icon: Icons.my_location,
                    value: CardioFormatter.elevation(selected.altitudeMeters, unitSystem),
                    label: l10n.elevationProfileAltitudeReadoutLabel,
                  ),
                ),
                Expanded(
                  child: _ElevationReadout(
                    value: CardioFormatter.distance(selected.cumulativeDistanceMeters, unitSystem),
                    label: l10n.elevationProfileDistanceReadoutLabel,
                  ),
                ),
                Expanded(
                  child: _ElevationReadout(
                    value: CardioFormatter.duration(Duration(seconds: selected.elapsedSeconds)),
                    label: l10n.elevationProfileElapsedReadoutLabel,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// One number of the selected-point readout row (M40: "my_location 612 m
/// magasság · 8,4 km idáig · 2:38 eltelt").
class _ElevationReadout extends StatelessWidget {
  const _ElevationReadout({required this.value, required this.label, this.icon});

  final IconData? icon;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            if (icon != null) ...[
              Icon(icon, size: 13, color: scheme.onSurfaceVariant),
              const SizedBox(width: 4),
            ],
            Text(
              value,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                fontFeatures: [FontFeature.tabularFigures()],
              ),
            ),
          ],
        ),
        Text(
          label,
          style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: scheme.onSurfaceVariant),
        ),
      ],
    );
  }
}

/// The "kiválasztott pont · 6,4 km" header chip — same shape as
/// [_IntervalCountChip], different icon.
class _SelectedPointChip extends StatelessWidget {
  const _SelectedPointChip({required this.label, required this.accent});

  final String label;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.location_on, size: 12, color: accent),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, color: accent),
          ),
        ],
      ),
    );
  }
}

/// Marks a fallen-back-to-the-old-approximation elevation profile
/// (docs/cardio/60 C8.3's kész-ha: "a nyers pontok törlése után
/// 'EGYSZERŰSÍTETT' profil marad, nem üres hely") — a small, muted badge
/// rather than an error state, since nothing actually went wrong.
class _SimplifiedBadge extends StatelessWidget {
  const _SimplifiedBadge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 9,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.4,
          color: scheme.onSurfaceVariant,
        ),
      ),
    );
  }
}
