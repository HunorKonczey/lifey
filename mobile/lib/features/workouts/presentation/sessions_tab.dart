import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_tokens.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/widgets/date_range_filter_bar.dart';
import '../../../shared/widgets/empty_view.dart';
import '../../../shared/widgets/error_view.dart';
import '../../../shared/widgets/app_snackbar.dart';
import '../../../shared/widgets/confirm_delete_dialog.dart';
import '../../../shared/widgets/sync_status_indicator.dart';
import '../application/exercise_controller.dart';
import '../application/workout_session_controller.dart';
import '../domain/exercise_enums.dart';
import '../domain/workout_session.dart';
import 'log_session_screen.dart';

/// "Sessions" tab: tap to edit/continue; swipe-to-delete with confirm; date filter.
/// The active [filter] is owned by the parent screen and shown in the AppBar.
class SessionsTab extends ConsumerStatefulWidget {
  const SessionsTab({
    super.key,
    this.topPadding = 0,
    this.filter = DateRangeFilter.today,
  });

  final double topPadding;
  final DateRangeFilter filter;

  @override
  ConsumerState<SessionsTab> createState() => _SessionsTabState();
}

class _SessionsTabState extends ConsumerState<SessionsTab> {
  static final _dateLabel = DateFormat('EEE, MMM d · HH:mm');

  /// Muscle group with the most exercises in [session], or null when unknown.
  static String? _dominantCategory(
      WorkoutSession session, Map<String, String?> categoryByExercise) {
    final exerciseIds = <String>{
      for (final ex in session.exercises) ex.exerciseClientId,
      for (final set in session.sets) set.exerciseClientId,
    };
    return dominantMuscleGroup(
      exerciseIds.map((id) => categoryByExercise[id]),
    );
  }

  Future<void> _edit(BuildContext context, WorkoutSession session) {
    return Navigator.of(context, rootNavigator: true).push(
      MaterialPageRoute(builder: (_) => LogSessionScreen(session: session)),
    );
  }

  Future<void> _delete(BuildContext context, WidgetRef ref, WorkoutSession session) async {
    final l10n = AppLocalizations.of(context)!;
    try {
      await ref.read(workoutSessionControllerProvider.notifier).deleteSession(session.clientId);
      if (context.mounted) {
        AppSnackbar.showSuccess(context, title: l10n.workoutDeletedMessage);
      }
    } catch (_) {
      if (context.mounted) {
        AppSnackbar.showError(context, title: l10n.couldNotDeleteWorkoutMessage);
      }
      await ref.read(workoutSessionControllerProvider.notifier).refresh();
    }
  }

  Future<void> _confirmDelete(
      BuildContext context, WidgetRef ref, WorkoutSession session) async {
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showConfirmDeleteDialog(
      context,
      title: l10n.deleteWorkoutQuestionTitle,
      message: l10n.deleteWorkoutConfirmMessage,
    );
    if (confirmed && context.mounted) {
      await _delete(context, ref, session);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(workoutSessionControllerProvider);
    final l10n = AppLocalizations.of(context)!;
    final bottomPad = MediaQuery.paddingOf(context).bottom;

    // Exercise clientId → muscle-group code, for colouring each card's icon by
    // the session's dominant muscle group.
    final categoryByExercise = ref.watch(exerciseControllerProvider).maybeWhen(
          data: (exercises) => {for (final e in exercises) e.clientId: e.category},
          orElse: () => const <String, String?>{},
        );

    return state.when(
      data: (sessions) {
        final filtered =
            sessions.where((s) => widget.filter.matches(s.startedAt)).toList();

        if (sessions.isEmpty || filtered.isEmpty) {
          return RefreshIndicator(
            displacement: widget.topPadding,
            onRefresh: () =>
                ref.read(workoutSessionControllerProvider.notifier).refresh(),
            child: EmptyView(
              icon: Icons.fitness_center_outlined,
              title: sessions.isEmpty
                  ? l10n.noWorkoutsLoggedYetTitle
                  : l10n.noWorkoutsInRangeTitle,
              subtitle: sessions.isEmpty
                  ? l10n.tapPlusToLogOneMessage
                  : l10n.tryWiderDateFilterMessage,
            ),
          );
        }

        return RefreshIndicator(
          displacement: widget.topPadding,
          onRefresh: () =>
              ref.read(workoutSessionControllerProvider.notifier).refresh(),
          child: ListView.builder(
            padding: EdgeInsets.fromLTRB(12, widget.topPadding, 12, bottomPad + 88),
            itemCount: filtered.length,
            itemBuilder: (context, index) => _SessionCard(
              session: filtered[index],
              categoryCode: _dominantCategory(filtered[index], categoryByExercise),
              dateLabel: _dateLabel,
              onEdit: () => _edit(context, filtered[index]),
              onDelete: () => _confirmDelete(context, ref, filtered[index]),
            ),
          ),
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
    required this.categoryCode,
    required this.dateLabel,
    required this.onEdit,
    required this.onDelete,
  });

  final WorkoutSession session;
  final String? categoryCode;
  final DateFormat dateLabel;
  final VoidCallback onEdit;

  /// Asks for confirmation, then deletes. Shared by the swipe gesture and the
  /// trailing delete button.
  final VoidCallback onDelete;

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

    final Color badgeBg;
    final Color badgeIconColor;
    if (categoryCode != null) {
      final mc = muscleGroupColor(categoryCode!, context);
      badgeBg = mc.withValues(alpha: 0.15);
      badgeIconColor = mc;
    } else {
      badgeBg = scheme.primaryContainer;
      badgeIconColor = scheme.onPrimaryContainer;
    }

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
      // Confirm before deleting; the local cache stream removes the tile once
      // the delete lands, so we always report `false` here.
      confirmDismiss: (_) async {
        onDelete();
        return false;
      },
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
                    color: badgeBg,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Center(
                    child: Icon(
                      Icons.fitness_center,
                      size: 22,
                      color: badgeIconColor,
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
                // Delete button
                IconButton(
                  onPressed: onDelete,
                  icon: Icon(
                    Icons.delete_outline,
                    size: 20,
                    color: scheme.onSurfaceVariant,
                  ),
                  tooltip: l10n.deleteWorkoutTooltip,
                  visualDensity: VisualDensity.compact,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
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
