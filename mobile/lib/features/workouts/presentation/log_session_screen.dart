import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/health/apple_workout.dart';
import '../../../core/health/health_controller.dart';
import '../../../core/health/health_workout_import_service.dart';
import '../../../l10n/app_localizations.dart';
import '../application/exercise_controller.dart';
import '../application/workout_session_controller.dart';
import '../data/workout_session_repository.dart';
import '../domain/exercise.dart';
import '../domain/workout_session.dart';
import '../domain/workout_template.dart';
import 'widgets/add_exercise_to_session_sheet.dart';
import 'widgets/add_set_sheet.dart';

/// Full-screen form for logging a session, or editing one when [session] is given.
///
/// When [template] is given (starting a fresh session from it), the template's
/// exercises are added to the session immediately as quick-add chips — no set
/// needs to be logged for an exercise for it to be "in" the session. When
/// [session] is given (resuming/editing), the session's own persisted planned
/// exercises (`session.exercises`) are used instead, so this works the same
/// whether or not the session originally came from a template.
class LogSessionScreen extends ConsumerStatefulWidget {
  const LogSessionScreen({super.key, this.session, this.template});

  final WorkoutSession? session;
  final WorkoutTemplate? template;

  @override
  ConsumerState<LogSessionScreen> createState() => _LogSessionScreenState();
}

class _LogSessionScreenState extends ConsumerState<LogSessionScreen> {
  static final _label = DateFormat('EEE, MMM d · HH:mm');

  late DateTime _startedAt;
  DateTime? _finishedAt;

  /// The persisted session's clientId. Set when editing an existing session,
  /// or once a brand-new session has been created via the first [_persist].
  /// While null, no session row exists yet for a freshly started workout.
  String? _sessionClientId;

  /// Exercises planned for this session — template-seeded and/or ad-hoc added,
  /// each carrying an optional target set count. Names are resolved at render
  /// time from the exercise master list.
  final List<PlannedExerciseInput> _planned = [];

  final List<({Exercise exercise, int reps, double weight, DateTime performedAt})> _sets = [];
  bool _saving = false;

  bool get _isEditing => widget.session != null;

  @override
  void initState() {
    super.initState();
    final session = widget.session;
    _startedAt = session?.startedAt ?? DateTime.now();
    _finishedAt = session?.finishedAt;
    if (session != null) {
      _sessionClientId = session.clientId;
      _planned.addAll(session.exercises.map((e) => PlannedExerciseInput(
            exerciseClientId: e.exerciseClientId,
            targetSets: e.targetSets,
          )));
      for (final set in session.sets) {
        // Only clientId + name are needed downstream; macros aren't sent on save.
        _sets.add((
          exercise: Exercise(clientId: set.exerciseClientId, name: set.exerciseName),
          reps: set.reps,
          weight: set.weight,
          performedAt: set.performedAt,
        ));
      }
      // Rest time is a delta between consecutive sets, so this list must
      // stay in performedAt order — also re-asserted after every mutation.
      _sets.sort((a, b) => a.performedAt.compareTo(b.performedAt));
    } else if (widget.template != null) {
      _planned.addAll(widget.template!.exercises.map((te) => PlannedExerciseInput(
            exerciseClientId: te.exerciseClientId,
            targetSets: te.targetSets,
          )));
    }
  }

