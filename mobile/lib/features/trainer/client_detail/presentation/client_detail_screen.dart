import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/network/error_message.dart';
import '../../../../core/sync/connectivity_status_provider.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../shared/widgets/app_snackbar.dart';
import '../../../../shared/widgets/ds/lifey_header.dart';
import '../../../../shared/widgets/empty_view.dart';
import '../../../../shared/widgets/error_view.dart';
import '../../../chat/data/chat_repository.dart';
import '../../clients/application/trainer_clients_controller.dart';
import '../../programs/application/programs_controller.dart';
import '../../schedule/application/client_schedules_controller.dart';
import '../../schedule/presentation/widgets/create_schedule_sheet.dart';
import '../application/client_detail_entry.dart';
import '../application/client_detail_tab_preference.dart';
import '../domain/client_detail_tab.dart';
import 'tabs/nutrition_tab.dart';
import 'tabs/schedule_tab.dart';
import 'tabs/overview_tab.dart';
import 'tabs/statistics_tab.dart';
import 'tabs/workouts_tab.dart';
import 'tabs/steps_tab.dart';
import 'tabs/weight_tab.dart';
import 'widgets/client_action_bar.dart';
import 'widgets/client_detail_header.dart';
import 'widgets/client_tab_bar.dart';

/// Everything the trainer can see about one client — read-only in T2
/// (docs/chat/41-trainer-mobile-v2-plan.md).
///
/// Reached by tapping a client card, from a chat thread's "view their data",
/// or by a deep link straight to `/trainer/clients/{id}`. That last case is
/// why the header waits on the client list rather than assuming it: arriving
/// from outside, there may be nothing loaded yet.
class ClientDetailScreen extends ConsumerWidget {
  const ClientDetailScreen({super.key, required this.clientId, this.embedded = false});

  final int clientId;

  /// True when this is the detail pane of a two-pane tablet layout rather
  /// than a pushed screen (§8.2): there is nothing to go back to, so the
  /// header drops its back button.
  final bool embedded;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final client = ref.watch(trainerClientProvider(clientId));

    // The loaded screen builds its own Scaffold (its header needs the
    // client); the states without one get the same header, bare, so there is
    // still a way back from a spinner or an error.
    Widget bare(Widget body) => Scaffold(
          appBar: LifeySubpageHeader(title: l10n.trainerClientFallbackTitle, showBack: !embedded),
          body: body,
        );

    return client.when(
      data: (client) => client == null
          ? bare(
              EmptyView(
                icon: Icons.person_off_outlined,
                // Not an error: the relationship may simply have ended
                // while this link was sitting in someone's notifications.
                title: l10n.trainerClientNotFoundTitle,
                subtitle: l10n.trainerClientNotFoundMessage,
              ),
            )
          : _Loaded(client: client, embedded: embedded),
      loading: () => bare(const Center(child: CircularProgressIndicator())),
      error: (error, _) => bare(
        ErrorView(
          error: error,
          onRetry: () => ref.read(trainerClientsControllerProvider.notifier).refresh(),
        ),
      ),
    );
  }
}

class _Loaded extends ConsumerStatefulWidget {
  const _Loaded({required this.client, required this.embedded});

  final TrainerClientSummary client;
  final bool embedded;

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

  bool _openingChat = false;

  Future<void> _openChat() async {
    if (_openingChat) return;
    setState(() => _openingChat = true);
    try {
      final conversationId =
          await ref.read(chatRepositoryProvider).openConversationWith(widget.client.client.userId);
      if (mounted) context.push('/chat/$conversationId');
    } catch (error) {
      if (mounted) AppSnackbar.showError(context, title: friendlyError(error));
    } finally {
      if (mounted) setState(() => _openingChat = false);
    }
  }

  Future<void> _schedule() async {
    final clientId = widget.client.client.userId;
    final created = await CreateScheduleSheet.show(context, clientId: clientId);
    if (created != true) return;
    // The schedule tab reads these; it may be showing the old list.
    ref.invalidate(clientSchedulesProvider(clientId));
    ref.invalidate(clientUpcomingOccurrencesProvider(clientId));
    ref.invalidate(clientProgramAssignmentsProvider(clientId));
  }

  @override
  Widget build(BuildContext context) {
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
          ClientDetailTab.schedule => l10n.trainerTabScheduleLabel,
        };

    return Scaffold(
      appBar: ClientDetailHeader(
        client: widget.client.client,
        showBack: !widget.embedded,
        onMessage: _openChat,
        openingChat: _openingChat,
      ),
      body: Column(
        children: [
          // Seven tabs do not fit a phone's width as text, and two rows would
          // push the content below the fold. A scrolling row keeps every label
          // readable and the first tabs visible where the thumb is.
          ClientTabBar(
            controller: _controller,
            labels: [for (final tab in ClientDetailTab.values) label(tab)],
          ),
          ClientActionBar(onMessage: _openChat, onSchedule: _schedule, busy: _openingChat),
          Expanded(
            child: TabBarView(
              controller: _controller,
              children: [
                ClientOverviewTab(
                  clientId: clientId,
                  onOpenTab: _openTab,
                  offline: offline,
                  missedWorkoutCount: widget.client.client.missedWorkoutCount,
                ),
                ClientStatisticsTab(clientId: clientId, offline: offline),
                ClientWorkoutsTab(clientId: clientId, offline: offline),
                ClientNutritionTab(clientId: clientId, offline: offline),
                ClientStepsTab(clientId: clientId, offline: offline),
                ClientWeightTab(clientId: clientId, offline: offline),
                ClientScheduleTab(clientId: clientId, offline: offline),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
