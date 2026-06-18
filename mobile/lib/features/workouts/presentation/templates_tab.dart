import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/widgets/empty_view.dart';
import '../../../shared/widgets/error_view.dart';
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
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete template?'),
        content: Text('"${template.name}" will be removed.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref
          .read(workoutTemplateControllerProvider.notifier)
          .deleteTemplate(template.id);
      messenger.showSnackBar(const SnackBar(content: Text('Template deleted')));
    } catch (_) {
      messenger
          .showSnackBar(const SnackBar(content: Text("Couldn't delete the template")));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(workoutTemplateControllerProvider);
    // Resolve exercise ids to names when the list is available.
    final names = ref.watch(exerciseControllerProvider).maybeWhen(
          data: (exercises) => {for (final e in exercises) e.id: e.name},
          orElse: () => const <int, String>{},
        );

    return RefreshIndicator(
      onRefresh: () =>
          ref.read(workoutTemplateControllerProvider.notifier).refresh(),
      child: state.when(
        data: (templates) {
          if (templates.isEmpty) {
            return const EmptyView(
              icon: Icons.list_alt_outlined,
              title: 'No templates yet',
              subtitle: 'Tap + to create one',
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
  final Map<int, String> names;
  final VoidCallback onStart;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final resolved = template.exerciseIds
        .map((id) => names[id])
        .whereType<String>()
        .toList();
    final subtitle = resolved.isNotEmpty
        ? resolved.join(', ')
        : '${template.exerciseIds.length} exercises';

    return ListTile(
      leading: const CircleAvatar(child: Icon(Icons.list_alt)),
      title: Text(template.name),
      subtitle: Text(subtitle, maxLines: 2, overflow: TextOverflow.ellipsis),
      onTap: onStart,
      trailing: PopupMenuButton<String>(
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
        itemBuilder: (_) => const [
          PopupMenuItem(value: 'start', child: Text('Start session')),
          PopupMenuItem(value: 'edit', child: Text('Edit')),
          PopupMenuItem(value: 'delete', child: Text('Delete')),
        ],
      ),
    );
  }
}
