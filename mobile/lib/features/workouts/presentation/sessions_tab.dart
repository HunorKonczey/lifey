import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../shared/widgets/empty_view.dart';
import '../../../shared/widgets/error_view.dart';
import '../application/workout_session_controller.dart';
import '../domain/workout_session.dart';

/// "Sessions" tab: list of logged workout sessions (read-only; no delete API).
class SessionsTab extends ConsumerWidget {
  const SessionsTab({super.key});

  static final _dateLabel = DateFormat('EEE, MMM d · HH:mm');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(workoutSessionControllerProvider);

    return RefreshIndicator(
      onRefresh: () => ref.read(workoutSessionControllerProvider.notifier).refresh(),
      child: state.when(
        data: (sessions) {
          if (sessions.isEmpty) {
            return const EmptyView(
              icon: Icons.fitness_center_outlined,
              title: 'No workouts logged yet',
              subtitle: 'Tap + to log one',
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: sessions.length,
            itemBuilder: (context, index) =>
                _SessionCard(session: sessions[index], dateLabel: _dateLabel),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => ErrorView(
          error: error,
          onRetry: () =>
              ref.read(workoutSessionControllerProvider.notifier).refresh(),
        ),
      ),
    );
  }
}

class _SessionCard extends StatelessWidget {
  const _SessionCard({required this.session, required this.dateLabel});

  final WorkoutSession session;
  final DateFormat dateLabel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      elevation: 0,
      color: theme.colorScheme.surfaceContainerHighest,
      margin: const EdgeInsets.only(bottom: 12),
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
    );
  }
}
