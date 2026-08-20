import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../l10n/app_localizations.dart';
import '../../../shared/widgets/app_snackbar.dart';
import '../../settings/application/settings_controller.dart';
import '../../settings/domain/user_settings.dart';
import '../application/workout_session_controller.dart';
import '../domain/activity_type.dart';
import '../domain/weather_condition.dart';
import 'widgets/box_score_stepper.dart';
import '../domain/workout_session.dart';
import 'widgets/rpe_selector.dart';

/// Bottom sheet to manually (after the fact) log a cardio workout — all
/// three families (docs/cardio/59-cardio-implementation-plan.md C1.8/C1.9):
/// DISTANCE, MACHINE, and GAME (intensity, venue, optional score), plus the
/// universal RPE + note fields, reusing [RpeSelector] from the existing
/// post-workout feedback flow.
class LogCardioSheet extends ConsumerStatefulWidget {
  const LogCardioSheet({super.key});

  @override
  ConsumerState<LogCardioSheet> createState() => _LogCardioSheetState();
}

class _LogCardioSheetState extends ConsumerState<LogCardioSheet> {
  static final _dateTimeLabel = DateFormat('EEE, MMM d · HH:mm');

  String _activityType = kActivityTypes.first;
  DateTime _startedAt = DateTime.now();
  bool _submitting = false;

  final _hoursController = TextEditingController();
  final _minutesController = TextEditingController();
  final _secondsController = TextEditingController();
  final _distanceController = TextEditingController();
  final _elevationGainController = TextEditingController();
  final _backpackWeightController = TextEditingController();
  final _weatherTempController = TextEditingController();
  final _weatherWindController = TextEditingController();
  final _weatherPrecipController = TextEditingController();
  final _avgWattsController = TextEditingController();
  final _avgCadenceController = TextEditingController();
  final _resistanceController = TextEditingController();
  final _deviceCaloriesController = TextEditingController();
  final _noteController = TextEditingController();

  int? _intensity;
  String? _venue;
  int? _scorePoints;
  int? _scoreAssists;
  int? _scoreRebounds;
  int? _rpe;
  String? _weatherCondition;

