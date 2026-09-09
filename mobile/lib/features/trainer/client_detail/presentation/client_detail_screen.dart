import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/sync/connectivity_status_provider.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../shared/widgets/empty_view.dart';
import '../../../../shared/widgets/error_view.dart';
import '../../clients/application/trainer_clients_controller.dart';
import '../application/client_detail_entry.dart';
import '../application/client_detail_tab_preference.dart';
import '../domain/client_detail_tab.dart';
import 'tabs/nutrition_tab.dart';
import 'tabs/overview_tab.dart';
import 'tabs/statistics_tab.dart';
import 'tabs/workouts_tab.dart';
import 'tabs/steps_tab.dart';
import 'tabs/weight_tab.dart';
import 'widgets/client_detail_header.dart';

/// Everything the trainer can see about one client — read-only in T2
/// (docs/chat/41-trainer-mobile-v2-plan.md).
///
/// Reached by tapping a client card, from a chat thread's "view their data",
/// or by a deep link straight to `/trainer/clients/{id}`. That last case is
/// why the header waits on the client list rather than assuming it: arriving
/// from outside, there may be nothing loaded yet.
class ClientDetailScreen extends ConsumerWidget {
  const ClientDetailScreen({super.key, required this.clientId});

  final int clientId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final client = ref.watch(trainerClientProvider(clientId));

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: client.when(
          data: (client) => client == null
              ? EmptyView(
                  icon: Icons.person_off_outlined,
                  // Not an error: the relationship may simply have ended
                  // while this link was sitting in someone's notifications.
                  title: l10n.trainerClientNotFoundTitle,
                  subtitle: l10n.trainerClientNotFoundMessage,
                )
              : _Loaded(client: client),
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => ErrorView(
            error: error,
            onRetry: () =>
                ref.read(trainerClientsControllerProvider.notifier).refresh(),
          ),
        ),
      ),
    );
  }
}

class _Loaded extends ConsumerStatefulWidget {
  const _Loaded({required this.client});

  final TrainerClientSummary client;

  @override
  ConsumerState<_Loaded> createState() => _LoadedState();
}

class _LoadedState extends ConsumerState<_Loaded>
    with SingleTickerProviderStateMixin {
  late final TabController _controller = TabController(
    length: ClientDetailTab.values.length,
    vsync: this,
    initialIndex: widget.client.initialTab.index,
  )..addListener(_rememberTab);

  @override
  void dispose() {
    _controller.removeListener(_rememberTab);
    _controller.dispose();
    super.dispose();
  }

  void _rememberTab() {
    if (_controller.indexIsChanging) return;
    ref.read(clientDetailTabPreferenceProvider).setLastTab(
          widget.client.client.userId,
          ClientDetailTab.values[_controller.index],
        );
  }

  void _openTab(ClientDetailTab tab) => _controller.animateTo(tab.index);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    final clientId = widget.client.client.userId;
    final offline = ref.watch(isOfflineProvider).value ?? false;

    String label(ClientDetailTab tab) => switch (tab) {
          ClientDetailTab.overview => l10n.trainerTabOverviewLabel,
          ClientDetailTab.statistics => l10n.trainerTabStatisticsLabel,
          ClientDetailTab.workouts => l10n.trainerTabWorkoutsLabel,
          ClientDetailTab.nutrition => l10n.trainerTabNutritionLabel,
          ClientDetailTab.steps => l10n.trainerTabStepsLabel,
          ClientDetailTab.weight => l10n.trainerTabWeightLabel,
        };

    const icons = {
      ClientDetailTab.overview: Icons.dashboard_outlined,
      ClientDetailTab.statistics: Icons.bar_chart,
      ClientDetailTab.workouts: Icons.fitness_center,
      ClientDetailTab.nutrition: Icons.restaurant_outlined,
      ClientDetailTab.steps: Icons.directions_walk,
      ClientDetailTab.weight: Icons.monitor_weight_outlined,
    };

    return Column(
      children: [
        ClientDetailHeader(client: widget.client.client),
        // Five tabs do not fit a phone's width as text, and two rows would
        // push the content below the fold. A scrolling row keeps every label
        // readable and the first tabs visible where the thumb is.
        TabBar(
          controller: _controller,
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          indicatorColor: theme.colorScheme.tertiary,
          labelColor: theme.colorScheme.onSurface,
          unselectedLabelColor: theme.colorScheme.onSurfaceVariant,
          dividerColor: Colors.transparent,
          tabs: [
            for (final tab in ClientDetailTab.values)
              Tab(icon: Icon(icons[tab], size: 18), text: label(tab), height: 58),
          ],
        ),
        Expanded(
          child: TabBarView(
            controller: _controller,
            children: [
              ClientOverviewTab(
                clientId: clientId,
                onOpenTab: _openTab,
                offline: offline,
              ),
              ClientStatisticsTab(clientId: clientId, offline: offline),
              ClientWorkoutsTab(clientId: clientId, offline: offline),
              ClientNutritionTab(clientId: clientId, offline: offline),
              ClientStepsTab(clientId: clientId, offline: offline),
              ClientWeightTab(clientId: clientId, offline: offline),
            ],
          ),
        ),
      ],
    );
  }
}
