import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/exercise_controller.dart';
import '../../domain/exercise.dart';

/// Bottom sheet to add an exercise to the *current session's* planned-exercise
/// list (no reps/weight yet — just "this exercise is part of the workout").
/// Distinct from [AddExerciseSheet], which creates a brand-new master exercise.
/// Pops with the picked [Exercise], or null if dismissed.
class AddExerciseToSessionSheet extends ConsumerWidget {
  const AddExerciseToSessionSheet({super.key, required this.excludeIds});

  /// Exercise clientIds already planned for this session — hidden from the list.
  final Set<String> excludeIds;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final exercisesState = ref.watch(exerciseControllerProvider);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Add exercise', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 12),
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 320),
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
                  final available =
                      exercises.where((e) => !excludeIds.contains(e.clientId)).toList();
                  if (available.isEmpty) {
                    return const Padding(
                      padding: EdgeInsets.all(24),
                      child: Text('Every exercise is already in this session.'),
                    );
                  }
                  return ListView.separated(
                    shrinkWrap: true,
                    itemCount: available.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final exercise = available[index];
                      return ListTile(
                        title: Text(exercise.name),
                        onTap: () => Navigator.of(context).pop<Exercise>(exercise),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
