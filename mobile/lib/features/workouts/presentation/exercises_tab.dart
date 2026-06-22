import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/app_localizations.dart';
import '../../../shared/widgets/empty_view.dart';
import '../../../shared/widgets/error_view.dart';
import '../../../shared/widgets/sync_status_indicator.dart';
import '../application/exercise_controller.dart';
import '../domain/exercise.dart';

/// "Exercises" tab: manage the exercise master list (add / swipe-to-delete).
class ExercisesTab extends ConsumerWidget {
  const ExercisesTab({super.key});

  Future<void> _delete(BuildContext context, WidgetRef ref, Exercise exercise) async {
    final messenger = ScaffoldMessenger.of(context);
    final l10n = AppLocalizations.of(context)!;
    try {
      await ref.read(exerciseControllerProvider.notifier).deleteExercise(exercise.clientId);
      messenger.showSnackBar(SnackBar(content: Text(l10n.deletedExerciseMessage(exercise.name))));
    } catch (_) {
      messenger.showSnackBar(SnackBar(content: Text(l10n.couldNotDeleteExerciseMessage(exercise.name))));
      await ref.read(exerciseControllerProvider.notifier).refresh();
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(exerciseControllerProvider);
    final l10n = AppLocalizations.of(context)!;

    return RefreshIndicator(
      onRefresh: () => ref.read(exerciseControllerProvider.notifier).refresh(),
      child: state.when(
        data: (exercises) {
          if (exercises.isEmpty) {
            return EmptyView(
              icon: Icons.sports_gymnastics_outlined,
              title: l10n.noExercisesYetTitle,
              subtitle: l10n.tapPlusToAddOneMessage,
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: exercises.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final exercise = exercises[index];
              return Dismissible(
                key: ValueKey(exercise.clientId),
                direction: DismissDirection.endToStart,
                background: Container(
                  color: Theme.of(context).colorScheme.errorContainer,
                  alignment: Alignment.centerRight,
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Icon(Icons.delete,
                      color: Theme.of(context).colorScheme.onErrorContainer),
                ),
                confirmDismiss: (_) async {
                  await _delete(context, ref, exercise);
                  return false;
                },
                child: ListTile(
                  leading: const CircleAvatar(child: Icon(Icons.fitness_center)),
                  title: Text(exercise.name),
                  trailing: SyncStatusIndicator(clientId: exercise.clientId),
                ),
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => ErrorView(
          error: error,
          onRetry: () => ref.read(exerciseControllerProvider.notifier).refresh(),
        ),
      ),
    );
  }
}
