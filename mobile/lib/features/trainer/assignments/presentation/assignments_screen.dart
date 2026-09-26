import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/format/lifey_format.dart';
import '../../../../core/network/error_message.dart';
import '../../../../core/sync/connectivity_status_provider.dart';
import '../../../../core/theme/app_tokens.dart';
import '../../../../l10n/app_localizations.dart';
import '../../shared/trainer_fab.dart';
import '../../shared/trainer_layout.dart';
import '../../../../shared/widgets/app_snackbar.dart';
import '../../../../shared/widgets/confirm_delete_dialog.dart';
import '../../../../shared/widgets/ds/lifey_card.dart';
import '../../../../shared/widgets/ds/lifey_header.dart';
import '../../../../shared/widgets/ds/list_group.dart';
import '../../../../shared/widgets/empty_view.dart';
import '../../../../shared/widgets/error_view.dart';
import '../../../../shared/widgets/nav_collapse_controller.dart';
import '../../../../shared/widgets/trainer_view_menu.dart';
import '../../../chat/application/conversation_list_controller.dart';
import '../../clients/application/trainer_clients_controller.dart';
import '../../shared/filter_pill_row.dart';
import '../../shared/trainer_view_badge.dart';
import '../application/assignable_content.dart';
import '../application/assignments_controller.dart';
import '../domain/assignment.dart';
import 'widgets/assign_result_sheet.dart';
import 'widgets/assign_sheet.dart';

/// The trainer's second branch: what have I given people, and to whom
/// (docs/chat/41-trainer-mobile-v2-plan.md T4, frame E1) — in the v2 family
/// (canvas Lifey 6): the clay TRAINER mark over a large title, the filters as
/// pills, one card per assignment.
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

    Future<void> refresh() => ref.read(assignmentsControllerProvider.notifier).refresh();

    final header = LifeyHeader(
      title: l10n.trainerAssignmentsTitle,
      badge: const TrainerViewBadge(),
      // The mark is a 12/16 caps line in a padded pill; it grows with the text.
      badgeHeight: MediaQuery.textScalerOf(context).scale(16) + 2 * AppSpacing.s4,
      actions: [
        HeaderIconButton(
          icon: Icons.chat_bubble_outline_rounded,
          tooltip: l10n.chatOpenTooltip,
          showDot: (ref.watch(unreadBadgeProvider).value ?? 0) > 0,
          onPressed: () => context.push('/chat'),
        ),
        const TrainerViewMenu(inTrainerView: true),
      ],
    );

    final List<Widget> content = isOffline && !state.hasValue
        ? [
            SliverFillRemaining(
              child: EmptyView(
                icon: Icons.cloud_off,
                title: l10n.trainerOfflineTitle,
                subtitle: l10n.trainerOfflineMessage,
                action: FilledButton.tonal(onPressed: refresh, child: Text(l10n.retryButton)),
              ),
            ),
          ]
        : state.when(
            data: (rows) => _listSlivers(context, ref, rows),
            loading: () => const [SliverFillRemaining(child: Center(child: CircularProgressIndicator()))],
            error: (error, _) => [SliverFillRemaining(child: ErrorView(error: error, onRetry: refresh))],
          );

    return Scaffold(
      floatingActionButton: TrainerFabPadding(
        child: FloatingActionButton.extended(
          heroTag: null,
          onPressed: () => _assign(context, ref),
          icon: const Icon(Icons.add_rounded),
          label: Text(l10n.trainerAssignButton),
        ),
      ),
      body: ScrollCollapseListener(
        child: RefreshIndicator(
          edgeOffset: MediaQuery.paddingOf(context).top + 52,
          onRefresh: refresh,
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [header, ...content],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// List
// ---------------------------------------------------------------------------

List<Widget> _listSlivers(BuildContext context, WidgetRef ref, List<AssignmentRow> rows) {
  final l10n = AppLocalizations.of(context)!;
  final filter = ref.watch(assignmentFilterControllerProvider);
  final visible = rows.where(filter.matches).toList();
  final bottomPad = MediaQuery.paddingOf(context).bottom + (isTrainerTwoPane(context) ? AppSpacing.s24 : 96) + 72;

  // The empty state is its own filling sliver — EmptyView fills the viewport,
  // which a list row cannot be asked to do.
  if (rows.isEmpty) {
    return [
      SliverFillRemaining(
        child: EmptyView(
          icon: Icons.assignment_outlined,
          title: l10n.trainerNoAssignmentsTitle,
          subtitle: l10n.trainerNoAssignmentsMessage,
        ),
      ),
    ];
  }

  // Wide screens keep the list a readable column instead of stretching cards
  // across 1200 dp.
  Widget narrow(Widget child) => Center(
        child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: trainerContentMaxWidth), child: child),
      );

  return [
    SliverToBoxAdapter(child: narrow(const _FilterBar())),
    if (visible.isEmpty)
      SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 40, 24, 0),
          child: Text(
            l10n.trainerNoAssignmentsForFilterMessage,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: context.palette.text2),
          ),
        ),
      )
    else
      SliverList.builder(
        itemCount: visible.length,
        itemBuilder: (context, i) => narrow(
          Padding(
            padding: const EdgeInsets.fromLTRB(AppSpacing.screen, 0, AppSpacing.screen, AppSpacing.s12),
            child: _AssignmentTile(row: visible[i]),
          ),
        ),
      ),
    SliverToBoxAdapter(child: SizedBox(height: bottomPad)),
  ];
}

