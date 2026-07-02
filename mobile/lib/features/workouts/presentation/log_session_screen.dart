import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/health/apple_workout.dart';
import '../../../core/health/health_controller.dart';
import '../../../core/health/health_service.dart';
import '../../../core/health/health_workout_import_service.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/widgets/app_snackbar.dart';
import '../../../shared/widgets/confirm_delete_dialog.dart';
import '../application/exercise_controller.dart';
import '../application/workout_session_controller.dart';
import '../data/workout_session_repository.dart';
import '../domain/workout_session.dart';
import '../domain/workout_template.dart';
import 'widgets/add_exercise_to_session_sheet.dart';
import 'widgets/apple_workout_picker_sheet.dart';
import 'widgets/exercise_session_card.dart';

/// Full-screen form for logging a session, or editing one when [session] is given.
///
/// Exercises are represented as [ExerciseBlock]s — one card per exercise —
/// each carrying a list of [SetRow]s. Only rows with [SetRow.doneAt] set are
/// persisted as [ExerciseSetInput]s; their values (weight/reps) don't survive
/// a session close. The *count* of rows (done + blank) is persisted as each
/// exercise's targetSets (see [_buildPlanned]), so a blank row added ad-hoc
/// still regenerates the next time the session is opened.
class LogSessionScreen extends ConsumerStatefulWidget {
  const LogSessionScreen({super.key, this.session, this.template});

  final WorkoutSession? session;
  final WorkoutTemplate? template;

  @override
  ConsumerState<LogSessionScreen> createState() => _LogSessionScreenState();
}

class _LogSessionScreenState extends ConsumerState<LogSessionScreen> {
  // Used only for formatting the Apple workout date in the pairing dialog.
  static final _label = DateFormat('EEE, MMM d · HH:mm');

  DateTime? _startedAt;
  DateTime? _finishedAt;

  /// The persisted session's clientId. Set when editing an existing session,
  /// or once a brand-new session has been created via the first [_persist].
  String? _sessionClientId;

  /// One block per planned exercise. Each block's rows are either done
  /// (doneAt set → will be persisted) or plan (doneAt null → UI only).
  final List<ExerciseBlock> _blocks = [];

  bool _saving = false;
  Timer? _ticker;
  DateTime _now = DateTime.now();

  // ── Near-live heart rate (Apple Health, running sessions only) ──
  // HealthKit doesn't stream live samples to an iPhone app: the Apple Watch
  // syncs heart-rate samples into the store in batches with a short delay, so
  // we poll the latest one. We reveal the readout as soon as a *fresh* sample
  // shows up — a sample landing this recently is itself proof the watch is
  // actively feeding live data (a workout), which is a faster and more reliable
  // signal than waiting for the value to move a few times (it never would while
  // the heart rate is steady). If the data dries up the latest sample ages past
  // the fresh window, the query returns nothing, and we hide the readout rather
  // than leaving a frozen number on screen.
  static const _kHrPollInterval = Duration(seconds: 5);
  static const _kHrFreshWindow = Duration(minutes: 2);

  Timer? _hrTicker;
  int? _currentHeartRate; // latest bpm; only shown while [_showHeartRate]
  DateTime? _lastHrSampleAt; // timestamp of the sample currently shown
  bool _showHeartRate = false;

  bool get _isEditing => widget.session != null;

  // ---------------------------------------------------------------------------
  // Init / dispose
  // ---------------------------------------------------------------------------

