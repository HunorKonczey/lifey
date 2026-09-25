import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/sync/connectivity_status_provider.dart';
import '../../../../core/theme/app_tokens.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../shared/widgets/ds/lifey_header.dart';
import '../../../../shared/widgets/ds/section_label.dart';
import '../../../../shared/widgets/empty_view.dart';
import '../../../../shared/widgets/error_view.dart';
import '../../../../shared/widgets/nav_collapse_controller.dart';
import '../../../../shared/widgets/trainer_view_menu.dart';
import '../../../chat/application/conversation_list_controller.dart';
import '../../client_detail/presentation/client_detail_screen.dart';
import '../../shared/trainer_layout.dart';
import '../../shared/trainer_view_badge.dart';
import '../application/selected_client_controller.dart';
import '../application/trainer_clients_controller.dart';
import '../domain/compliance.dart';
import '../domain/trainer_client.dart';
import 'widgets/client_card.dart';
import 'widgets/client_sort_chips.dart';

/// The trainer's daily entry point: who am I coaching, and who needs me today
/// (docs/chat/41-trainer-mobile-v2-plan.md, T1; canvas Lifey 6 › 9.1): the clay
/// "TRAINER" mark over a large "My clients" title with add-person, chat and the
/// view switch, the sort pills, and one card per client.
class TrainerClientsScreen extends ConsumerWidget {
  const TrainerClientsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final state = ref.watch(trainerClientsControllerProvider);
    final isOffline = ref.watch(isOfflineProvider).value ?? false;
    final twoPane = isTrainerTwoPane(context);

    Future<void> refresh() =>
        ref.read(trainerClientsControllerProvider.notifier).refresh();

    // A client who is no longer on the list must not stay in the pane beside
    // it — the relationship may have ended while the tablet was open.
    ref.listen(trainerClientsControllerProvider, (_, next) {
      next.whenData((clients) => ref
          .read(selectedClientControllerProvider.notifier)
          .keepOnlyIfPresent(clients.map((client) => client.userId)));
    });

    final header = LifeyHeader(
      title: l10n.trainerClientsTitle,
      badge: const TrainerViewBadge(),
      // The mark is a 12/16 caps line in a padded pill; it grows with the text.
      badgeHeight: MediaQuery.textScalerOf(context).scale(16) + 2 * AppSpacing.s4,
      actions: [
        HeaderIconButton(
          icon: Icons.person_add_alt_1_rounded,
          tooltip: l10n.trainerInvitesTitle,
          onPressed: () => context.push(trainerInvitesLocation),
        ),
        // Same entry point as the client side — the chat is one feature both
        // roles share (40-es terv).
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
        // Offline is a first-class state here, not an edge case: the trainer
        // view keeps no local copy of client data (§2.2), so with nothing
        // loaded there is genuinely nothing to show. Once a list *has* loaded,
        // the app-wide offline banner is enough — blanking a screen the
        // trainer is reading would be worse than letting them finish reading it.
        ? [SliverFillRemaining(child: _OfflineView(onRetry: refresh))]
        : state.when(
            data: (clients) => clients.isEmpty
                ? [
                    SliverFillRemaining(
                      child: EmptyView(
                        icon: Icons.group_outlined,
                        title: l10n.trainerClientsEmptyTitle,
                        subtitle: l10n.trainerClientsEmptyMessage,
                        // T1 could only point at the web here; T7 brought the
                        // invite flow onto the phone.
                        action: FilledButton.tonalIcon(
                          onPressed: () => context.push(trainerInvitesLocation),
                          icon: const Icon(Icons.mail_outline, size: 18),
                          label: Text(l10n.trainerSendInviteButton),
                        ),
                      ),
                    ),
                  ]
                : _clientSlivers(context, ref, clients, twoPane: twoPane),
            loading: () => const [SliverFillRemaining(child: Center(child: CircularProgressIndicator()))],
            error: (error, _) => [SliverFillRemaining(child: ErrorView(error: error, onRetry: refresh))],
          );

    final list = ScrollCollapseListener(
      child: RefreshIndicator(
        edgeOffset: MediaQuery.paddingOf(context).top + 52,
        onRefresh: refresh,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [header, ...content],
        ),
      ),
    );

    // Tablet: the list keeps its place while the detail changes beside it
    // (docs/chat/41-trainer-mobile-v2-plan.md §8.2).
    return Scaffold(
      body: twoPane
          ? TrainerTwoPane(list: list, detail: const _ClientDetailPane())
          : list,
    );
  }
}

