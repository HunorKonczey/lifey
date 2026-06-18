import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../shared/widgets/date_range_filter_bar.dart';
import '../../../shared/widgets/empty_view.dart';
import '../../../shared/widgets/error_view.dart';
import '../application/workout_session_controller.dart';
import '../domain/workout_session.dart';
import 'log_session_screen.dart';

/// "Sessions" tab: tap to edit (e.g. finish an in-progress workout), swipe to
/// delete, filter by date range.
class SessionsTab extends ConsumerStatefulWidget {
  const SessionsTab({super.key});

  @override
  ConsumerState<SessionsTab> createState() => _SessionsTabState();
}

class _SessionsTabState extends ConsumerState<SessionsTab> {
  static final _dateLabel = DateFormat('EEE, MMM d · HH:mm');

  DateRangeFilter _filter = DateRangeFilter.all;

  Future<void> _edit(BuildContext context, WorkoutSession session) {
    return Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => LogSessionScreen(session: session)),
    );
  }

  Future<void> _delete(BuildContext context, WidgetRef ref, WorkoutSession session) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(workoutSessionControllerProvider.notifier).deleteSession(session.id);
      messenger.showSnackBar(const SnackBar(content: Text('Workout deleted')));
    } catch (_) {
      messenger.showSnackBar(const SnackBar(content: Text("Couldn't delete the workout")));
      await ref.read(workoutSessionControllerProvider.notifier).refresh();
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(workoutSessionControllerProvider);

    return state.when(
      data: (sessions) {
        if (sessions.isEmpty) {
          return RefreshIndicator(
            onRefresh: () =>
                ref.read(workoutSessionControllerProvider.notifier).refresh(),
            child: const EmptyView(
              icon: Icons.fitness_center_outlined,
              title: 'No workouts logged yet',
              subtitle: 'Tap + to log one',
            ),
          );
        }
        final filtered =
            sessions.where((s) => _filter.matches(s.startedAt)).toList();
        return Column(
          children: [
            DateRangeFilterBar(
              value: _filter,
              onChanged: (f) => setState(() => _filter = f),
            ),
            Expanded(
              child: RefreshIndicator(
                onRefresh: () => ref
                    .read(workoutSessionControllerProvider.notifier)
                    .refresh(),
                child: filtered.isEmpty
                    ? const EmptyView(
                        icon: Icons.fitness_center_outlined,
                        title: 'No workouts in this range',
                        subtitle: 'Try a wider date filter',
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(12),
                        itemCount: filtered.length,
                        itemBuilder: (context, index) => _SessionCard(
                          session: filtered[index],
                          dateLabel: _dateLabel,
                          onEdit: () => _edit(context, filtered[index]),
                          onDelete: () => _delete(context, ref, filtered[index]),
                        ),
                      ),
              ),
            ),
          ],
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => ErrorView(
        error: error,
        onRetry: () =>
            ref.read(workoutSessionControllerProvider.notifier).refresh(),
      ),
    );
  }
}

class _SessionCard extends StatelessWidget {
  const _SessionCard({
    required this.session,
    required this.dateLabel,
    required this.onEdit,
    required this.onDelete,
  });

  final WorkoutSession session;
  final DateFormat dateLabel;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Dismissible(
      key: ValueKey(session.id),
      direction: DismissDirection.endToStart,
      background: Container(
        decoration: BoxDecoration(
          color: theme.colorScheme.errorContainer,
          borderRadius: BorderRadius.circular(12),
        ),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        margin: const EdgeInsets.only(bottom: 12),
        child: Icon(Icons.delete, color: theme.colorScheme.onErrorContainer),
      ),
      onDismissed: (_) => onDelete(),
      child: Card(
        elevation: 0,
        color: theme.colorScheme.surfaceContainerHighest,
        margin: const EdgeInsets.only(bottom: 12),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onEdit,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(dateLabel.format(session.startedAt.toLocal()),
                        style: theme.textTheme.titleSmall),
                    const Spacer(),
                    if (session.inProgress)
                      Chip(
                        label: const Text('In progress'),
                        visualDensity: VisualDensity.compact,
                        backgroundColor: theme.colorScheme.tertiaryContainer,
                      )
                    else
                      Text('${session.sets.length} sets',
                          style: theme.textTheme.labelLarge),
                  ],
                ),
                const SizedBox(height: 8),
                ...session.sets.map(
                  (s) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Text(
                        '${s.exerciseName} — ${s.reps} × ${s.weight.toStringAsFixed(1)} kg'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
