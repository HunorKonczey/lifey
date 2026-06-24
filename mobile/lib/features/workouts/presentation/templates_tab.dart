import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_tokens.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/widgets/empty_view.dart';
import '../../../shared/widgets/error_view.dart';
import '../../../shared/widgets/sync_status_indicator.dart';
import '../application/exercise_controller.dart';
import '../application/workout_template_controller.dart';
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
    final names = ref.watch(exerciseControllerProvider).maybeWhen(
          data: (exercises) => {for (final e in exercises) e.clientId: e.name},
          orElse: () => const <String, String>{},
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
                names: names,
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
    required this.names,
    required this.onStart,
    required this.onEdit,
    required this.onDelete,
  });

  final WorkoutTemplate template;
  final Map<String, String> names;
  final VoidCallback onStart;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final l10n = AppLocalizations.of(context)!;

    final resolved = template.exerciseClientIds
        .map((id) => names[id])
        .whereType<String>()
        .toList();
    final subtitle = resolved.isNotEmpty
        ? resolved.join(', ')
        : l10n.exercisesCountLabel(template.exerciseClientIds.length);

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
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
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
                    Icons.list_alt,
                    size: 22,
                    color: scheme.onPrimaryContainer,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              // Content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
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
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              // Start pill button
              GestureDetector(
                onTap: onStart,
                behavior: HitTestBehavior.opaque,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
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
                        l10n.startSessionMenuItem,
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
              ),
              // Overflow menu for edit/delete
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
        ),
      ),
    );
  }
}
