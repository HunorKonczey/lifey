import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../l10n/app_localizations.dart';
import '../../../../../shared/widgets/empty_view.dart';
import '../../../../../shared/widgets/error_view.dart';
import '../../application/client_sessions_controller.dart';
import '../widgets/session_card.dart';
import '../widgets/session_detail_sheet.dart';

/// The client's training history, and the only tab that writes anything
/// (docs/chat/41-trainer-mobile-v2-plan.md T3).
///
/// No read-only badge here, deliberately: this tab has an edit affordance, so
/// the badge's promise would be false.
class ClientWorkoutsTab extends ConsumerWidget {
  const ClientWorkoutsTab({
    super.key,
    required this.clientId,
    required this.offline,
  });

  final int clientId;
  final bool offline;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final state = ref.watch(clientSessionsControllerProvider(clientId));
    final controller =
        ref.read(clientSessionsControllerProvider(clientId).notifier);

    Widget body;
    if (state.loading) {
      body = const Center(child: CircularProgressIndicator());
    } else if (state.error != null && state.sessions.isEmpty) {
      body = offline
          ? EmptyView(
              icon: Icons.cloud_off,
              title: l10n.trainerOfflineTitle,
              subtitle: l10n.trainerOfflineMessage,
              action: FilledButton.tonal(
                onPressed: controller.refresh,
                child: Text(l10n.retryButton),
              ),
            )
          : ErrorView(error: state.error!, onRetry: controller.refresh);
    } else if (state.sessions.isEmpty) {
      body = EmptyView(
        icon: Icons.fitness_center,
        title: l10n.trainerNoSessionsTitle,
        subtitle: l10n.trainerNoSessionsMessage,
      );
    } else {
      body = NotificationListener<ScrollNotification>(
        // Paging on approach rather than on a button: the trainer scrolls
        // back through weeks, and a "load more" tap every twenty rows is
        // twenty taps they did not ask for.
        onNotification: (notification) {
          final metrics = notification.metrics;
          if (metrics.axis == Axis.vertical &&
              metrics.pixels >= metrics.maxScrollExtent - 400) {
            controller.loadMore();
          }
          return false;
        },
        child: ListView.builder(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
          itemCount: state.sessions.length + (state.hasMore ? 1 : 0),
          itemBuilder: (context, index) {
            if (index == state.sessions.length) {
              return const Padding(
                padding: EdgeInsets.symmetric(vertical: 20),
                child: Center(child: CircularProgressIndicator()),
              );
            }
            final session = state.sessions[index];
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: SessionCard(
                session: session,
                onTap: () => SessionDetailSheet.show(
                  context,
                  clientId: clientId,
                  sessionId: session.id,
                ),
              ),
            );
          },
        ),
      );
    }

    return RefreshIndicator(onRefresh: controller.refresh, child: body);
  }
}
