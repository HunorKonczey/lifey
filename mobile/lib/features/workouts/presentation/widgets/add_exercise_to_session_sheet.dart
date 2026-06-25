import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../l10n/app_localizations.dart';
import '../../application/exercise_controller.dart';
import '../../domain/exercise.dart';

/// Result of the exercise-add sheet: the picked exercise and optional target sets.
class PlannedExerciseDraft {
  const PlannedExerciseDraft({required this.exercise, this.targetSets});

  final Exercise exercise;
  final int? targetSets;
}

/// Bottom sheet to add an exercise to the current session's planned-exercise
/// list. Two-step flow: pick an exercise from the list, then optionally set a
/// target number of sets. Pops with [PlannedExerciseDraft] or null if dismissed.
class AddExerciseToSessionSheet extends ConsumerStatefulWidget {
  const AddExerciseToSessionSheet({super.key, required this.excludeIds});

  /// Exercise clientIds already planned — hidden from the picker list.
  final Set<String> excludeIds;

  @override
  ConsumerState<AddExerciseToSessionSheet> createState() =>
      _AddExerciseToSessionSheetState();
}

class _AddExerciseToSessionSheetState
    extends ConsumerState<AddExerciseToSessionSheet> {
  Exercise? _picked;
  int? _targetSets;

  @override
  Widget build(BuildContext context) {
    return _picked == null
        ? _buildPickStep(context)
        : _buildConfirmStep(context);
  }

  // ── Step 1: exercise list ─────────────────────────────────────────────────

  Widget _buildPickStep(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final exercisesState = ref.watch(exerciseControllerProvider);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(l10n.addExerciseTitle, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 12),
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 360),
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
                  final available = exercises
                      .where((e) => !widget.excludeIds.contains(e.clientId))
                      .toList();
                  if (available.isEmpty) {
                    return Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(l10n.everyExerciseAlreadyInSessionMessage),
                    );
                  }
                  return ListView.separated(
                    shrinkWrap: true,
                    itemCount: available.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, i) => ListTile(
                      title: Text(available[i].name),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => setState(() {
                        _picked = available[i];
                        _targetSets = null;
                      }),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Step 2: confirm + target sets ─────────────────────────────────────────

  Widget _buildConfirmStep(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    final ex = _picked!;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Back + exercise name
            Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back),
                  onPressed: () => setState(() {
                    _picked = null;
                    _targetSets = null;
                  }),
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    ex.name,
                    style: Theme.of(context).textTheme.titleLarge,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Target sets counter
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: scheme.surfaceContainerHigh,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      l10n.setsLabel,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: scheme.onSurface,
                      ),
                    ),
                  ),
                  // Decrement
                  _StepButton(
                    icon: Icons.remove,
                    onPressed: _targetSets == null
                        ? null
                        : () => setState(() {
                              _targetSets =
                                  _targetSets! <= 1 ? null : _targetSets! - 1;
                            }),
                  ),
                  SizedBox(
                    width: 40,
                    child: Text(
                      _targetSets?.toString() ?? '—',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: _targetSets != null
                            ? scheme.primary
                            : scheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                  // Increment
                  _StepButton(
                    icon: Icons.add,
                    onPressed: () =>
                        setState(() => _targetSets = (_targetSets ?? 0) + 1),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Add button
            FilledButton(
              onPressed: () => Navigator.of(context).pop(
                PlannedExerciseDraft(exercise: ex, targetSets: _targetSets),
              ),
              child: Text(l10n.addExerciseTitle),
            ),
          ],
        ),
      ),
    );
  }
}

class _StepButton extends StatelessWidget {
  const _StepButton({required this.icon, required this.onPressed});

  final IconData icon;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        width: 34,
        height: 34,
        decoration: BoxDecoration(
          color: onPressed != null
              ? scheme.surfaceContainerHighest
              : scheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(
          icon,
          size: 18,
          color: onPressed != null
              ? scheme.onSurface
              : scheme.onSurface.withValues(alpha: 0.3),
        ),
      ),
    );
  }
}
