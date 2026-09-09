import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/network/error_message.dart';
import '../../../../core/sync/connectivity_status_provider.dart';
import '../../../../core/theme/app_tokens.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../shared/widgets/adaptive_app_bar.dart';
import '../../../../shared/widgets/app_snackbar.dart';
import '../../../../shared/widgets/confirm_delete_dialog.dart';
import '../../../../shared/widgets/empty_view.dart';
import '../../../../shared/widgets/error_view.dart';
import '../../../../shared/widgets/nav_collapse_controller.dart';
import '../../../../shared/widgets/trainer_view_menu.dart';
import '../../../chat/application/conversation_list_controller.dart';
import '../../clients/application/trainer_clients_controller.dart';
import '../../shared/trainer_view_badge.dart';
import '../application/assignable_content.dart';
import '../application/assignments_controller.dart';
import '../domain/assignment.dart';
import 'widgets/assign_result_sheet.dart';
import 'widgets/assign_sheet.dart';

/// The trainer's second branch: what have I given people, and to whom
/// (docs/chat/41-trainer-mobile-v2-plan.md T4, frame E1).
class AssignmentsScreen extends ConsumerWidget {
  const AssignmentsScreen({super.key});

  Future<void> _assign(BuildContext context, WidgetRef ref) async {
    final result = await AssignSheet.show(context);
    if (result == null || !context.mounted) return;
    await AssignResultSheet.show(
      context,
      result: result,
      clients: ref.read(trainerClientsControllerProvider).value ?? const [],
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final state = ref.watch(assignmentsControllerProvider);
    final isOffline = ref.watch(isOfflineProvider).value ?? false;

    final statusTop = MediaQuery.paddingOf(context).top;
    final barTop = statusTop + 8.0;
    final contentTop = barTop + 58.0 + 12.0;

    Future<void> refresh() =>
        ref.read(assignmentsControllerProvider.notifier).refresh();

    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        heroTag: null,
        onPressed: () => _assign(context, ref),
        backgroundColor: Theme.of(context).colorScheme.tertiary,
        foregroundColor: Theme.of(context).colorScheme.onTertiary,
        icon: const Icon(Icons.add),
        label: Text(l10n.trainerAssignButton),
      ),
      body: ScrollCollapseListener(
        child: Stack(
          children: [
            Positioned.fill(
              child: RefreshIndicator(
                displacement: contentTop,
                onRefresh: refresh,
                child: isOffline && !state.hasValue
                    ? EmptyView(
                        icon: Icons.cloud_off,
                        title: l10n.trainerOfflineTitle,
                        subtitle: l10n.trainerOfflineMessage,
                        action: FilledButton.tonal(
                          onPressed: refresh,
                          child: Text(l10n.retryButton),
                        ),
                      )
                    : state.when(
                        data: (rows) => _AssignmentList(
                          rows: rows,
                          contentTop: contentTop,
                        ),
                        loading: () =>
                            const Center(child: CircularProgressIndicator()),
                        error: (error, _) =>
                            ErrorView(error: error, onRetry: refresh),
                      ),
              ),
            ),
            Positioned(
              top: barTop,
              left: 12,
              right: 12,
              child: AdaptiveAppBar(
                title: l10n.trainerAssignmentsTitle,
                titleBadge: const TrainerViewBadge(),
                actions: [
                  AdaptiveAppBarAction(
                    icon: Icons.chat_bubble_outline,
                    tooltip: l10n.chatOpenTooltip,
                    badgeCount: ref.watch(unreadBadgeProvider).value ?? 0,
                    onPressed: () => context.push('/chat'),
                  ),
                ],
                trailing: const TrainerViewMenu(inTrainerView: true),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// List
// ---------------------------------------------------------------------------

class _AssignmentList extends ConsumerWidget {
  const _AssignmentList({required this.rows, required this.contentTop});

  final List<AssignmentRow> rows;
  final double contentTop;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final filter = ref.watch(assignmentFilterControllerProvider);
    final visible = rows.where(filter.matches).toList();
    final bottomPad = MediaQuery.paddingOf(context).bottom + 96;

    // The empty state is its own scrollable, not a list row — EmptyView fills
    // the viewport, which a ListView child cannot be asked to do.
    if (rows.isEmpty) {
      return EmptyView(
        icon: Icons.assignment_outlined,
        title: l10n.trainerNoAssignmentsTitle,
        subtitle: l10n.trainerNoAssignmentsMessage,
      );
    }

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: EdgeInsets.only(top: contentTop, bottom: bottomPad),
      children: [
        const _FilterBar(),
        if (visible.isEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 40, 24, 0),
            child: Text(
              l10n.trainerNoAssignmentsForFilterMessage,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
          )
        else
          for (final row in visible)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
              child: _AssignmentTile(row: row),
            ),
      ],
    );
  }
}

class _FilterBar extends ConsumerWidget {
  const _FilterBar();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    final filter = ref.watch(assignmentFilterControllerProvider);
    final controller = ref.read(assignmentFilterControllerProvider.notifier);
    final clients = ref.watch(trainerClientsControllerProvider).value ?? const [];

    Widget chip(String label, bool selected, VoidCallback onTap) => ChoiceChip(
          label: Text(label),
          selected: selected,
          showCheckmark: false,
          selectedColor: scheme.tertiaryContainer,
          labelStyle: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: selected ? scheme.onTertiaryContainer : scheme.onSurfaceVariant,
          ),
          onSelected: (_) => onTap(),
        );

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            height: 38,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                chip(l10n.trainerFilterAllTypesLabel, filter.contentType == null,
                    () => controller.selectType(null)),
                const SizedBox(width: 8),
                chip(
                  l10n.trainerContentTypeTemplateLabel,
                  filter.contentType == AssignableContentType.template,
                  () => controller.selectType(AssignableContentType.template),
                ),
                const SizedBox(width: 8),
                chip(
                  l10n.trainerContentTypeRecipeLabel,
                  filter.contentType == AssignableContentType.recipe,
                  () => controller.selectType(AssignableContentType.recipe),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 38,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                chip(l10n.trainerFilterAllClientsLabel, filter.clientId == null,
                    () => controller.selectClient(null)),
                for (final client in clients) ...[
                  const SizedBox(width: 8),
                  chip(
                    client.displayName,
                    filter.clientId == client.userId,
                    () => controller.selectClient(client.userId),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AssignmentTile extends ConsumerWidget {
  const _AssignmentTile({required this.row});

  final AssignmentRow row;

  Future<void> _unassign(
    BuildContext context,
    WidgetRef ref,
    String contentName,
    AppLocalizations l10n,
  ) async {
    final confirmed = await showConfirmDeleteDialog(
      context,
      title: l10n.trainerUnassignConfirmTitle,
      // Names the second consequence out loud: this does not just untie a
      // row, it removes the copy from the client's own account.
      message: l10n.trainerUnassignConfirmMessage(
        contentName,
        row.client.displayName,
      ),
    );
    if (!confirmed || !context.mounted) return;
    try {
      await ref
          .read(assignmentsControllerProvider.notifier)
          .unassign(row.assignment.id);
      if (context.mounted) {
        AppSnackbar.showSuccess(context, title: l10n.trainerUnassignedMessage);
      }
    } catch (error) {
      if (context.mounted) {
        AppSnackbar.showError(context, title: friendlyError(error));
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final l10n = AppLocalizations.of(context)!;
    final locale = Localizations.localeOf(context).toString();

    final resolveName = ref.watch(assignedContentNameProvider);
    final contentName =
        resolveName(row.assignment.contentType, row.assignment.sourceId) ??
            l10n.trainerDeletedContentLabel;

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 10, 6, 10),
      decoration: BoxDecoration(
        color: scheme.surfaceContainer,
        borderRadius: AppRadius.cardAll,
      ),
      child: Row(
        children: [
          Icon(
            row.assignment.contentType == AssignableContentType.template
                ? Icons.fitness_center
                : Icons.restaurant,
            size: 20,
            color: scheme.tertiary,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  contentName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyMedium
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 2),
                Text(
                  '${row.client.displayName} · '
                  '${DateFormat.yMMMd(locale).format(row.assignment.assignedAt.toLocal())}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelSmall
                      ?.copyWith(color: scheme.onSurfaceVariant),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.remove_circle_outline),
            color: scheme.error,
            tooltip: l10n.trainerUnassignTooltip,
            onPressed: () => _unassign(context, ref, contentName, l10n),
          ),
        ],
      ),
    );
  }
}
