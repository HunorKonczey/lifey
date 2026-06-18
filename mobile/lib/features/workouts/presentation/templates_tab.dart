import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/widgets/empty_view.dart';
import '../../../shared/widgets/error_view.dart';
import '../application/exercise_controller.dart';
import '../application/workout_template_controller.dart';
import '../domain/workout_template.dart';

/// "Templates" tab: list of workout templates (read-only; no delete API).
class TemplatesTab extends ConsumerWidget {
  const TemplatesTab({super.key});

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
            itemBuilder: (context, index) =>
                _TemplateTile(template: templates[index], names: names),
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
  const _TemplateTile({required this.template, required this.names});

  final WorkoutTemplate template;
  final Map<int, String> names;

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
    );
  }
}
