import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/sync/connectivity_status_provider.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../shared/widgets/adaptive_app_bar.dart';
import '../../../../shared/widgets/empty_view.dart';
import '../../../../shared/widgets/error_view.dart';
import '../../../../shared/widgets/nav_collapse_controller.dart';
import '../../../../shared/widgets/trainer_view_menu.dart';
import '../../../chat/application/conversation_list_controller.dart';
import '../../shared/trainer_view_badge.dart';
import '../application/trainer_clients_controller.dart';
import '../domain/compliance.dart';
import '../domain/trainer_client.dart';
import 'widgets/client_card.dart';
import 'widgets/client_sort_chips.dart';

/// The trainer's daily entry point: who am I coaching, and who needs me today
/// (docs/chat/41-trainer-mobile-v2-plan.md, T1).
class TrainerClientsScreen extends ConsumerWidget {
  const TrainerClientsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final state = ref.watch(trainerClientsControllerProvider);
    final isOffline = ref.watch(isOfflineProvider).value ?? false;

    final statusTop = MediaQuery.paddingOf(context).top;
    final barTop = statusTop + 8.0;
    final contentTop = barTop + 58.0 + 12.0;

    Future<void> refresh() =>
        ref.read(trainerClientsControllerProvider.notifier).refresh();

    return Scaffold(
      body: ScrollCollapseListener(
        child: Stack(
          children: [
            Positioned.fill(
              child: RefreshIndicator(
                displacement: contentTop,
                onRefresh: refresh,
                // Offline is a first-class state here, not an edge case: the
                // trainer view keeps no local copy of client data (§2.2), so
                // with nothing loaded there is genuinely nothing to show.
                // Once a list *has* loaded, the app-wide offline banner is
                // enough — blanking a screen the trainer is reading would be
                // worse than letting them finish reading it.
                child: isOffline && !state.hasValue
                    ? _OfflineView(onRetry: refresh)
                    : state.when(
                        data: (clients) => clients.isEmpty
                            ? EmptyView(
                                icon: Icons.group_outlined,
                                title: l10n.trainerClientsEmptyTitle,
                                subtitle: l10n.trainerClientsEmptyMessage,
                              )
                            : _ClientList(clients: clients, contentTop: contentTop),
                        loading: () => const Center(child: CircularProgressIndicator()),
                        error: (error, _) => ErrorView(error: error, onRetry: refresh),
                      ),
              ),
            ),
            Positioned(
              top: barTop,
              left: 12,
              right: 12,
              child: AdaptiveAppBar(
                title: l10n.trainerClientsTitle,
                titleBadge: const TrainerViewBadge(),
                actions: [
                  // Same entry point as the client side, same badge — the
                  // chat is one feature both roles share (40-es terv).
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

class _ClientList extends ConsumerWidget {
  const _ClientList({required this.clients, required this.contentTop});

  final List<TrainerClient> clients;
  final double contentTop;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final sort = ref.watch(clientSortControllerProvider);
    final bottomPad = MediaQuery.paddingOf(context).bottom + 24;

    // One instant for the whole build: sorting, badges and "days ago" must
    // not disagree because they each called DateTime.now() a millisecond
    // apart.
    final now = DateTime.now();
    final sorted = sortClients(clients, sort, now: now);
    final needsAttention =
        sorted.where((c) => complianceFor(c, now: now).needsAttention).toList();
    final rest = sorted
        .where((c) => !complianceFor(c, now: now).needsAttention)
        .toList();

    Widget card(TrainerClient client) => Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
          child: ClientCard(client: client, now: now),
        );

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: EdgeInsets.only(top: contentTop, bottom: bottomPad),
      children: [
        ClientSortChips(
          selected: sort,
          onSelected: (option) =>
              ref.read(clientSortControllerProvider.notifier).select(option),
        ),
        const SizedBox(height: 12),
        // The block disappears entirely when nobody is flagged — an empty
        // "needs attention" heading would be a false alarm every day it is
        // read (frame B2).
        if (needsAttention.isNotEmpty) ...[
          _SectionHeader(title: l10n.trainerClientsNeedsAttentionTitle),
          ...needsAttention.map(card),
          _SectionHeader(title: l10n.trainerClientsAllClientsTitle),
        ],
        ...rest.map(card),
      ],
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      child: Text(
        title,
        style: theme.textTheme.labelLarge?.copyWith(
          fontWeight: FontWeight.w800,
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
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