  @override
  void dispose() {
    _hoursController.dispose();
    _minutesController.dispose();
    _secondsController.dispose();
    _distanceController.dispose();
    _elevationGainController.dispose();
    _backpackWeightController.dispose();
    _weatherTempController.dispose();
    _weatherWindController.dispose();
    _weatherPrecipController.dispose();
    _avgWattsController.dispose();
    _avgCadenceController.dispose();
    _resistanceController.dispose();
    _deviceCaloriesController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  ActivityFamily get _family => activityFamilyOf(_activityType);

  int get _durationSeconds {
    final h = int.tryParse(_hoursController.text) ?? 0;
    final m = int.tryParse(_minutesController.text) ?? 0;
    final s = int.tryParse(_secondsController.text) ?? 0;
    return h * 3600 + m * 60 + s;
  }

  double? _parseDouble(String text) {
    if (text.trim().isEmpty) return null;
    return double.tryParse(text.replaceAll(',', '.').trim());
  }

  int? _parseInt(String text) {
    if (text.trim().isEmpty) return null;
    return int.tryParse(text.trim());
  }

  Future<void> _pickDateTime() async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: _startedAt,
      firstDate: DateTime(2000),
      lastDate: now,
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_startedAt),
    );
    if (!mounted) return;
    setState(() {
      _startedAt = DateTime(
        date.year,
        date.month,
        date.day,
        time?.hour ?? _startedAt.hour,
        time?.minute ?? _startedAt.minute,
      );
    });
  }

  Future<void> _submit() async {
    if (_submitting || _durationSeconds <= 0) return;
    setState(() => _submitting = true);
    final navigator = Navigator.of(context);
    final l10n = AppLocalizations.of(context)!;

    final distanceKm = _parseDouble(_distanceController.text);
    final unitSystem =
        (ref.read(settingsControllerProvider).value ?? const UserSettings.defaults())
            .unitSystem;
    final distanceMeters = distanceKm == null
        ? null
        : distanceKm * (unitSystem == UnitSystem.imperial ? 1609.344 : 1000);
    final elevationGainM = _family == ActivityFamily.distance
        ? _parseDouble(_elevationGainController.text)
        : null;
    // Hike-only (docs/cardio/60 C8.5, M42) — entered in whatever unit the
    // field itself showed, converted to kg for storage.
    const kgPerLb = 0.45359237;
    final backpackWeightInput =
        _activityType == 'HIKING' ? _parseDouble(_backpackWeightController.text) : null;
    final backpackWeightKg = backpackWeightInput == null
        ? null
        : (unitSystem == UnitSystem.imperial ? backpackWeightInput * kgPerLb : backpackWeightInput);
    final hiking = _activityType == 'HIKING';
    final weatherTempInput = hiking ? _parseDouble(_weatherTempController.text) : null;
    final weatherTempC = weatherTempInput == null
        ? null
        : (unitSystem == UnitSystem.imperial
            ? (weatherTempInput - 32) * 5 / 9
            : weatherTempInput);
    const kphPerMph = 1.609344;
    final weatherWindInput = hiking ? _parseDouble(_weatherWindController.text) : null;
    final weatherWindKph = weatherWindInput == null
        ? null
        : (unitSystem == UnitSystem.imperial ? weatherWindInput * kphPerMph : weatherWindInput);
    const mmPerInch = 25.4;
    final weatherPrecipInput = hiking ? _parseDouble(_weatherPrecipController.text) : null;
    final weatherPrecipMm = weatherPrecipInput == null
        ? null
        : (unitSystem == UnitSystem.imperial ? weatherPrecipInput * mmPerInch : weatherPrecipInput);
    final weatherCondition = hiking ? _weatherCondition : null;
    final avgWatts = _family == ActivityFamily.machine ? _parseDouble(_avgWattsController.text) : null;
    final avgCadence =
        _family == ActivityFamily.machine ? _parseDouble(_avgCadenceController.text) : null;
    final resistanceLevel =
        _family == ActivityFamily.machine ? _parseInt(_resistanceController.text) : null;
    final deviceCalories =
        _family == ActivityFamily.machine ? _parseDouble(_deviceCaloriesController.text) : null;
    final intensity = _family == ActivityFamily.game ? _intensity : null;
    final venue = _family == ActivityFamily.game ? _venue : null;
    final scorePoints = _family == ActivityFamily.game ? _scorePoints : null;
    final scoreAssists = _family == ActivityFamily.game ? _scoreAssists : null;
    final scoreRebounds =
        _family == ActivityFamily.game && _activityType == 'BASKETBALL' ? _scoreRebounds : null;

    final hasAnyMetric = distanceMeters != null ||
        elevationGainM != null ||
        backpackWeightKg != null ||
        weatherTempC != null ||
        weatherWindKph != null ||
        weatherPrecipMm != null ||
        weatherCondition != null ||
        avgWatts != null ||
        avgCadence != null ||
        resistanceLevel != null ||
        deviceCalories != null ||
        intensity != null ||
        venue != null ||
        scorePoints != null;

    final cardio = !hasAnyMetric
        ? null
        : CardioMetrics(
            distanceMeters: distanceMeters,
            elevationGainMeters: elevationGainM,
            backpackWeightKg: backpackWeightKg,
            weatherTempC: weatherTempC,
            weatherWindKph: weatherWindKph,
            weatherPrecipMm: weatherPrecipMm,
            weatherCondition: weatherCondition,
            avgWatts: avgWatts,
            avgCadence: avgCadence,
            resistanceLevel: resistanceLevel,
            deviceCalories: deviceCalories,
            intensity: intensity,
            venue: venue,
            scorePoints: scorePoints,
            scoreAssists: scoreAssists,
            scoreRebounds: scoreRebounds,
            // A manual override always wins over a measured value (docs/cardio/
            // 51-cardio-overview-plan.md R8) — every numeric field this sheet
            // captures ultimately maps to one of these two source flags, the
            // only per-field provenance the domain model tracks.
            distanceSource: distanceMeters == null ? null : 'MANUAL',
            caloriesSource: deviceCalories == null ? null : 'MANUAL',
          );

    final note = _noteController.text.trim();

    try {
      await ref.read(workoutSessionControllerProvider.notifier).logCardioSession(
            startedAt: _startedAt,
            activityType: _activityType,
            movingSeconds: _durationSeconds,
            cardio: cardio,
            rpe: _rpe,
            feedbackNote: note.isEmpty ? null : note,
          );
      navigator.pop();
      if (mounted) {
        AppSnackbar.showSuccess(context, title: l10n.cardioWorkoutLoggedMessage);
      }
    } catch (_) {
      if (mounted) {
        setState(() => _submitting = false);
        AppSnackbar.showError(context, title: l10n.couldNotLogWorkoutMessage);
      }
    }
  }

  Widget _durationField(TextEditingController controller, String suffix) {
    return SizedBox(
      width: 72,
      child: TextField(
        controller: controller,
        enabled: !_submitting,
        keyboardType: TextInputType.number,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        textAlign: TextAlign.center,
        onChanged: (_) => setState(() {}),
        decoration: InputDecoration(
          isDense: true,
          suffixText: suffix,
          border: const OutlineInputBorder(),
          contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
        ),
      ),
    );
  }

  Widget _numericField({
    required String label,
    required TextEditingController controller,
    required String suffix,
    bool decimal = true,
    // Winter-hike temperatures go below zero (docs/cardio/60 C8.1) — every
    // other numeric field this sheet captures is a non-negative measurement,
    // so this defaults off rather than adding a stray '-' to fields where it
    // would never be a valid entry.
    bool signed = false,
  }) {
    final pattern = signed
        ? (decimal ? r'[-\d.,]' : r'[-\d]')
        : (decimal ? r'[\d.,]' : r'\d');
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: TextField(
        controller: controller,
        enabled: !_submitting,
        keyboardType: TextInputType.numberWithOptions(decimal: decimal, signed: signed),
        inputFormatters: [FilteringTextInputFormatter.allow(RegExp(pattern))],
        decoration: InputDecoration(
          labelText: label,
          suffixText: suffix,
          isDense: true,
          border: const OutlineInputBorder(),
        ),
      ),
    );
  }

  /// The condition chip row (docs/cardio/60 C8.6, M42) — shared between this
  /// sheet and `CardioSummaryScreen`'s weather edit sheet, but small enough
  /// (six chips) that duplicating the ~15-line builder was simpler than
  /// threading a callback-shaped widget between two otherwise unrelated
  /// screens.
  Widget _weatherConditionChips(AppLocalizations l10n) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final code in kWeatherConditions)
          ChoiceChip(
            label: Text(weatherConditionLabel(l10n, code)),
            avatar: Icon(weatherConditionIcon(code), size: 18),
            selected: _weatherCondition == code,
            onSelected: _submitting
                ? null
                : (_) => setState(
                    () => _weatherCondition = _weatherCondition == code ? null : code),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    final viewInsets = MediaQuery.of(context).viewInsets.bottom;
    final unitSystem =
        (ref.watch(settingsControllerProvider).value ?? const UserSettings.defaults())
            .unitSystem;
    final distanceUnit = unitSystem == UnitSystem.imperial ? 'mi' : 'km';
    final elevationUnit = unitSystem == UnitSystem.imperial ? 'ft' : 'm';
    final weightUnit = unitSystem == UnitSystem.imperial ? 'lb' : 'kg';
    final tempUnit = unitSystem == UnitSystem.imperial ? '°F' : '°C';
    final windUnit = unitSystem == UnitSystem.imperial ? 'mph' : 'km/h';
    final precipUnit = unitSystem == UnitSystem.imperial ? 'in' : 'mm';
    final canSubmit = !_submitting && _durationSeconds > 0;

    return Padding(
      padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + viewInsets),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(l10n.logCardioSheetTitle, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 16),
            Text(l10n.activityTypeSectionLabel, style: Theme.of(context).textTheme.labelLarge),
            const SizedBox(height: 8),
            SizedBox(
              height: 44,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: kActivityTypes.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (context, i) {
                  final type = kActivityTypes[i];
                  final selected = type == _activityType;
                  final color = activityTypeColor(type, context);
                  return ChoiceChip(
                    label: Text(activityTypeLabel(l10n, type)),
                    avatar: Icon(activityTypeIcon(type), size: 18, color: selected ? null : color),
                    selected: selected,
                    selectedColor: color,
                    labelStyle: TextStyle(
                      color: selected ? scheme.onPrimary : null,
                      fontWeight: FontWeight.w700,
                    ),
                    onSelected:
                        _submitting ? null : (_) => setState(() => _activityType = type),
                  );
                },
              ),
            ),
            const SizedBox(height: 16),
            Text(l10n.whenLabel, style: Theme.of(context).textTheme.labelLarge),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: _submitting ? null : _pickDateTime,
              icon: const Icon(Icons.schedule),
              label: Text(_dateTimeLabel.format(_startedAt)),
            ),
            const SizedBox(height: 16),
            Text(l10n.durationSectionLabel, style: Theme.of(context).textTheme.labelLarge),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.start,
              children: [
                _durationField(_hoursController, l10n.durationHoursAbbrev),
                const SizedBox(width: 8),
                _durationField(_minutesController, l10n.durationMinutesAbbrev),
                const SizedBox(width: 8),
                _durationField(_secondsController, l10n.durationSecondsAbbrev),
              ],
            ),
            const SizedBox(height: 16),
            if (_family == ActivityFamily.distance) ...[
              _numericField(
                label: l10n.distanceFieldLabel,
                controller: _distanceController,
                suffix: distanceUnit,
              ),
              _numericField(
                label: l10n.elevationGainFieldLabel,
                controller: _elevationGainController,
                suffix: elevationUnit,
                decimal: false,
              ),
              // Hike-only (docs/cardio/60 C8.5's kész-ha: "csak túránál
              // látszik") — RUNNING/WALKING share this branch but never see
              // the field.
              if (_activityType == 'HIKING') ...[
                _numericField(
                  label: l10n.backpackWeightFieldLabel,
                  controller: _backpackWeightController,
                  suffix: weightUnit,
                ),
                _numericField(
                  label: l10n.weatherTemperatureFieldLabel,
                  controller: _weatherTempController,
                  suffix: tempUnit,
                  decimal: false,
                  signed: true,
                ),
                _numericField(
                  label: l10n.weatherWindFieldLabel,
                  controller: _weatherWindController,
                  suffix: windUnit,
                  decimal: false,
                ),
                _numericField(
                  label: l10n.weatherPrecipFieldLabel,
                  controller: _weatherPrecipController,
                  suffix: precipUnit,
                ),
                Text(l10n.weatherConditionSectionLabel,
                    style: Theme.of(context).textTheme.labelLarge),
                const SizedBox(height: 8),
                _weatherConditionChips(l10n),
                const SizedBox(height: 10),
              ],
            ] else if (_family == ActivityFamily.machine) ...[
              _numericField(
                label: l10n.distanceFieldLabel,
                controller: _distanceController,
                suffix: distanceUnit,
              ),
              _numericField(
                label: l10n.avgWattsFieldLabel,
                controller: _avgWattsController,
                suffix: 'W',
                decimal: false,
              ),
              _numericField(
                label: l10n.avgCadenceFieldLabel,
                controller: _avgCadenceController,
                suffix: 'rpm',
                decimal: false,
              ),
              _numericField(
                label: l10n.resistanceLevelFieldLabel,
                controller: _resistanceController,
                suffix: '',
                decimal: false,
              ),
              _numericField(
                label: l10n.deviceCaloriesFieldLabel,
                controller: _deviceCaloriesController,
                suffix: 'kcal',
                decimal: false,
              ),
            ] else if (_family == ActivityFamily.game) ...[
              Text(l10n.venueSectionLabel, style: Theme.of(context).textTheme.labelLarge),
              const SizedBox(height: 8),
              SegmentedButton<String>(
                showSelectedIcon: false,
                segments: [
                  ButtonSegment(value: 'INDOOR', label: Text(l10n.venueIndoorLabel)),
                  ButtonSegment(value: 'OUTDOOR', label: Text(l10n.venueOutdoorLabel)),
                ],
                selected: _venue == null ? const {} : {_venue!},
                emptySelectionAllowed: true,
                onSelectionChanged: _submitting
                    ? null
                    : (selection) => setState(
                        () => _venue = selection.isEmpty ? null : selection.first),
              ),
              const SizedBox(height: 16),
              Text(l10n.intensitySectionLabel, style: Theme.of(context).textTheme.labelLarge),
              const SizedBox(height: 8),
              RpeSelector(
                value: _intensity,
                max: 5,
                onChanged: _submitting ? (_) {} : (v) => setState(() => _intensity = v),
              ),
              const SizedBox(height: 16),
              // C9.2/M44: the *same* stepper component the live screen uses,
              // so a hand-logged match and a counted one are entered the same
              // way — and so football gets two columns here too, without a
              // second implementation to keep in step.
              BoxScoreStepper(
                columns: [
                  BoxScoreColumn(
                    label: _activityType == 'BASKETBALL'
                        ? l10n.boxScorePointsLabel
                        : l10n.boxScoreGoalsLabel,
                    value: _scorePoints ?? 0,
                    onStep: (d) =>
                        setState(() => _scorePoints = ((_scorePoints ?? 0) + d).clamp(0, 1 << 30)),
                  ),
                  if (_activityType == 'BASKETBALL')
                    BoxScoreColumn(
                      label: l10n.boxScoreReboundsLabel,
                      value: _scoreRebounds ?? 0,
                      onStep: (d) => setState(
                          () => _scoreRebounds = ((_scoreRebounds ?? 0) + d).clamp(0, 1 << 30)),
                    ),
                  BoxScoreColumn(
                    label: l10n.boxScoreAssistsLabel,
                    value: _scoreAssists ?? 0,
                    onStep: (d) => setState(
                        () => _scoreAssists = ((_scoreAssists ?? 0) + d).clamp(0, 1 << 30)),
                  ),
                ],
                enabled: !_submitting,
                // The sheet has no idle-dismiss: it is already a deliberate,
                // post-hoc entry surface, not something open mid-match.
                onInteraction: () {},
              ),
            ],
            const SizedBox(height: 16),
            Text(l10n.postWorkoutFeedbackTitle, style: Theme.of(context).textTheme.labelLarge),
            const SizedBox(height: 8),
            RpeSelector(
              value: _rpe,
              onChanged: _submitting ? (_) {} : (v) => setState(() => _rpe = v),
              lowAnchorLabel: l10n.postWorkoutFeedbackAnchorEasy,
              highAnchorLabel: l10n.postWorkoutFeedbackAnchorMax,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _noteController,
              enabled: !_submitting,
              minLines: 1,
              maxLines: 3,
              decoration: InputDecoration(
                hintText: l10n.postWorkoutFeedbackNoteHint,
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: canSubmit ? _submit : null,
              icon: _submitting
                  ? const SizedBox(
                      height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.check),
              label: Text(l10n.saveButton),
            ),
          ],
        ),
      ),
    );
  }
}
