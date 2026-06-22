import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

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

  /// Exercises planned for this session — template-seeded and/or ad-hoc added.
  /// Names are resolved at render time from the exercise master list.
  final Set<String> _plannedExerciseIds = {};

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
      _plannedExerciseIds.addAll(session.exercises.map((e) => e.exerciseClientId));
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
      _plannedExerciseIds.addAll(widget.template!.exerciseClientIds);
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
        _plannedExerciseIds.add(draft.exercise.clientId);
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
        _plannedExerciseIds.add(draft.exercise.clientId);
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
    final exercise = await showModalBottomSheet<Exercise>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => AddExerciseToSessionSheet(excludeIds: _plannedExerciseIds),
    );
    if (exercise != null) {
      setState(() => _plannedExerciseIds.add(exercise.clientId));
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
          exerciseClientIds: _plannedExerciseIds.toList(),
          sets: sets);
    } else {
      await notifier.updateSession(existingId,
          startedAt: _startedAt,
          finishedAt: _finishedAt,
          exerciseClientIds: _plannedExerciseIds.toList(),
          sets: sets);
    }
  }

  Future<void> _save() async {
    if (_saving) return; // guard against a fast double-tap creating two sessions
    setState(() => _saving = true);
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    final couldNotSaveSessionMessage = AppLocalizations.of(context)!.couldNotSaveSessionMessage;
    try {
      await _persist();
      navigator.pop();
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

    return Scaffold(
      appBar: AppBar(
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
                      if (_sessionClientId != null) await _autoSave();
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
          if (_plannedExerciseIds.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(l10n.noExercisesPlannedMessage),
            )
          else
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                for (final id in _plannedExerciseIds)
                  if (exercisesById[id] != null)
                    ActionChip(
                      avatar: const Icon(Icons.add, size: 18),
                      label: Text(exercisesById[id]!.name),
                      onPressed: () => _addSet(initial: exercisesById[id]),
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
