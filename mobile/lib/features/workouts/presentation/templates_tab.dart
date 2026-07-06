import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_tokens.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/widgets/app_snackbar.dart';
import '../../../shared/widgets/confirm_delete_dialog.dart';
import '../../../shared/widgets/empty_view.dart';
import '../../../shared/widgets/error_view.dart';
import '../../../shared/widgets/origin_trainer_badge.dart';
import '../application/exercise_controller.dart';
import '../application/workout_template_controller.dart';
import '../domain/exercise.dart';
import '../domain/exercise_enums.dart';
import '../domain/workout_template.dart';
import 'create_template_screen.dart';
import 'log_session_screen.dart';

/// "Templates" tab: tap "Start" to begin a session; overflow menu for edit/delete.
class TemplatesTab extends ConsumerWidget {
  const TemplatesTab({super.key, this.topPadding = 0});

  final double topPadding;

  void _start(BuildContext context, WorkoutTemplate template) {
    Navigator.of(context, rootNavigator: true).push(
      MaterialPageRoute(builder: (_) => LogSessionScreen(template: template)),
    );
  }

  void _edit(BuildContext context, WorkoutTemplate template) {
    Navigator.of(context, rootNavigator: true).push(
      MaterialPageRoute(builder: (_) => CreateTemplateScreen(template: template)),
    );
  }