class _FilterBar extends ConsumerWidget {
  const _FilterBar();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final filter = ref.watch(assignmentFilterControllerProvider);
    final controller = ref.read(assignmentFilterControllerProvider.notifier);
    final clients = ref.watch(trainerClientsControllerProvider).value ?? const [];

    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.s8, bottom: AppSpacing.s16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          FilterPillRow(
            pills: [
              (
                label: l10n.trainerFilterAllTypesLabel,
                selected: filter.contentType == null,
                onTap: () => controller.selectType(null),
              ),
              (
                label: l10n.trainerContentTypeTemplateLabel,
                selected: filter.contentType == AssignableContentType.template,
                onTap: () => controller.selectType(AssignableContentType.template),
              ),
              (
                label: l10n.trainerContentTypeRecipeLabel,
                selected: filter.contentType == AssignableContentType.recipe,
                onTap: () => controller.selectType(AssignableContentType.recipe),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.s8),
          FilterPillRow(
            pills: [
              (
                label: l10n.trainerFilterAllClientsLabel,
                selected: filter.clientId == null,
                onTap: () => controller.selectClient(null),
              ),
              for (final client in clients)
                (
                  label: client.displayName,
                  selected: filter.clientId == client.userId,
                  onTap: () => controller.selectClient(client.userId),
                ),
            ],
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
      await ref.read(assignmentsControllerProvider.notifier).unassign(row.assignment.id);
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
    final p = context.palette;
    final mc = context.metricColors;
    final l10n = AppLocalizations.of(context)!;
    final f = LifeyFormat.of(context);

    final resolveName = ref.watch(assignedContentNameProvider);
    final contentName = resolveName(row.assignment.contentType, row.assignment.sourceId) ?? l10n.trainerDeletedContentLabel;
    final isTemplate = row.assignment.contentType == AssignableContentType.template;

    return LifeyCard(
      padding: const EdgeInsets.fromLTRB(AppSpacing.s16, AppSpacing.s12, AppSpacing.s4, AppSpacing.s12),
      child: Row(
        children: [
          // A workout in the primary colour, a recipe in the protein green — the
          // same pairing the rest of the app uses for training and food.
          ListIconHolder(
            icon: isTemplate ? Icons.fitness_center_rounded : Icons.restaurant_rounded,
            color: isTemplate ? theme.colorScheme.primary : mc.protein,
          ),
          const SizedBox(width: AppSpacing.s12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(contentName, maxLines: 1, overflow: TextOverflow.ellipsis, style: theme.textTheme.titleSmall),
                const SizedBox(height: 2),
                Text(
                  '${row.client.displayName} · ${f.fullDate(row.assignment.assignedAt.toLocal())}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(color: p.text2),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.remove_circle_outline_rounded),
            color: theme.colorScheme.error,
            tooltip: l10n.trainerUnassignTooltip,
            onPressed: () => _unassign(context, ref, contentName, l10n),
          ),
        ],
      ),
    );
  }
}
