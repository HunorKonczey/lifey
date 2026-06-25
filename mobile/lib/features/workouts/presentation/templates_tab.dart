import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_tokens.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/widgets/empty_view.dart';
import '../../../shared/widgets/error_view.dart';
import '../../../shared/widgets/sync_status_indicator.dart';
import '../application/exercise_controller.dart';
import '../application/workout_template_controller.dart';
import '../domain/exercise.dart';
import '../domain/exercise_enums.dart';
import '../domain/workout_template.dart';
import 'create_template_screen.dart';
import 'log_session_screen.dart';

/// "Templates" tab: tap "Start" to begin a session; overflow menu for edit/delete.
class TemplatesTab extends ConsumerWidget {
  const TemplatesTab({super.key});

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
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.deleteTemplateQuestionTitle),
        content: Text(l10n.deleteTemplateConfirmMessage(template.name)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(l10n.cancelButton),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(l10n.deleteButton),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref
          .read(workoutTemplateControllerProvider.notifier)
          .deleteTemplate(template.clientId);
      messenger.showSnackBar(SnackBar(content: Text(l10n.templateDeletedMessage)));
    } catch (_) {
      messenger
          .showSnackBar(SnackBar(content: Text(l10n.couldNotDeleteTemplateMessage)));
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
            padding: EdgeInsets.fromLTRB(12, 4, 12, bottomPad + 88),
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
    final primaryCategory = categories.isNotEmpty ? categories.first : null;
    final Color badgeBg;
    final Color badgeIconColor;
    if (primaryCategory != null) {
      final mc = muscleGroupColor(primaryCategory, context);
      badgeBg = mc.withValues(alpha: 0.15);
      badgeIconColor = mc;
    } else {
      badgeBg = scheme.primaryContainer;
      badgeIconColor = scheme.onPrimaryContainer;
    }

    // Resolved exercise rows: (name, targetSets)
    final rows = template.exercises.map((te) {
      final ex = exercisesMap[te.exerciseClientId];
      return (name: ex?.name ?? '…', targetSets: te.targetSets);
    }).toList();

    return Card(
      elevation: 0,
      color: scheme.surfaceContainerHigh,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.card),
      ),
      margin: const EdgeInsets.only(bottom: 10),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onStart,
        borderRadius: BorderRadius.circular(AppRadius.card),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 4, 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Icon badge
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: badgeBg,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: Icon(
                    _templateIcon(categories),
                    size: 22,
                    color: badgeIconColor,
                  ),
                ),
              ),
              const SizedBox(width: 12),

              // Main content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Name + sync indicator
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            template.name,
                            style: theme.textTheme.bodyLarge,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        SyncStatusIndicator(clientId: template.clientId),
                      ],
                    ),

                    // Exercise count
                    const SizedBox(height: 2),
                    Text(
                      l10n.exercisesCountLabel(template.exercises.length),
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),

                    // Category chips
                    if (categories.isNotEmpty) ...[
                      const SizedBox(height: 8),
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

                    // Exercise list with optional targetSets badge
                    const SizedBox(height: 10),
                    ...rows.map((r) => _ExerciseRow(
                          name: r.name,
                          targetSets: r.targetSets,
                        )),
                  ],
                ),
              ),

              // Action column: Start pill + overflow menu
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  _StartButton(label: l10n.startSessionMenuItem, onTap: onStart),
                  const SizedBox(height: 4),
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
                        size: 18, color: scheme.onSurfaceVariant),
                    padding: EdgeInsets.zero,
                    itemBuilder: (_) => [
                      PopupMenuItem(value: 'edit', child: Text(l10n.editMenuItem)),
                      PopupMenuItem(
                          value: 'delete', child: Text(l10n.deleteButton)),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
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

// ---------------------------------------------------------------------------
// Exercise row
// ---------------------------------------------------------------------------

class _ExerciseRow extends StatelessWidget {
  const _ExerciseRow({required this.name, required this.targetSets});

  final String name;
  final int? targetSets;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          if (targetSets != null) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
              decoration: BoxDecoration(
                color: scheme.primaryContainer,
                borderRadius: BorderRadius.circular(AppRadius.sm),
              ),
              child: Text(
                '$targetSets×',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: scheme.onPrimaryContainer,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(width: 6),
          ] else ...[
            // Bullet dot to align with set-badge rows
            Padding(
              padding: const EdgeInsets.only(right: 6),
              child: Text(
                '·',
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: scheme.onSurfaceVariant),
              ),
            ),
          ],
          Expanded(
            child: Text(
              name,
              style: theme.textTheme.bodySmall,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Start button
// ---------------------------------------------------------------------------

class _StartButton extends StatelessWidget {
  const _StartButton({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color: scheme.primary.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.play_arrow, size: 14, color: scheme.primary),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontFamily: 'PlusJakartaSans',
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: scheme.primary,
                height: 1.0,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
