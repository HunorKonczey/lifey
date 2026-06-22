import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/app_localizations.dart';
import '../../../shared/widgets/empty_view.dart';
import '../../../shared/widgets/error_view.dart';
import '../../../shared/widgets/sync_status_indicator.dart';
import '../application/exercise_controller.dart';
import '../application/workout_template_controller.dart';
import '../domain/workout_template.dart';
import 'create_template_screen.dart';
import 'log_session_screen.dart';

/// "Templates" tab: tap a template to start a session from it; the overflow
/// menu edits or deletes it.
class TemplatesTab extends ConsumerWidget {
  const TemplatesTab({super.key});

  void _start(BuildContext context, WorkoutTemplate template) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => LogSessionScreen(template: template)),
    );
  }

  void _edit(BuildContext context, WorkoutTemplate template) {
    Navigator.of(context).push(
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
    // Resolve exercise ids to names when the list is available.
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
          return ListView.separated(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: templates.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final template = templates[index];
              return _TemplateTile(
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

class _TemplateTile extends StatelessWidget {
  const _TemplateTile({
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
    final l10n = AppLocalizations.of(context)!;
    final resolved = template.exerciseClientIds
        .map((id) => names[id])
        .whereType<String>()
        .toList();
    final subtitle = resolved.isNotEmpty
        ? resolved.join(', ')
        : l10n.exercisesCountLabel(template.exerciseClientIds.length);

    return ListTile(
      leading: const CircleAvatar(child: Icon(Icons.list_alt)),
      title: Text(template.name),
      subtitle: Text(subtitle, maxLines: 2, overflow: TextOverflow.ellipsis),
      onTap: onStart,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SyncStatusIndicator(clientId: template.clientId),
          PopupMenuButton<String>(
            onSelected: (value) {
              switch (value) {
                case 'start':
                  onStart();
                case 'edit':
                  onEdit();
                case 'delete':
                  onDelete();
              }
            },
            itemBuilder: (_) => [
              PopupMenuItem(value: 'start', child: Text(l10n.startSessionMenuItem)),
              PopupMenuItem(value: 'edit', child: Text(l10n.editMenuItem)),
              PopupMenuItem(value: 'delete', child: Text(l10n.deleteButton)),
            ],
          ),
        ],
      ),
    );
  }
}
