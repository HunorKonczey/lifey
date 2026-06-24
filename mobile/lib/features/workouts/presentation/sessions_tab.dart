import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_tokens.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/widgets/date_range_filter_bar.dart';
import '../../../shared/widgets/empty_view.dart';
import '../../../shared/widgets/error_view.dart';
import '../../../shared/widgets/sync_status_indicator.dart';
import '../application/workout_session_controller.dart';
import '../domain/workout_session.dart';
import 'log_session_screen.dart';

/// "Sessions" tab: tap to edit/continue; swipe-to-delete with confirm; date filter.
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
    final bottomPad = MediaQuery.paddingOf(context).bottom;

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
                onRefresh: () =>
                    ref.read(workoutSessionControllerProvider.notifier).refresh(),
                child: filtered.isEmpty
                    ? EmptyView(
                        icon: Icons.fitness_center_outlined,
                        title: l10n.noWorkoutsInRangeTitle,
                        subtitle: l10n.tryWiderDateFilterMessage,
                      )
                    : ListView.builder(
                        padding: EdgeInsets.fromLTRB(12, 4, 12, bottomPad + 88),
                        itemCount: filtered.length,
                        itemBuilder: (context, index) => _SessionCard(
                          session: filtered[index],
                          dateLabel: _dateLabel,
                          onEdit: () => _edit(context, filtered[index]),
                          onDelete: () => _delete(context, ref, filtered[index]),
                          onDeleteTap: () =>
                              _confirmDelete(context, ref, filtered[index]),
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

// ---------------------------------------------------------------------------
// Session card
// ---------------------------------------------------------------------------

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
    final scheme = theme.colorScheme;
    final l10n = AppLocalizations.of(context)!;

    // Comma-separated unique exercise names from this session's sets.
    final exerciseNames = session.sets
        .map((s) => s.exerciseName)
        .toSet()
        .take(4)
        .join(', ');

    return Dismissible(
      key: ValueKey(session.clientId),
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
      onDismissed: (_) => onDelete(),
      child: Card(
        elevation: 0,
        color: scheme.surfaceContainerHigh,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.card),
        ),
        margin: const EdgeInsets.only(bottom: 10),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onEdit,
          borderRadius: BorderRadius.circular(AppRadius.card),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
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
                // Content
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Date + Apple Health badge + status chip
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              dateLabel.format(session.startedAt.toLocal()),
                              style: theme.textTheme.bodyLarge,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (session.fromAppleHealth)
                            Padding(
                              padding: const EdgeInsets.only(left: 4),
                              child: Tooltip(
                                message: l10n.importedFromAppleHealthTooltip,
                                child: Icon(
                                  Icons.apple,
                                  size: 15,
                                  color: scheme.onSurfaceVariant,
                                  semanticLabel:
                                      l10n.importedFromAppleHealthTooltip,
                                ),
                              ),
                            ),
                          SyncStatusIndicator(clientId: session.clientId),
                        ],
                      ),
                      const SizedBox(height: 3),
                      // Sets count / in-progress pill
                      if (session.inProgress)
                        _StatusPill(label: l10n.inProgressLabel, scheme: scheme)
                      else
                        Text(
                          l10n.setsCountLabel(session.sets.length),
                          style: theme.textTheme.labelMedium?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      // Apple Health stats
                      if (session.activeCalories != null ||
                          session.averageHeartRate != null) ...[
                        const SizedBox(height: 3),
                        Text(
                          l10n.appleHealthStatsLine(
                            session.activeCalories?.round().toString() ?? '–',
                            session.averageHeartRate?.round().toString() ?? '–',
                          ),
                          style: theme.textTheme.labelMedium?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                      // Exercise names
                      if (exerciseNames.isNotEmpty) ...[
                        const SizedBox(height: 3),
                        Text(
                          exerciseNames,
                          style: theme.textTheme.labelMedium?.copyWith(
                            color: scheme.onSurfaceVariant
                                .withValues(alpha: 0.7),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                ),
                // Delete tap target
                GestureDetector(
                  onTap: onDeleteTap,
                  behavior: HitTestBehavior.opaque,
                  child: Padding(
                    padding: const EdgeInsets.only(left: 4),
                    child: Icon(
                      Icons.more_vert,
                      size: 18,
                      color: scheme.onSurfaceVariant,
                    ),
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

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.label, required this.scheme});
  final String label;
  final ColorScheme scheme;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: scheme.tertiaryContainer,
        borderRadius: BorderRadius.circular(99),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontFamily: 'PlusJakartaSans',
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: scheme.onTertiaryContainer,
          height: 1.0,
        ),
      ),
    );
  }
}
