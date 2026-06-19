import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

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

  /// Exercises planned for this session — template-seeded and/or ad-hoc added.
  /// Names are resolved at render time from the exercise master list.
  final Set<int> _plannedExerciseIds = {};

  final List<({Exercise exercise, int reps, double weight})> _sets = [];
  bool _saving = false;

  bool get _isEditing => widget.session != null;

  @override
  void initState() {
    super.initState();
    final session = widget.session;
    _startedAt = session?.startedAt ?? DateTime.now();
    _finishedAt = session?.finishedAt;
    if (session != null) {
      _plannedExerciseIds.addAll(session.exercises.map((e) => e.exerciseId));
      for (final set in session.sets) {
        // Only id + name are needed downstream; macros aren't sent on save.
        _sets.add((
          exercise: Exercise(id: set.exerciseId, name: set.exerciseName),
          reps: set.reps,
          weight: set.weight,
        ));
      }
    } else if (widget.template != null) {
      _plannedExerciseIds.addAll(widget.template!.exerciseIds);
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
        _sets.add((exercise: draft.exercise, reps: draft.reps, weight: draft.weight));
        // Logging a set for an exercise implicitly plans it too, so it shows
        // up as a quick-add chip for the rest of the workout.
        _plannedExerciseIds.add(draft.exercise.id);
      });
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
      setState(() => _plannedExerciseIds.add(exercise.id));
    }
  }

  Future<void> _save() async {
    if (_saving) return; // guard against a fast double-tap creating two sessions
    setState(() => _saving = true);
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    final sets = _sets
        .map((s) => ExerciseSetInput(
            exerciseId: s.exercise.id, reps: s.reps, weight: s.weight))
        .toList();
    try {
      final notifier = ref.read(workoutSessionControllerProvider.notifier);
      if (_isEditing) {
        await notifier.updateSession(widget.session!.id,
            startedAt: _startedAt,
            finishedAt: _finishedAt,
            exerciseIds: _plannedExerciseIds.toList(),
            sets: sets);
      } else {
        await notifier.logSession(
            startedAt: _startedAt,
            finishedAt: _finishedAt,
            exerciseIds: _plannedExerciseIds.toList(),
            sets: sets);
      }
      navigator.pop();
    } catch (_) {
      setState(() => _saving = false);
      messenger.showSnackBar(
        const SnackBar(content: Text("Couldn't save the session. Please try again.")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final template = widget.template;
    final exercisesById = ref.watch(exerciseControllerProvider).maybeWhen(
          data: (list) => {for (final e in list) e.id: e},
          orElse: () => const <int, Exercise>{},
        );

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing
            ? 'Edit workout'
            : (template != null ? template.name : 'Log workout')),
        actions: [
          TextButton(
            onPressed: _saving ? null : _save,
            child: _saving
                ? const SizedBox(
                    height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2))
                : const Text('Save'),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('Started', style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: () async {
              final picked = await _pickDateTime(_startedAt);
              if (picked != null) setState(() => _startedAt = picked);
            },
            icon: const Icon(Icons.play_arrow),
            label: Text(_label.format(_startedAt)),
          ),
          const SizedBox(height: 16),
          Text('Finished (optional)',
              style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () async {
                    final picked = await _pickDateTime(_finishedAt ?? _startedAt);
                    if (picked != null) setState(() => _finishedAt = picked);
                  },
                  icon: const Icon(Icons.flag),
                  label: Text(_finishedAt == null
                      ? 'Not set (in progress)'
                      : _label.format(_finishedAt!)),
                ),
              ),
              if (_finishedAt != null)
                IconButton(
                  tooltip: 'Clear',
                  icon: const Icon(Icons.close),
                  onPressed: () => setState(() => _finishedAt = null),
                ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Exercises', style: Theme.of(context).textTheme.labelLarge),
              TextButton.icon(
                onPressed: _addPlannedExercise,
                icon: const Icon(Icons.add),
                label: const Text('Add exercise'),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text('Tap an exercise to log a set',
              style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 8),
          if (_plannedExerciseIds.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Text('No exercises planned yet — tap "Add exercise" to add one'),
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
              Text('Sets', style: Theme.of(context).textTheme.labelLarge),
              TextButton.icon(
                onPressed: _addSet,
                icon: const Icon(Icons.add),
                label: const Text('Add set'),
              ),
            ],
          ),
          if (_sets.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Text('No sets added yet'),
            )
          else
            ..._sets.asMap().entries.map((entry) {
              final s = entry.value;
              return Card(
                elevation: 0,
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                child: ListTile(
                  title: Text(s.exercise.name),
                  subtitle: Text(
                      '${s.reps} reps · ${s.weight.toStringAsFixed(1)} kg'),
                  trailing: IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => setState(() => _sets.removeAt(entry.key)),
                  ),
                ),
              );
            }),
        ],
      ),
    );
  }
}