  Future<void> _delete(
      BuildContext context, WidgetRef ref, WorkoutTemplate template) async {
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showConfirmDeleteDialog(
      context,
      title: l10n.deleteTemplateQuestionTitle,
      message: l10n.deleteTemplateConfirmMessage(template.name),
    );
    if (!confirmed || !context.mounted) return;

    try {
      await ref
          .read(workoutTemplateControllerProvider.notifier)
          .deleteTemplate(template.clientId);
      if (context.mounted) {
        AppSnackbar.showSuccess(context, title: l10n.templateDeletedMessage);
      }
    } catch (_) {
      if (context.mounted) {
        AppSnackbar.showError(context, title: l10n.couldNotDeleteTemplateMessage);
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(workoutTemplateControllerProvider);
    final l10n = AppLocalizations.of(context)!;
    final bottomPad = MediaQuery.paddingOf(context).bottom;

    // Full Exercise objects keyed by clientId — needed for categories + names.
    final exercisesMap = ref.watch(exerciseControllerProvider).maybeWhen(
          data: (exercises) => {for (final e in exercises) e.clientId: e},
          orElse: () => const <String, Exercise>{},
        );

    return RefreshIndicator(
      displacement: topPadding,
      onRefresh: () =>
          ref.read(workoutTemplateControllerProvider.notifier).refresh(),
      child: state.when(
        data: (templates) {
          if (templates.isEmpty) {
            return EmptyView(
              icon: Icons.list_alt_outlined,
              title: l10n.noTemplatesYetTitle,
              subtitle: l10n.tapPlusToCreateOneMessage,
            );
          }
          return ListView.builder(
            padding: EdgeInsets.fromLTRB(12, topPadding, 12, bottomPad + 88),
            itemCount: templates.length,
            itemBuilder: (context, index) {
              final template = templates[index];
              return _TemplateCard(
                template: template,
                exercisesMap: exercisesMap,
                l10n: l10n,
                onStart: () => _start(context, template),
                onEdit: () => _edit(context, template),
                onDelete: () => _delete(context, ref, template),
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => ErrorView(
          error: error,
          onRetry: () =>
              ref.read(workoutTemplateControllerProvider.notifier).refresh(),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Template card
// ---------------------------------------------------------------------------

class _TemplateCard extends StatelessWidget {
  const _TemplateCard({
    required this.template,
    required this.exercisesMap,
    required this.l10n,
    required this.onStart,
    required this.onEdit,
    required this.onDelete,
  });

  final WorkoutTemplate template;
  final Map<String, Exercise> exercisesMap;
  final AppLocalizations l10n;
  final VoidCallback onStart;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  /// Distinct muscle-group codes present in this template, ordered by
  /// [kMuscleGroups] display order. Exercises without a category are ignored.
  List<String> _categories() {
    final seen = <String>{};
    final ordered = <String>[];
    for (final code in kMuscleGroups) {
      if (template.exercises.any((te) {
        final ex = exercisesMap[te.exerciseClientId];
        return ex?.category == code;
      })) {
        if (seen.add(code)) ordered.add(code);
      }
    }
    return ordered;
  }

  IconData _templateIcon(List<String> categories) {
    if (categories.contains('CARDIO')) return Icons.directions_run;
    final hasBodyweight = template.exercises.any(
      (te) => exercisesMap[te.exerciseClientId]?.equipment == 'BODYWEIGHT',
    );
    if (hasBodyweight) return Icons.sports_gymnastics;
    return Icons.list_alt;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    final categories = _categories();
    // Templates keep the neutral green badge (matching the design); the
    // muscle-group colours appear only on the category chips below.
    final badgeBg = scheme.primaryContainer;
    final badgeIconColor = scheme.onPrimaryContainer;

    return Card(
      elevation: 0,
      color: scheme.surfaceContainerHigh,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.card),
      ),
      margin: const EdgeInsets.only(bottom: 10),
      clipBehavior: Clip.antiAlias,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── Info section (tappable → start) ──────────────────────────────
          InkWell(
            onTap: onStart,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header row
                  Row(
                    children: [
                      Container(
                        width: 46,
                        height: 46,
                        decoration: BoxDecoration(
                          color: badgeBg,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Center(
                          child: Icon(
                            _templateIcon(categories),
                            size: 24,
                            color: badgeIconColor,
                          ),
                        ),
                      ),
                      const SizedBox(width: 13),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              template.name,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                              ).copyWith(color: scheme.onSurface),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              l10n.exercisesCountLabel(template.exercises.length),
                              style: const TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w600,
                              ).copyWith(color: scheme.onSurfaceVariant),
                            ),
                          ],
                        ),
                      ),
                      PopupMenuButton<String>(
                        onSelected: (value) {
                          switch (value) {
                            case 'edit':
                              onEdit();
                            case 'delete':
                              onDelete();
                          }
                        },
                        icon: Icon(Icons.more_vert,
                            size: 20, color: scheme.onSurfaceVariant),
                        padding: EdgeInsets.zero,
                        itemBuilder: (_) => [
                          PopupMenuItem(value: 'edit', child: Text(l10n.editMenuItem)),
                          PopupMenuItem(
                              value: 'delete', child: Text(l10n.deleteButton)),
                        ],
                      ),
                    ],
                  ),

                  // "Edzőtől" badge, if this template was trainer-assigned
                  if (template.originTrainerId != null) ...[
                    const SizedBox(height: 10),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: OriginTrainerBadge(
                        originTrainerId: template.originTrainerId!,
                      ),
                    ),
                  ],

                  // Category chips
                  if (categories.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: categories
                          .map((c) => _CategoryChip(
                                label: muscleGroupLabel(l10n, c),
                                color: muscleGroupColor(c, context),
                              ))
                          .toList(),
                    ),
                  ],
                ],
              ),
            ),
          ),

          // ── Start button ─────────────────────────────────────────────────
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            child: SizedBox(
              width: double.infinity,
              child: FilledButton.tonal(
                onPressed: onStart,
                style: FilledButton.styleFrom(
                  backgroundColor: scheme.primaryContainer,
                  foregroundColor: scheme.onPrimaryContainer,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadius.card - 4),
                  ),
                  textStyle: const TextStyle(
                    fontFamily: 'PlusJakartaSans',
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.play_arrow_rounded, size: 20),
                    const SizedBox(width: 6),
                    Text(l10n.startWorkoutButton),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Category chip
// ---------------------------------------------------------------------------

class _CategoryChip extends StatelessWidget {
  const _CategoryChip({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: AppRadius.pill,
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          height: 1.0,
        ).copyWith(color: color),
      ),
    );
  }
}

