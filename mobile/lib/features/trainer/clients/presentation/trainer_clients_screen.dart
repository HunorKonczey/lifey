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

    final list = ScrollCollapseListener(
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
                                // T1 could only point at the web here; T7
                                // brought the invite flow onto the phone.
                                action: FilledButton.tonalIcon(
                                  onPressed: () =>
                                      context.push(trainerInvitesLocation),
                                  icon: const Icon(Icons.mail_outline, size: 18),
                                  label: Text(l10n.trainerSendInviteButton),
                                ),
                              )
                            : _ClientList(
                                clients: clients,
                                contentTop: contentTop,
                                twoPane: twoPane,
                              ),
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
                    icon: Icons.person_add_alt,
                    tooltip: l10n.trainerInvitesTitle,
                    onPressed: () => context.push(trainerInvitesLocation),
                  ),
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

class _ClientList extends ConsumerWidget {
  const _ClientList({
    required this.clients,
    required this.contentTop,
    required this.twoPane,
  });

  final List<TrainerClient> clients;
  final double contentTop;

  /// On a tablet a tap picks the pane's client; on a phone it pushes the
  /// detail screen, exactly as before.
  final bool twoPane;

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

    final selected = ref.watch(selectedClientControllerProvider);

    Widget card(TrainerClient client) => Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
          child: ClientCard(
            client: client,
            now: now,
            selected: twoPane && client.userId == selected,
            onTap: () => twoPane
                ? ref
                    .read(selectedClientControllerProvider.notifier)
                    .select(client.userId)
                : context.push('$trainerShellLocation/${client.userId}'),
          ),
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
