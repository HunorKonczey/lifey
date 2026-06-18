import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/exercise_controller.dart';
import '../../domain/exercise.dart';

/// Result of adding a set: an exercise with reps and weight.
typedef SetDraft = ({Exercise exercise, int reps, double weight});

/// Bottom sheet to add a set (exercise + reps + weight). Pops with a [SetDraft].
/// Pass [initialExercise] to pre-select it (e.g. when adding a template exercise).
class AddSetSheet extends ConsumerStatefulWidget {
  const AddSetSheet({super.key, this.initialExercise});

  final Exercise? initialExercise;

  @override
  ConsumerState<AddSetSheet> createState() => _AddSetSheetState();
}

class _AddSetSheetState extends ConsumerState<AddSetSheet> {
  final _formKey = GlobalKey<FormState>();
  final _reps = TextEditingController();
  final _weight = TextEditingController();
  Exercise? _exercise;

  @override
  void initState() {
    super.initState();
    _exercise = widget.initialExercise;
  }

  @override
  void dispose() {
    _reps.dispose();
    _weight.dispose();
    super.dispose();
  }

  void _submit() {
    if (_exercise == null) return;
    if (!_formKey.currentState!.validate()) return;
    Navigator.of(context).pop<SetDraft>((
      exercise: _exercise!,
      reps: int.parse(_reps.text.trim()),
      weight: double.parse(_weight.text.replaceAll(',', '.')),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final exercisesState = ref.watch(exerciseControllerProvider);
    final viewInsets = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + viewInsets),
      child: exercisesState.when(
        loading: () => const Padding(
          padding: EdgeInsets.all(24),
          child: Center(child: CircularProgressIndicator()),
        ),
        error: (e, _) => Padding(
          padding: const EdgeInsets.all(24),
          child: Text("Couldn't load exercises: $e"),
        ),
        data: (exercises) {
          if (exercises.isEmpty) {
            return const Padding(
              padding: EdgeInsets.all(24),
              child: Text('No exercises available.'),
            );
          }
          return Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('Add set', style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 16),
                DropdownButtonFormField<Exercise>(
                  initialValue: _exercise,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Exercise',
                    border: OutlineInputBorder(),
                  ),
                  items: exercises
                      .map((e) =>
                          DropdownMenuItem(value: e, child: Text(e.name)))
                      .toList(),
                  onChanged: (e) => setState(() => _exercise = e),
                  validator: (e) => e == null ? 'Pick an exercise' : null,
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _reps,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Reps',
                          border: OutlineInputBorder(),
                        ),
                        validator: (v) {
                          final parsed = int.tryParse((v ?? '').trim());
                          if (parsed == null) return 'Enter a number';
                          if (parsed <= 0) return 'Must be > 0';
                          return null;
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: _weight,
                        keyboardType:
                            const TextInputType.numberWithOptions(decimal: true),
                        decoration: const InputDecoration(
                          labelText: 'Weight',
                          suffixText: 'kg',
                          border: OutlineInputBorder(),
                        ),
                        validator: (v) {
                          final parsed =
                              double.tryParse((v ?? '').replaceAll(',', '.'));
                          if (parsed == null) return 'Enter a number';
                          if (parsed < 0) return 'Must be 0 or more';
                          return null;
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                FilledButton(onPressed: _submit, child: const Text('Add')),
              ],
            ),
          );
        },
      ),
    );
  }
}