/// The right-hand pane: the picked client, or an invitation to pick one.
class _ClientDetailPane extends ConsumerWidget {
  const _ClientDetailPane();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(selectedClientControllerProvider);
    final l10n = AppLocalizations.of(context)!;

    if (selected == null) {
      return EmptyView(
        icon: Icons.touch_app_outlined,
        title: l10n.trainerPickClientTitle,
        subtitle: l10n.trainerPickClientMessage,
      );
    }
    // Keyed so switching clients rebuilds the tabs against the new one rather
    // than keeping the previous client's scroll and tab state.
    return ClientDetailScreen(
      key: ValueKey(selected),
      clientId: selected,
      embedded: true,
    );
  }
}

// ---------------------------------------------------------------------------
// List
// ---------------------------------------------------------------------------

List<Widget> _clientSlivers(
  BuildContext context,
  WidgetRef ref,
  List<TrainerClient> clients, {
  required bool twoPane,
}) {
  final l10n = AppLocalizations.of(context)!;
  final sort = ref.watch(clientSortControllerProvider);
  final bottomPad = MediaQuery.paddingOf(context).bottom + 96;

  // One instant for the whole build: sorting, chips and "days ago" must not
  // disagree because they each called DateTime.now() a millisecond apart.
  final now = DateTime.now();
  final sorted = sortClients(clients, sort, now: now);
  final needsAttention = sorted.where((c) => complianceFor(c, now: now).needsAttention).toList();
  final rest = sorted.where((c) => !complianceFor(c, now: now).needsAttention).toList();
  final selected = ref.watch(selectedClientControllerProvider);

  Widget card(TrainerClient client) => Padding(
        padding: const EdgeInsets.fromLTRB(AppSpacing.screen, 0, AppSpacing.screen, AppSpacing.s12),
        child: ClientCard(
          client: client,
          now: now,
          selected: twoPane && client.userId == selected,
          onTap: () => twoPane
              ? ref.read(selectedClientControllerProvider.notifier).select(client.userId)
              : context.push('$trainerShellLocation/${client.userId}'),
        ),
      );

  Widget section(String title) => Padding(
        padding: const EdgeInsets.fromLTRB(AppSpacing.screen, AppSpacing.s8, AppSpacing.screen, AppSpacing.s8),
        child: SectionLabel(title),
      );

  return [
    SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.only(top: AppSpacing.s8, bottom: AppSpacing.s16),
        child: ClientSortChips(
          selected: sort,
          onSelected: (option) => ref.read(clientSortControllerProvider.notifier).select(option),
        ),
      ),
    ),
    // The block disappears entirely when nobody is flagged — an empty "needs
    // attention" heading would be a false alarm every day it is read
    // (frame B2).
    if (needsAttention.isNotEmpty) ...[
      SliverToBoxAdapter(child: section(l10n.trainerClientsNeedsAttentionTitle)),
      SliverList.builder(
        itemCount: needsAttention.length,
        itemBuilder: (context, i) => card(needsAttention[i]),
      ),
      SliverToBoxAdapter(child: section(l10n.trainerClientsAllClientsTitle)),
    ],
    SliverList.builder(itemCount: rest.length, itemBuilder: (context, i) => card(rest[i])),
    SliverToBoxAdapter(child: SizedBox(height: bottomPad)),
  ];
}

// ---------------------------------------------------------------------------
// Offline
// ---------------------------------------------------------------------------

class _OfflineView extends StatelessWidget {
  const _OfflineView({required this.onRetry});

  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return EmptyView(
      icon: Icons.cloud_off,
      title: l10n.trainerOfflineTitle,
      subtitle: l10n.trainerOfflineMessage,
      action: FilledButton.tonal(
        onPressed: onRetry,
        child: Text(l10n.retryButton),
      ),
    );
  }
}
