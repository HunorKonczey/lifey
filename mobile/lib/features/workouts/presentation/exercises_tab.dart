import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_tokens.dart';
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
      messenger.showSnackBar(
          SnackBar(content: Text(l10n.couldNotDeleteExerciseMessage(exercise.name))));
      await ref.read(exerciseControllerProvider.notifier).refresh();
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(exerciseControllerProvider);
    final l10n = AppLocalizations.of(context)!;
    final bottomPad = MediaQuery.paddingOf(context).bottom;

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
          return ListView.builder(
            padding: EdgeInsets.fromLTRB(12, 4, 12, bottomPad + 88),
            itemCount: exercises.length,
            itemBuilder: (context, index) {
              final exercise = exercises[index];
              return _ExerciseCard(
                exercise: exercise,
                onDelete: () => _delete(context, ref, exercise),
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

// ---------------------------------------------------------------------------
// Exercise card
// ---------------------------------------------------------------------------

class _ExerciseCard extends StatelessWidget {
  const _ExerciseCard({
    required this.exercise,
    required this.onDelete,
  });

  final Exercise exercise;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Dismissible(
      key: ValueKey(exercise.clientId),
      direction: DismissDirection.endToStart,
      background: Container(
        decoration: BoxDecoration(
          color: scheme.errorContainer,
          borderRadius: BorderRadius.circular(AppRadius.card),
        ),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        margin: const EdgeInsets.only(bottom: 10),
        child: Icon(Icons.delete, color: scheme.onErrorContainer),
      ),
      confirmDismiss: (_) async {
        onDelete();
        return false;
      },
      child: Card(
        elevation: 0,
        color: scheme.surfaceContainerHigh,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.card),
        ),
        margin: const EdgeInsets.only(bottom: 10),
        clipBehavior: Clip.antiAlias,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              // Icon badge
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: scheme.primaryContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: Icon(
                    Icons.fitness_center,
                    size: 22,
                    color: scheme.onPrimaryContainer,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(exercise.name, style: theme.textTheme.bodyLarge),
              ),
              SyncStatusIndicator(clientId: exercise.clientId),
            ],
          ),
        ),
      ),
    );
  }
}