  Future<DateTime?> _pickDateTime(DateTime initial) async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2000),
      lastDate: now,
    );
    if (date == null || !mounted) return null;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initial),
    );
    final picked = DateTime(date.year, date.month, date.day,
        time?.hour ?? initial.hour, time?.minute ?? initial.minute);
    return picked.isAfter(now) ? now : picked;
  }

  Future<void> _addSet({Exercise? initial}) async {
    final draft = await showModalBottomSheet<SetDraft>(
      context: context,
    useRootNavigator: true,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => AddSetSheet(initialExercise: initial),
    );
    if (draft != null) {
      setState(() {
        _sets.add((
          exercise: draft.exercise,
          reps: draft.reps,
          weight: draft.weight,
          performedAt: DateTime.now(),
        ));
        // Logging a set for an exercise implicitly plans it too, so it shows
        // up as a quick-add chip for the rest of the workout.
        if (!_planned.any((p) => p.exerciseClientId == draft.exercise.clientId)) {
          _planned.add(PlannedExerciseInput(exerciseClientId: draft.exercise.clientId));
        }
      });
      await _autoSave();
    }
  }

  /// Double-tapping a set card opens the add-set sheet pre-filled with that
  /// set's exercise/reps/weight — the fast "log another one like this"
  /// gesture. The timestamp is deliberately not pre-filled: it's stamped
  /// fresh on submit, which is also what makes consecutive-set rest time
  /// meaningful.
  Future<void> _duplicateSet(int index) async {
    final source = _sets[index];
    final draft = await showModalBottomSheet<SetDraft>(
      context: context,
    useRootNavigator: true,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => AddSetSheet(
        initialExercise: source.exercise,
        initialReps: source.reps,
        initialWeight: source.weight,
      ),
    );
    if (draft != null) {
      setState(() {
        _sets.add((
          exercise: draft.exercise,
          reps: draft.reps,
          weight: draft.weight,
          performedAt: DateTime.now(),
        ));
        if (!_planned.any((p) => p.exerciseClientId == draft.exercise.clientId)) {
          _planned.add(PlannedExerciseInput(exerciseClientId: draft.exercise.clientId));
        }
      });
      await _autoSave();
    }
  }

  /// Single-tapping a set card opens the same sheet pre-filled with that
  /// set's exercise/reps/weight, but edits it in place rather than adding a
  /// new one — the timestamp (and therefore rest-time math) is left
  /// untouched.
  Future<void> _editSet(int index) async {
    final source = _sets[index];
    final draft = await showModalBottomSheet<SetDraft>(
      context: context,
    useRootNavigator: true,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => AddSetSheet(
        initialExercise: source.exercise,
        initialReps: source.reps,
        initialWeight: source.weight,
        isEditing: true,
      ),
    );
    if (draft != null) {
      setState(() {
        _sets[index] = (
          exercise: draft.exercise,
          reps: draft.reps,
          weight: draft.weight,
          performedAt: source.performedAt,
        );
        if (!_planned.any((p) => p.exerciseClientId == draft.exercise.clientId)) {
          _planned.add(PlannedExerciseInput(exerciseClientId: draft.exercise.clientId));
        }
      });
      await _autoSave();
    }
  }

  /// Persists in the background right after an in-place edit (e.g. logging a
  /// set), so nothing is lost if the user closes the app mid-workout. Reuses
  /// the same _saving + snackbar pattern as the top Save button — guarding on
  /// it avoids racing a manual save, and resetting it in `finally` means the
  /// top button is only briefly disabled rather than stuck. Never navigates.
  Future<void> _autoSave() async {
    if (_saving) return;
    setState(() => _saving = true);
    final messenger = ScaffoldMessenger.of(context);
    final l10n = AppLocalizations.of(context)!;
    try {
      await _persist();
      messenger.showSnackBar(
        SnackBar(
          content: Text(l10n.sessionAutoSavedMessage),
          duration: const Duration(seconds: 1),
          behavior: SnackBarBehavior.floating,
          width: 160,
        ),
      );
    } catch (_) {
      messenger.showSnackBar(SnackBar(content: Text(l10n.couldNotSaveSessionMessage)));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _addPlannedExercise() async {
    final draft = await showModalBottomSheet<PlannedExerciseDraft>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => AddExerciseToSessionSheet(
        excludeIds: {for (final p in _planned) p.exerciseClientId},
      ),
    );
    if (draft != null) {
      setState(() => _planned.add(PlannedExerciseInput(
            exerciseClientId: draft.exercise.clientId,
            targetSets: draft.targetSets,
          )));
      if (_sessionClientId != null) await _autoSave();
    }
  }

  /// Persists the current form state: creates the session on the first call
  /// (caching its clientId in [_sessionClientId]) or updates the existing one
  /// thereafter. No UI side effects — throws on failure for callers to handle.
  Future<void> _persist() async {
    final sets = _sets
        .map((s) => ExerciseSetInput(
            exerciseClientId: s.exercise.clientId,
            reps: s.reps,
            weight: s.weight,
            performedAt: s.performedAt))
        .toList();
    final notifier = ref.read(workoutSessionControllerProvider.notifier);
    final existingId = _sessionClientId;
    if (existingId == null) {
      _sessionClientId = await notifier.logSession(
          startedAt: _startedAt,
          finishedAt: _finishedAt,
          exercises: _planned,
          sets: sets);
    } else {
      await notifier.updateSession(existingId,
          startedAt: _startedAt,
          finishedAt: _finishedAt,
          exercises: _planned,
          sets: sets);
    }
  }

  /// Manual "Import from Apple Health": reads the just-finished Apple strength
  /// workout, confirms with the user, then closes + enriches THIS session with
  /// its calories / avg HR. Only offered while this is an in-progress session
  /// (see the visibility gate in [build]). iOS-only via the toggle/provider.
  Future<void> _importFromAppleHealth() async {
    if (_saving) return;
    final messenger = ScaffoldMessenger.of(context);
    final l10n = AppLocalizations.of(context)!;
    final importService = ref.read(healthWorkoutImportServiceProvider);

    setState(() => _saving = true);
    try {
      final AppleWorkout? workout = await importService.findImportable();
      if (!mounted) return;
      if (workout == null) {
        messenger.showSnackBar(SnackBar(content: Text(l10n.noRecentAppleWorkoutMessage)));
        return;
      }
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(l10n.pairAppleWorkoutTitle),
          content: Text(l10n.pairAppleWorkoutMessage(
            // Full date + time, not just time-of-day: the import window is a
            // day wide now, so "Started 14:30" alone would be ambiguous about
            // which day.
            _label.format(workout.startDate.toLocal()),
            workout.activeCalories?.round().toString() ?? '–',
            workout.averageHeartRate?.round().toString() ?? '–',
          )),
          actions: [
            TextButton(
                onPressed: () => Navigator.of(ctx).pop(false), child: Text(l10n.cancelButton)),
            TextButton(
                onPressed: () => Navigator.of(ctx).pop(true), child: Text(l10n.pairButton)),
          ],
        ),
      );
      if (confirmed != true || !mounted) return;

      final sets = _sets
          .map((s) => ExerciseSetInput(
              exerciseClientId: s.exercise.clientId,
              reps: s.reps,
              weight: s.weight,
              performedAt: s.performedAt))
          .toList();
      await importService.importInto(
        sessionClientId: _sessionClientId!,
        startedAt: _startedAt,
        exercises: _planned,
        sets: sets,
        workout: workout,
      );
      // Importing always finishes the session, so land back on the dashboard
      // — and pop this screen off whichever branch's Navigator stack it was
      // pushed onto, otherwise switching back to that tab finds it waiting.
      if (mounted) {
        context.go('/dashboard');
        Navigator.of(context).pop();
      }
    } catch (_) {
      if (mounted) {
        messenger.showSnackBar(SnackBar(content: Text(l10n.couldNotSaveSessionMessage)));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _save() async {
    if (_saving) return; // guard against a fast double-tap creating two sessions
    setState(() => _saving = true);
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    final isFinishing = _finishedAt != null;
    final couldNotSaveSessionMessage = AppLocalizations.of(context)!.couldNotSaveSessionMessage;
    try {
      await _persist();
      // A finished session is done for good, so land back on the dashboard
      // rather than the list/detail screen this was pushed from — but it
      // still has to be popped off that branch's own Navigator stack too,
      // otherwise switching back to that tab later finds this screen still
      // sitting there waiting instead of the list.
      if (isFinishing) {
        if (mounted) context.go('/dashboard');
        navigator.pop();
      } else {
        navigator.pop();
      }
    } catch (_) {
      setState(() => _saving = false);
      messenger.showSnackBar(
        SnackBar(content: Text(couldNotSaveSessionMessage)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final template = widget.template;
    final l10n = AppLocalizations.of(context)!;
    final exercisesById = ref.watch(exerciseControllerProvider).maybeWhen(
          data: (list) => {for (final e in list) e.clientId: e},
          orElse: () => const <String, Exercise>{},
        );
    // Apple Health import is offered only on an in-progress, already-persisted
    // session and only when the "Connect Apple Health" toggle is on (the
    // provider is false on Android, so this is implicitly iOS-only).
    final appleHealthEnabled = ref.watch(appleHealthControllerProvider).value ?? false;
    final canImportFromHealth =
        _isEditing && _finishedAt == null && _sessionClientId != null && appleHealthEnabled;

    return Scaffold(
      appBar: AppBar(
        scrolledUnderElevation: 0,
        title: Text(_isEditing
            ? l10n.editWorkoutTitle
            : (template != null ? template.name : l10n.logWorkoutTitle)),
        actions: [
          TextButton(
            onPressed: _saving ? null : _save,
            child: _saving
                ? const SizedBox(
                    height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2))
                : Text(l10n.saveButton),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(l10n.startedLabel, style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: () async {
              final picked = await _pickDateTime(_startedAt);
              if (picked != null) {
                setState(() => _startedAt = picked);
                if (_sessionClientId != null) await _autoSave();
              }
            },
            icon: const Icon(Icons.play_arrow),
            label: Text(_label.format(_startedAt)),
          ),
          const SizedBox(height: 16),
          Text(l10n.finishedOptionalLabel,
              style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () async {
                    final picked = await _pickDateTime(_finishedAt ?? DateTime.now());
                    if (picked != null) {
                      setState(() => _finishedAt = picked);
                      // Setting a finish time finishes the workout outright —
                      // no separate Save tap needed, so persist and navigate
                      // away exactly like the Save button would.
                      await _save();
                    }
                  },
                  icon: const Icon(Icons.flag),
                  label: Text(_finishedAt == null
                      ? l10n.notSetInProgressMessage
                      : _label.format(_finishedAt!)),
                ),
              ),
              if (_finishedAt != null)
                IconButton(
                  tooltip: l10n.clearTooltip,
                  icon: const Icon(Icons.close),
                  onPressed: () async {
                    setState(() => _finishedAt = null);
                    if (_sessionClientId != null) await _autoSave();
                  },
                ),
            ],
          ),
          if (canImportFromHealth) ...[
            const SizedBox(height: 16),
            FilledButton.tonalIcon(
              onPressed: _saving ? null : _importFromAppleHealth,
              icon: const Icon(Icons.favorite),
              label: Text(l10n.importFromAppleHealthButton),
            ),
          ],
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(l10n.exercisesLabel, style: Theme.of(context).textTheme.labelLarge),
              TextButton.icon(
                onPressed: _addPlannedExercise,
                icon: const Icon(Icons.add),
                label: Text(l10n.addExerciseTitle),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(l10n.tapExerciseToLogSetMessage,
              style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 8),
          if (_planned.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(l10n.noExercisesPlannedMessage),
            )
          else
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                for (final p in _planned)
                  if (exercisesById[p.exerciseClientId] != null)
                    ActionChip(
                      avatar: const Icon(Icons.add, size: 18),
                      label: Text(
                        p.targetSets != null
                            ? '${exercisesById[p.exerciseClientId]!.name} · ${l10n.setsCountLabel(p.targetSets!)}'
                            : exercisesById[p.exerciseClientId]!.name,
                      ),
                      onPressed: () => _addSet(initial: exercisesById[p.exerciseClientId]),
                    ),
              ],
            ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(l10n.setsLabel, style: Theme.of(context).textTheme.labelLarge),
              TextButton.icon(
                onPressed: _addSet,
                icon: const Icon(Icons.add),
                label: Text(l10n.addSetTitle),
              ),
            ],
          ),
          if (_sets.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Text(l10n.noSetsAddedYetMessage),
            )
          else
            ..._sets.asMap().entries.map((entry) {
              final index = entry.key;
              final s = entry.value;
              final rest = index == 0 ? null : s.performedAt.difference(_sets[index - 1].performedAt);
              return GestureDetector(
                onTap: () => _editSet(index),
                onDoubleTap: () => _duplicateSet(index),
                child: Card(
                  elevation: 0,
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  child: ListTile(
                    title: Text(s.exercise.name),
                    subtitle: Text([
                      l10n.repsTimesWeightLabel(s.reps.toString(), s.weight.toStringAsFixed(1)),
                      if (rest != null)
                        l10n.restTimeLabel(
                          rest.inMinutes.toString(),
                          (rest.inSeconds % 60).toString().padLeft(2, '0'),
                        ),
                    ].join(' · ')),
                    trailing: IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () async {
                        setState(() => _sets.removeAt(index));
                        if (_sessionClientId != null) await _autoSave();
                      },
                    ),
                  ),
                ),
              );
            }),
        ],
      ),
    );
  }
}
