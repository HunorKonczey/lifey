import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../l10n/app_localizations.dart';
import '../../../shared/widgets/date_range_filter_bar.dart';
import '../../../shared/widgets/empty_view.dart';
import '../../../shared/widgets/error_view.dart';
import '../../../shared/widgets/sync_status_indicator.dart';
import '../application/workout_session_controller.dart';
import '../domain/workout_session.dart';
import 'log_session_screen.dart';

/// "Sessions" tab: tap to edit (e.g. finish an in-progress workout), delete via
/// the trailing icon or by swiping, filter by date range.
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
    final l10n = AppLocalizations.of(context)!;
    try {
      await ref.read(workoutSessionControllerProvider.notifier).deleteSession(session.clientId);
      messenger.showSnackBar(SnackBar(content: Text(l10n.workoutDeletedMessage)));
    } catch (_) {
      messenger.showSnackBar(SnackBar(content: Text(l10n.couldNotDeleteWorkoutMessage)));
      await ref.read(workoutSessionControllerProvider.notifier).refresh();
    }
  }

  Future<void> _confirmDelete(
      BuildContext context, WidgetRef ref, WorkoutSession session) async {
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.deleteWorkoutQuestionTitle),
        content: Text(l10n.deleteWorkoutConfirmMessage),
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
    if (confirmed == true && context.mounted) {
      await _delete(context, ref, session);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(workoutSessionControllerProvider);
    final l10n = AppLocalizations.of(context)!;

    return state.when(
      data: (sessions) {
        if (sessions.isEmpty) {
          return RefreshIndicator(
            onRefresh: () =>
                ref.read(workoutSessionControllerProvider.notifier).refresh(),
            child: EmptyView(
              icon: Icons.fitness_center_outlined,
              title: l10n.noWorkoutsLoggedYetTitle,
              subtitle: l10n.tapPlusToLogOneMessage,
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
                    ? EmptyView(
                        icon: Icons.fitness_center_outlined,
                        title: l10n.noWorkoutsInRangeTitle,
                        subtitle: l10n.tryWiderDateFilterMessage,
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(12),
                        itemCount: filtered.length,
                        itemBuilder: (context, index) => _SessionCard(
                          session: filtered[index],
                          dateLabel: _dateLabel,
                          onEdit: () => _edit(context, filtered[index]),
                          onDelete: () => _delete(context, ref, filtered[index]),
                          onDeleteTap: () => _confirmDelete(context, ref, filtered[index]),
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
    required this.onDeleteTap,
  });

  final WorkoutSession session;
  final DateFormat dateLabel;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onDeleteTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    return Dismissible(
      key: ValueKey(session.clientId),
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
                        label: Text(l10n.inProgressLabel),
                        visualDensity: VisualDensity.compact,
                        backgroundColor: theme.colorScheme.tertiaryContainer,
                      )
                    else
                      Text(l10n.setsCountLabel(session.sets.length),
                          style: theme.textTheme.labelLarge),
                    SyncStatusIndicator(clientId: session.clientId),
                    IconButton(
                      tooltip: l10n.deleteWorkoutTooltip,
                      icon: const Icon(Icons.delete_outline),
                      onPressed: onDeleteTap,
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ...session.sets.map(
                  (s) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Text(l10n.exerciseSetLine(
                        s.exerciseName, s.reps.toString(), s.weight.toStringAsFixed(1))),
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