  @override
  void initState() {
    super.initState();
    final session = widget.session;
    // For existing sessions, start time is known. For new sessions _startedAt
    // stays null until the first set is persisted — the timer only starts then.
    _startedAt = session?.startedAt;
    _finishedAt = session?.finishedAt;

    if (session != null) {
      _sessionClientId = session.clientId;
      // Group persisted sets by exercise, sorted by performedAt.
      final setsByEx = <String, List<ExerciseSet>>{};
      for (final s in session.sets) {
        setsByEx.putIfAbsent(s.exerciseClientId, () => []).add(s);
      }
      for (final sets in setsByEx.values) {
        sets.sort((a, b) => a.performedAt.compareTo(b.performedAt));
      }
      // Build one block per SessionExercise, preserving plan order.
      for (final se in session.exercises) {
        final doneSets = setsByEx[se.exerciseClientId] ?? [];
        final rows = <SetRow>[
          for (final s in doneSets)
            SetRow(weight: s.weight, reps: s.reps, doneAt: s.performedAt),
        ];
        final remaining = (se.targetSets ?? 0) - doneSets.length;
        if (remaining > 0) {
          rows.addAll(List.generate(remaining, (_) => SetRow()));
        } else if (doneSets.isEmpty) {
          rows.add(SetRow());
        }
        _blocks.add(ExerciseBlock(
          exerciseClientId: se.exerciseClientId,
          exerciseName: se.exerciseName,
          targetSets: se.targetSets,
          rows: rows,
        ));
      }
    } else if (widget.template != null) {
      for (final te in widget.template!.exercises) {
        // Name resolved at render time from the catalog (TemplateExercise has no name).
        _blocks.add(ExerciseBlock(
          exerciseClientId: te.exerciseClientId,
          exerciseName: '',
          targetSets: te.targetSets,
          rows: _generateRows(te.targetSets),
        ));
      }
    }

    // Only start the ticker immediately when editing an existing in-progress
    // session. For new sessions the ticker starts lazily in _persist() once
    // the first set is saved.
    if (_isEditing && _finishedAt == null) {
      _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted) setState(() => _now = DateTime.now());
      });
      _hrTicker = Timer.periodic(_kHrPollInterval, (_) => _pollHeartRate());
      _pollHeartRate(); // don't wait a full interval for the first read
    }

    unawaited(_loadPreviousPerformance(_blocks));
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _hrTicker?.cancel();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // Near-live heart rate
  // ---------------------------------------------------------------------------

  /// Polls Apple Health for the latest heart-rate sample. A sample that landed
  /// within [_kHrFreshWindow] counts as live and is shown immediately; once the
  /// freshest sample ages past that window the watch has stopped feeding us
  /// data, so we hide the readout instead of leaving a stale value on screen.
  /// No-ops on Android, when the session is finished, or when the user hasn't
  /// enabled the Apple Health connection.
  Future<void> _pollHeartRate() async {
    if (!mounted || _finishedAt != null) return;
    final enabled = ref.read(appleHealthControllerProvider).value ?? false;
    if (!enabled) return;

    final sample = await ref
        .read(healthServiceProvider)
        .latestHeartRate(within: _kHrFreshWindow);
    if (!mounted) return;

    // No fresh sample → the watch isn't syncing live data right now. Hide a
    // previously shown value rather than leaving it frozen on screen.
    if (sample == null) {
      if (_showHeartRate) setState(() => _showHeartRate = false);
      return;
    }

    // Skip if HealthKit handed us the same sample again (no new data synced).
    if (_lastHrSampleAt != null &&
        !sample.timestamp.isAfter(_lastHrSampleAt!)) {
      return;
    }
    _lastHrSampleAt = sample.timestamp;

    setState(() {
      _currentHeartRate = sample.bpm.round();
      _showHeartRate = true;
    });
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  List<SetRow> _generateRows(int? targetSets) {
    final count = (targetSets != null && targetSets > 0) ? targetSets : 1;
    return List.generate(count, (_) => SetRow());
  }

  /// clientId of the template this session was (or is being) started from,
  /// whether it's a brand-new session or one already being edited.
  String? get _templateClientId =>
      widget.template?.clientId ?? widget.session?.templateClientId;

  /// Fetches and fills in [ExerciseBlock.previousSets] for each of [blocks],
  /// so the exercise cards can show what was done last time. Fire-and-forget
  /// from initState / after adding an exercise — not awaited by callers.
  Future<void> _loadPreviousPerformance(List<ExerciseBlock> blocks) async {
    final repo = ref.read(workoutSessionRepositoryProvider);
    final templateClientId = _templateClientId;
    for (final block in blocks) {
      final previous = await repo.getPreviousPerformance(
        exerciseClientId: block.exerciseClientId,
        templateClientId: templateClientId,
        excludeSessionClientId: _sessionClientId,
      );
      if (!mounted) return;
      setState(() => block.previousSets = previous);
    }
  }

  DateTime? _lastDoneAt() {
    DateTime? last;
    for (final block in _blocks) {
      for (final row in block.rows) {
        if (row.doneAt != null && (last == null || row.doneAt!.isAfter(last))) {
          last = row.doneAt;
        }
      }
    }
    return last;
  }

  String _formatElapsed() {
    if (_startedAt == null) return '0:00';
    final duration = (_finishedAt ?? _now).difference(_startedAt!);
    final h = duration.inHours;
    final m = duration.inMinutes % 60;
    final s = duration.inSeconds % 60;
    if (h > 0) {
      return '$h:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
    }
    return '$m:${s.toString().padLeft(2, '0')}';
  }

  /// targetSets here means "how many rows (done + blank) this exercise has
  /// right now", not the original template goal — so a blank row added via
  /// "+ add set" or removed via the delete icon regenerates correctly next
  /// time the session reopens, instead of always reverting to the template's
  /// original set count.
  List<PlannedExerciseInput> _buildPlanned() => _blocks
      .map((b) => PlannedExerciseInput(
            exerciseClientId: b.exerciseClientId,
            targetSets: b.rows.length,
          ))
      .toList();

  // Only rows with both reps and weight filled in count as a real set — a
  // row can be `isDone` (doneAt set) while still missing one of these, e.g.
  // if a stale autosave fires between marking a row done and the editor
  // sheet returning a value. Such rows are dropped here rather than sent
  // with a coalesced 0, which the backend would otherwise have to reject or
  // silently discard itself.
  List<ExerciseSetInput> _buildSets() => [
        for (final block in _blocks)
          for (final row in block.rows)
            if (row.isDone && row.reps != null && row.reps! > 0 && row.weight != null)
              ExerciseSetInput(
                exerciseClientId: block.exerciseClientId,
                reps: row.reps!,
                weight: row.weight!,
                performedAt: row.doneAt!,
              ),
      ];

  void _navigateToDashboard() {
    context.go('/dashboard');
    Navigator.of(context).pop();
  }

  // ---------------------------------------------------------------------------
  // Block / row mutations
  // ---------------------------------------------------------------------------

  void _handleRowMarkDone(int bi, int ri) {
    setState(() => _blocks[bi].rows[ri].doneAt = DateTime.now());
    _autoSave();
  }

  void _handleRowReopen(int bi, int ri) {
    setState(() => _blocks[bi].rows[ri].doneAt = null);
    _autoSave();
  }

  void _handleRowEdit(int bi, int ri, double? weight, int? reps) {
    setState(() {
      _blocks[bi].rows[ri].weight = weight;
      _blocks[bi].rows[ri].reps = reps;
      _blocks[bi].rows[ri].doneAt ??= DateTime.now();
    });
    _autoSave();
  }

  void _handleRowDelete(int bi, int ri) {
    setState(() => _blocks[bi].rows.removeAt(ri));
    if (_sessionClientId != null) _autoSave();
  }

  void _handleRowDuplicate(int bi, int ri) {
    final row = _blocks[bi].rows[ri];
    final nextIdx = ri + 1;
    setState(() {
      if (nextIdx < _blocks[bi].rows.length &&
          _blocks[bi].rows[nextIdx].weight == null &&
          _blocks[bi].rows[nextIdx].reps == null) {
        _blocks[bi].rows[nextIdx].weight = row.weight;
        _blocks[bi].rows[nextIdx].reps = row.reps;
      } else {
        _blocks[bi]
            .rows
            .insert(nextIdx, SetRow(weight: row.weight, reps: row.reps));
      }
    });
    _autoSave();
  }

  void _handleAddSet(int bi, {bool prefillFromPrevious = false}) {
    setState(() {
      final block = _blocks[bi];
      PreviousSetHint? hint;
      if (prefillFromPrevious && block.rows.length < block.previousSets.length) {
        hint = block.previousSets[block.rows.length];
      }
      block.rows.add(SetRow(weight: hint?.weight, reps: hint?.reps));
    });
    if (_sessionClientId != null) _autoSave();
  }

  Future<void> _handleRemoveExercise(int bi) async {
    final hasDone = _blocks[bi].rows.any((r) => r.isDone);
    if (hasDone) {
      final l10n = AppLocalizations.of(context)!;
      final confirmed = await showAppConfirmDialog(
        context,
        title: l10n.removeExerciseTitle,
        message: l10n.removeExerciseConfirmMessage,
        confirmLabel: l10n.removeButton,
        cancelLabel: l10n.cancelButton,
        icon: Icons.remove_circle_rounded,
        accentColor: const Color(0xFFD66B5A),
      );
      if (confirmed != true || !mounted) return;
    }
    setState(() => _blocks.removeAt(bi));
    if (_sessionClientId != null) await _autoSave();
  }

  Future<void> _handleAddExercise() async {
    final excluded = {for (final b in _blocks) b.exerciseClientId};
    final draft = await showModalBottomSheet<PlannedExerciseDraft>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => AddExerciseToSessionSheet(excludeIds: excluded),
    );
    if (draft == null || !mounted) return;
    final block = ExerciseBlock(
      exerciseClientId: draft.exercise.clientId,
      exerciseName: draft.exercise.name,
      targetSets: draft.targetSets,
      rows: _generateRows(draft.targetSets),
    );
    setState(() => _blocks.add(block));
    unawaited(_loadPreviousPerformance([block]));
    if (_sessionClientId != null) await _autoSave();
  }

  // ---------------------------------------------------------------------------
  // Persistence
  // ---------------------------------------------------------------------------

  Future<void> _autoSave() async {
    if (_saving) return;
    setState(() => _saving = true);
    final l10n = AppLocalizations.of(context)!;
    try {
      await _persist();
    } catch (_) {
      if (mounted) {
        AppSnackbar.showError(context, title: l10n.couldNotSaveSessionMessage);
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _persist() async {
    final notifier = ref.read(workoutSessionControllerProvider.notifier);
    final existingId = _sessionClientId;
    if (existingId == null) {
      // Don't create the session until at least one set is logged, unless we
      // are finishing (finishedAt != null means the user explicitly hit Finish).
      if (_buildSets().isEmpty && _finishedAt == null) return;

      // First real save: stamp the start time now and kick off the ticker.
      if (_startedAt == null) {
        _startedAt = DateTime.now();
        if (_finishedAt == null) {
          setState(() {});
          _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
            if (mounted) setState(() => _now = DateTime.now());
          });
          _hrTicker = Timer.periodic(_kHrPollInterval, (_) => _pollHeartRate());
          _pollHeartRate();
        }
      }

      _sessionClientId = await notifier.logSession(
        startedAt: _startedAt!,
        finishedAt: _finishedAt,
        exercises: _buildPlanned(),
        sets: _buildSets(),
        templateClientId: widget.template?.clientId,
        templateName: widget.template?.name,
      );
    } else {
      await notifier.updateSession(
        existingId,
        startedAt: _startedAt!,
        finishedAt: _finishedAt,
        exercises: _buildPlanned(),
        sets: _buildSets(),
      );
    }
  }

  /// Stamps finishedAt = now, stops the ticker, and persists.
  /// Does NOT navigate — the caller decides where to go.
  Future<void> _persistFinished() async {
    _finishedAt = DateTime.now();
    // If no set was ever logged, start = finish (session was created via Finish).
    _startedAt ??= _finishedAt;
    _ticker?.cancel();
    _ticker = null;
    _hrTicker?.cancel();
    _hrTicker = null;
    await _persist();
  }

  /// Finish button handler — implements the full 5.6 Apple Health flow.
  Future<void> _finishWorkout() async {
    if (_saving) return;
    setState(() => _saving = true);
    final l10n = AppLocalizations.of(context)!;
    final importService = ref.read(healthWorkoutImportServiceProvider);

    try {
      final appleEnabled =
          ref.read(appleHealthControllerProvider).value ?? false;

      if (!appleEnabled) {
        await _persistFinished();
        if (!mounted) return;
        _navigateToDashboard();
        return;
      }

      // Apple Health is enabled — search for an importable workout.
      final AppleWorkout? workout = await importService.findImportable();
      if (!mounted) return;

      if (workout != null) {
        // Pairing dialog.
        final pair = await showAppConfirmDialog(
          context,
          title: l10n.pairAppleWorkoutTitle,
          message: l10n.pairAppleWorkoutMessage(
            _label.format(workout.startDate.toLocal()),
            workout.activeCalories?.round().toString() ?? '–',
            workout.averageHeartRate?.round().toString() ?? '–',
          ),
          confirmLabel: l10n.pairAndFinishButton,
          cancelLabel: l10n.finishWithoutPairingButton,
          icon: Icons.link_rounded,
          barrierDismissible: false,
        );
        if (!mounted || pair == null) return; // barrier dismiss = stay
        await _persistFinished();
        if (!mounted) return;
        if (pair) {
          await importService.importInto(
            sessionClientId: _sessionClientId!,
            startedAt: _startedAt!,
            exercises: _buildPlanned(),
            sets: _buildSets(),
            workout: workout,
          );
          if (!mounted) return;
        }
        _navigateToDashboard();
      } else {
        // No Apple workout found — dialog instead of snackbar.
        final finish = await showAppConfirmDialog(
          context,
          title: l10n.noAppleWorkoutTitle,
          message: l10n.noAppleWorkoutMessage,
          confirmLabel: l10n.finishAnywayButton,
          cancelLabel: l10n.cancelButton,
          icon: Icons.fitness_center_rounded,
          barrierDismissible: false,
        );
        if (!mounted || finish != true) return; // Cancel = stay
        await _persistFinished();
        if (!mounted) return;
        _navigateToDashboard();
      }
    } catch (_) {
      if (mounted) {
        AppSnackbar.showError(context, title: l10n.couldNotSaveSessionMessage);
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  /// Manual "Import from Apple Health" action for a session that's already
  /// been closed and isn't paired yet — covers finishing the Lifey session
  /// before the Apple Watch workout itself ended, so [_finishWorkout]'s
  /// same-moment auto-match found nothing. Opens a picker over the last two
  /// weeks of unpaired strength workouts rather than re-running the narrow
  /// auto-match.
  Future<void> _importFromAppleHealthManually() async {
    if (_saving || _sessionClientId == null) return;
    setState(() => _saving = true);
    final l10n = AppLocalizations.of(context)!;
    final importService = ref.read(healthWorkoutImportServiceProvider);

    try {
      final candidates = await importService.findImportableCandidates();
      if (!mounted) return;

      final workout = await showModalBottomSheet<AppleWorkout>(
        context: context,
        useRootNavigator: true,
        isScrollControlled: true,
        showDragHandle: true,
        builder: (_) => AppleWorkoutPickerSheet(candidates: candidates),
      );
      if (workout == null || !mounted) return;

      final confirm = await showAppConfirmDialog(
        context,
        title: l10n.pairAppleWorkoutTitle,
        message: l10n.pairAppleWorkoutMessage(
          _label.format(workout.startDate.toLocal()),
          workout.activeCalories?.round().toString() ?? '–',
          workout.averageHeartRate?.round().toString() ?? '–',
        ),
        confirmLabel: l10n.pairButton,
        cancelLabel: l10n.cancelButton,
        icon: Icons.link_rounded,
      );
      if (confirm != true || !mounted) return;

      await importService.importInto(
        sessionClientId: _sessionClientId!,
        startedAt: _startedAt!,
        exercises: _buildPlanned(),
        sets: _buildSets(),
        workout: workout,
      );
      if (!mounted) return;
      AppSnackbar.showSuccess(context, title: l10n.workoutPairedWithHealthMessage);
      Navigator.of(context).pop();
    } catch (_) {
      if (mounted) {
        AppSnackbar.showError(context, title: l10n.couldNotSaveSessionMessage);
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  // ---------------------------------------------------------------------------
  // Top bar
  // ---------------------------------------------------------------------------

  Widget _buildTopBar(BuildContext context, ColorScheme scheme,
      AppLocalizations l10n, String title) {
    return Container(
      height: 58,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.30),
            blurRadius: 22,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: Container(
            color: scheme.surfaceContainer.withValues(alpha: 0.92),
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: [
                GestureDetector(
                  onTap: () => Navigator.of(context).pop(),
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: scheme.surfaceContainerLowest,
                      borderRadius: BorderRadius.circular(13),
                    ),
                    child: Center(
                      child: Icon(Icons.arrow_back,
                          size: 22, color: scheme.onSurfaceVariant),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: 'PlusJakartaSans',
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      color: scheme.onSurface,
                      letterSpacing: -0.3,
                    ),
                  ),
                ),
                if (_startedAt != null) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                    decoration: BoxDecoration(
                      color: scheme.surfaceContainerLowest,
                      borderRadius: BorderRadius.circular(13),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.timer, size: 18, color: scheme.primary),
                        const SizedBox(width: 6),
                        Text(
                          _formatElapsed(),
                          style: TextStyle(
                            fontFamily: 'PlusJakartaSans',
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: scheme.onSurface,
                            fontFeatures: const [FontFeature.tabularFigures()],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                // Near-live heart rate, shown while a fresh sample is arriving.
                if (_showHeartRate && _currentHeartRate != null) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                    decoration: BoxDecoration(
                      color: scheme.surfaceContainerLowest,
                      borderRadius: BorderRadius.circular(13),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.favorite,
                            size: 18, color: context.metricColors.heart),
                        const SizedBox(width: 6),
                        Text(
                          '$_currentHeartRate',
                          style: TextStyle(
                            fontFamily: 'PlusJakartaSans',
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: scheme.onSurface,
                            fontFeatures: const [FontFeature.tabularFigures()],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final template = widget.template;
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;

    // Resolve exercise names for template-seeded blocks (TemplateExercise has no name).
    final exercisesById = ref.watch(exerciseControllerProvider).maybeWhen(
          data: (list) => {for (final e in list) e.clientId: e},
          orElse: () => const {},
        );
    for (final block in _blocks) {
      if (block.exerciseName.isEmpty) {
        block.exerciseName = exercisesById[block.exerciseClientId]?.name ?? '';
      }
    }

    final lastDoneAt = _lastDoneAt();
    final safeBottom = MediaQuery.paddingOf(context).bottom;
    final statusTop = MediaQuery.paddingOf(context).top;
    final barTop = statusTop + 8.0;
    const restBannerHeight = 50.0;
    final restBannerVisible = _finishedAt == null && lastDoneAt != null;
    final restBannerTop = barTop + 58.0 + 8.0;
    final contentTop = restBannerVisible
        ? restBannerTop + restBannerHeight + 8.0
        : barTop + 58.0 + 8.0;

    // Finish button is only shown for running (not-yet-finished) sessions.
    final showFinishButton = _finishedAt == null;
    // Manual pairing action for a session that's already closed but wasn't
    // paired with an Apple workout at finish time (e.g. the Apple Watch
    // workout was still running when Lifey's session was closed).
    final appleHealthEnabled = ref.watch(appleHealthControllerProvider).value ?? false;
    final showImportAppleHealthButton = _isEditing &&
        _finishedAt != null &&
        !(widget.session?.fromAppleHealth ?? false) &&
        appleHealthEnabled &&
        ref.read(healthServiceProvider).isAvailable;
    // ListView needs extra bottom room so content isn't hidden behind the sticky button.
    final listBottomPad = (showFinishButton || showImportAppleHealthButton)
        ? (safeBottom + 24 + 54 + 16)
        : (safeBottom + 16);

    final title = _isEditing
        ? (widget.session!.templateName ?? l10n.editWorkoutTitle)
        : (template != null ? template.name : l10n.logWorkoutTitle);

    return Scaffold(
      body: Stack(
        children: [
          // ── Scrollable content ──
          ListView(
            padding: EdgeInsets.fromLTRB(16, contentTop, 16, listBottomPad),
            children: [
              // Health stat cards (Apple-imported finished sessions only).
              if (widget.session?.finishedAt != null &&
                  widget.session!.fromAppleHealth) ...[
                Row(
                  children: [
                    Expanded(
                      child: _HealthStatCard(
                        icon: Icons.local_fire_department,
                        iconColor: context.metricColors.calories,
                        value: widget.session!.activeCalories
                                ?.round()
                                .toString() ??
                            '–',
                        label: l10n.activeKcalLabel,
                      ),
                    ),
                    const SizedBox(width: 11),
                    Expanded(
                      child: _HealthStatCard(
                        icon: Icons.favorite,
                        iconColor: context.metricColors.heart,
                        value: widget.session!.averageHeartRate
                                ?.round()
                                .toString() ??
                            '–',
                        label: l10n.avgBpmLabel,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 13),
              ],

              // Exercise cards.
              for (int bi = 0; bi < _blocks.length; bi++) ...[
                ExerciseSessionCard(
                  key: ValueKey(_blocks[bi].exerciseClientId),
                  block: _blocks[bi],
                  onRowMarkDone: (ri) => _handleRowMarkDone(bi, ri),
                  onRowReopen: (ri) => _handleRowReopen(bi, ri),
                  onRowEdit: (ri, w, r) => _handleRowEdit(bi, ri, w, r),
                  onRowDelete: (ri) => _handleRowDelete(bi, ri),
                  onRowDuplicate: (ri) => _handleRowDuplicate(bi, ri),
                  onAddSet: (prefill) =>
                      _handleAddSet(bi, prefillFromPrevious: prefill),
                  onRemoveExercise: () => _handleRemoveExercise(bi),
                ),
                const SizedBox(height: 13),
              ],

              // Dashed "Add exercise" button.
              _AddExerciseButton(onTap: _handleAddExercise, scheme: scheme),
            ],
          ),

          // ── Floating top bar ──
          Positioned(
            top: barTop,
            left: 12,
            right: 12,
            child: _buildTopBar(context, scheme, l10n, title),
          ),

          // ── Pinned rest banner ──
          if (restBannerVisible)
            Positioned(
              top: restBannerTop,
              left: 16,
              right: 16,
              child: _RestBanner(lastSetAt: lastDoneAt!, now: _now),
            ),

          // ── Sticky "Finish workout" button ──
          if (showFinishButton)
            Positioned(
              bottom: safeBottom + 24,
              left: 16,
              right: 16,
              child: SizedBox(
                height: 54,
                child: FilledButton.icon(
                  onPressed: _saving ? null : _finishWorkout,
                  style: FilledButton.styleFrom(
                    backgroundColor: scheme.primary,
                    foregroundColor: scheme.onPrimary,
                    disabledBackgroundColor:
                        scheme.primary.withValues(alpha: 0.6),
                    disabledForegroundColor:
                        scheme.onPrimary.withValues(alpha: 0.7),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                    textStyle: const TextStyle(
                      fontFamily: 'PlusJakartaSans',
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  icon: _saving
                      ? SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: scheme.onPrimary.withValues(alpha: 0.7),
                          ),
                        )
                      : const Icon(Icons.check, size: 20),
                  label: Text(l10n.finishWorkoutButton),
                ),
              ),
            ),

          // ── Sticky "Import from Apple Health" button (closed, unpaired session) ──
          if (showImportAppleHealthButton)
            Positioned(
              bottom: safeBottom + 24,
              left: 16,
              right: 16,
              child: SizedBox(
                height: 54,
                child: FilledButton.icon(
                  onPressed: _saving ? null : _importFromAppleHealthManually,
                  style: FilledButton.styleFrom(
                    backgroundColor: scheme.primary,
                    foregroundColor: scheme.onPrimary,
                    disabledBackgroundColor:
                        scheme.primary.withValues(alpha: 0.6),
                    disabledForegroundColor:
                        scheme.onPrimary.withValues(alpha: 0.7),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                    textStyle: const TextStyle(
                      fontFamily: 'PlusJakartaSans',
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  icon: _saving
                      ? SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: scheme.onPrimary.withValues(alpha: 0.7),
                          ),
                        )
                      : const Icon(Icons.link_rounded, size: 20),
                  label: Text(l10n.importFromAppleHealthButton),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Dashed "Add exercise" button
// ---------------------------------------------------------------------------

class _AddExerciseButton extends StatelessWidget {
  const _AddExerciseButton({required this.onTap, required this.scheme});

  final VoidCallback onTap;
  final ColorScheme scheme;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: CustomPaint(
        painter: _DashedBorderPainter(
          color: scheme.outline,
          radius: AppRadius.input,
          strokeWidth: 1.5,
        ),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.input),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.add, size: 21, color: scheme.onSurfaceVariant),
              const SizedBox(width: 7),
              Text(
                AppLocalizations.of(context)!.addExerciseTitle,
                style: TextStyle(
                  fontFamily: 'PlusJakartaSans',
                  fontSize: 13.5,
                  fontWeight: FontWeight.w700,
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

class _DashedBorderPainter extends CustomPainter {
  const _DashedBorderPainter({
    required this.color,
    required this.radius,
    required this.strokeWidth,
  });

  final Color color;
  final double radius;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final inset = strokeWidth / 2;
    final rrect = RRect.fromRectAndRadius(
      Rect.fromLTWH(
          inset, inset, size.width - strokeWidth, size.height - strokeWidth),
      Radius.circular(radius),
    );
    const dashLen = 7.0;
    const gapLen = 5.0;

    for (final metric in (Path()..addRRect(rrect)).computeMetrics()) {
      var distance = 0.0;
      var drawing = true;
      while (distance < metric.length) {
        final next =
            (distance + (drawing ? dashLen : gapLen)).clamp(0.0, metric.length);
        if (drawing) canvas.drawPath(metric.extractPath(distance, next), paint);
        distance = next;
        drawing = !drawing;
      }
    }
  }

  @override
  bool shouldRepaint(_DashedBorderPainter old) =>
      old.color != color ||
      old.strokeWidth != strokeWidth ||
      old.radius != radius;
}

// ---------------------------------------------------------------------------
// Rest banner
// ---------------------------------------------------------------------------

class _RestBanner extends StatelessWidget {
  const _RestBanner({required this.lastSetAt, required this.now});

  final DateTime lastSetAt;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final elapsed = now.difference(lastSetAt);
    final m = elapsed.inMinutes;
    final s = (elapsed.inSeconds % 60).toString().padLeft(2, '0');

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
      decoration: BoxDecoration(
        color: scheme.primary.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(AppRadius.input),
        border: Border.all(color: scheme.primary.withValues(alpha: 0.40)),
      ),
      child: Row(
        children: [
          Icon(Icons.hourglass_top, size: 22, color: scheme.primary),
          const SizedBox(width: 10),
          Text(
            AppLocalizations.of(context)!.restLabel,
            style: TextStyle(
              fontFamily: 'PlusJakartaSans',
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: scheme.onSurface,
            ),
          ),
          const Spacer(),
          Text(
            '$m:$s',
            style: TextStyle(
              fontFamily: 'PlusJakartaSans',
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: scheme.primary,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Health stat card (active kcal / avg bpm)
// ---------------------------------------------------------------------------

class _HealthStatCard extends StatelessWidget {
  const _HealthStatCard({
    required this.icon,
    required this.iconColor,
    required this.value,
    required this.label,
  });

  final IconData icon;
  final Color iconColor;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 13),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(AppRadius.input),
      ),
      child: Row(
        children: [
          Icon(icon, size: 21, color: iconColor),
          const SizedBox(width: 9),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                value,
                style: TextStyle(
                  fontFamily: 'PlusJakartaSans',
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: scheme.onSurface,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
              Text(
                label,
                style: TextStyle(
                  fontFamily: 'PlusJakartaSans',
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: scheme.onSurfaceVariant.withValues(alpha: 0.6),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
