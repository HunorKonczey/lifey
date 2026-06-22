import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../l10n/app_localizations.dart';
import '../../application/exercise_controller.dart';
import '../../domain/exercise.dart';

/// Result of adding a set: an exercise with reps and weight.
typedef SetDraft = ({Exercise exercise, int reps, double weight});

/// Bottom sheet to add a set (exercise + reps + weight). Pops with a [SetDraft].
/// Pass [initialExercise] to pre-select it (e.g. when adding a template
/// exercise) and/or [initialReps]/[initialWeight] to pre-fill the numeric
/// fields (e.g. when double-tapping an existing set to log another one like
/// it — only the timestamp is deliberately not pre-filled there, since it's
/// stamped fresh on submit).
class AddSetSheet extends ConsumerStatefulWidget {
  const AddSetSheet({super.key, this.initialExercise, this.initialReps, this.initialWeight});

  final Exercise? initialExercise;
  final int? initialReps;
  final double? initialWeight;

  @override
  ConsumerState<AddSetSheet> createState() => _AddSetSheetState();
}

class _AddSetSheetState extends ConsumerState<AddSetSheet> {
  final _formKey = GlobalKey<FormState>();
  late final _reps = TextEditingController(text: widget.initialReps?.toString() ?? '');
  late final _weight = TextEditingController(text: widget.initialWeight?.toString() ?? '');
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
    final l10n = AppLocalizations.of(context)!;

    return Padding(
      padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + viewInsets),
      child: exercisesState.when(
        loading: () => const Padding(
          padding: EdgeInsets.all(24),
          child: Center(child: CircularProgressIndicator()),
        ),
        error: (e, _) => Padding(
          padding: const EdgeInsets.all(24),
          child: Text('${l10n.couldNotLoadExercisesPrefix} $e'),
        ),
        data: (exercises) {
          if (exercises.isEmpty) {
            return Padding(
              padding: const EdgeInsets.all(24),
              child: Text(l10n.noExercisesAvailableMessage),
            );
          }
          return Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(l10n.addSetTitle, style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 16),
                DropdownButtonFormField<Exercise>(
                  initialValue: _exercise,
                  isExpanded: true,
                  decoration: InputDecoration(
                    labelText: l10n.exerciseLabel,
                    border: const OutlineInputBorder(),
                  ),
                  items: exercises
                      .map((e) =>
                          DropdownMenuItem(value: e, child: Text(e.name)))
                      .toList(),
                  onChanged: (e) => setState(() => _exercise = e),
                  validator: (e) => e == null ? l10n.pickAnExerciseError : null,
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _reps,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          labelText: l10n.repsLabel,
                          border: const OutlineInputBorder(),
                        ),
                        validator: (v) {
                          final parsed = int.tryParse((v ?? '').trim());
                          if (parsed == null) return l10n.enterANumberError;
                          if (parsed <= 0) return l10n.mustBeGreaterThanZeroShortError;
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
                        decoration: InputDecoration(
                          labelText: l10n.weightLabel,
                          suffixText: 'kg',
                          border: const OutlineInputBorder(),
                        ),
                        validator: (v) {
                          final parsed =
                              double.tryParse((v ?? '').replaceAll(',', '.'));
                          if (parsed == null) return l10n.enterANumberError;
                          if (parsed < 0) return l10n.mustBeZeroOrMoreError;
                          return null;
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                FilledButton(onPressed: _submit, child: Text(l10n.addButton)),
              ],
            ),
          );
        },
      ),
    );
  }
}
