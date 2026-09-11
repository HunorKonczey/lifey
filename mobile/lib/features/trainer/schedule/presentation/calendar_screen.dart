import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/sync/connectivity_status_provider.dart';
import '../../../../core/theme/app_tokens.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../shared/widgets/adaptive_app_bar.dart';
import '../../../../shared/widgets/empty_view.dart';
import '../../../../shared/widgets/error_view.dart';
import '../../../../shared/widgets/nav_collapse_controller.dart';
import '../../../../shared/widgets/trainer_view_menu.dart';
import '../../../chat/application/conversation_list_controller.dart';
import '../../clients/application/trainer_clients_controller.dart';
import '../../clients/domain/trainer_client.dart';
import '../../shared/client_avatar.dart';
import '../application/calendar_controller.dart';
import '../application/recurrence_text.dart';
import '../domain/schedule.dart';
import 'widgets/month_overview.dart';
import 'widgets/occurrence_status_chip.dart';
import 'widgets/session_peek_sheet.dart';
import 'widgets/week_strip.dart';

/// The trainer's calendar: who is training, when (docs/chat/41 T5, frame F).
///
/// The agenda is the default and the month is secondary — the reverse of the
/// web, and the whole point of T5 being a redesign rather than a port.
class TrainerCalendarScreen extends ConsumerStatefulWidget {
  const TrainerCalendarScreen({super.key});

  @override
  ConsumerState<TrainerCalendarScreen> createState() =>
      _TrainerCalendarScreenState();
}

class _TrainerCalendarScreenState extends ConsumerState<TrainerCalendarScreen> {
  bool _monthView = false;
  DateTime _selectedDay = dateOnly(DateTime.now());

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final locale = Localizations.localeOf(context).toString();
    final weekStart = ref.watch(calendarWeekControllerProvider);
    final isOffline = ref.watch(isOfflineProvider).value ?? false;
    final filter = ref.watch(calendarClientFilterProvider);

    final statusTop = MediaQuery.paddingOf(context).top;
    final barTop = statusTop + 8.0;
    final contentTop = barTop + 58.0 + 12.0;

    // The agenda reads a week; the month view reads a month. Two ranges, two
    // cache entries, so switching back and forth costs nothing.
    final range = _monthView
        ? (
            from: DateTime(weekStart.year, weekStart.month),
            to: DateTime(weekStart.year, weekStart.month + 1, 0),
          )
        : (from: weekStart, to: weekStart.add(const Duration(days: 6)));

    final sessions = ref.watch(calendarSessionsProvider(range));
    final clients = ref.watch(trainerClientsControllerProvider).value ?? const [];

    Future<void> refresh() async {
      ref.invalidate(calendarSessionsProvider(range));
      await ref.read(calendarSessionsProvider(range).future);
    }

    List<CalendarSession> visible(List<CalendarSession> all) {
      final controller = ref.read(calendarClientFilterProvider.notifier);
      return all.where((s) => controller.isVisible(s.clientId)).toList();
    }

    return Scaffold(
      body: ScrollCollapseListener(
        child: Stack(
          children: [
            Positioned.fill(
              child: Padding(
                padding: EdgeInsets.only(top: contentTop),
                child: sessions.when(
                  data: (all) => _Body(
                    sessions: visible(all),
                    clients: clients,
                    weekStart: weekStart,
                    selectedDay: _selectedDay,
                    monthView: _monthView,
                    onSelectDay: (day) => setState(() {
                      _selectedDay = day;
                      _monthView = false;
                      ref
                          .read(calendarWeekControllerProvider.notifier)
                          .showWeekOf(day);
                    }),
                    onRefresh: refresh,
                  ),
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (error, _) => isOffline
                      ? EmptyView(
                          icon: Icons.cloud_off,
                          title: l10n.trainerOfflineTitle,
                          subtitle: l10n.trainerOfflineMessage,
                          action: FilledButton.tonal(
                            onPressed: refresh,
                            child: Text(l10n.retryButton),
                          ),
                        )
                      : ErrorView(error: error, onRetry: refresh),
                ),
              ),
            ),
            Positioned(
              top: barTop,
              left: 12,
              right: 12,
              child: AdaptiveAppBar(
                title: _monthView
                    ? DateFormat.yMMMM(locale).format(weekStart)
                    : l10n.trainerCalendarTitle,
                titleBadge: filter.isEmpty
                    ? null
                    : _FilterChip(
                        count: filter.length,
                        onClear: () =>
                            ref.read(calendarClientFilterProvider.notifier).clear(),
                      ),
                actions: [
                  AdaptiveAppBarAction(
                    icon: _monthView ? Icons.view_agenda_outlined : Icons.calendar_month,
                    tooltip: _monthView
                        ? l10n.trainerAgendaViewTooltip
                        : l10n.trainerMonthViewTooltip,
                    onPressed: () => setState(() => _monthView = !_monthView),
                  ),
                  AdaptiveAppBarAction(
                    icon: Icons.filter_alt_outlined,
                    tooltip: l10n.trainerCalendarFilterTooltip,
                    onPressed: () => _openFilter(context, clients),
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
      ),
    );
  }

  void _openFilter(BuildContext context, List<TrainerClient> clients) {
    showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      showDragHandle: true,
      builder: (_) => _ClientFilterSheet(clients: clients),
    );
  }
}

// ---------------------------------------------------------------------------

class _Body extends ConsumerWidget {
  const _Body({
    required this.sessions,
    required this.clients,
    required this.weekStart,
    required this.selectedDay,
    required this.monthView,
    required this.onSelectDay,
    required this.onRefresh,
  });

  final List<CalendarSession> sessions;
  final List<TrainerClient> clients;
  final DateTime weekStart;
  final DateTime selectedDay;
  final bool monthView;
  final ValueChanged<DateTime> onSelectDay;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (monthView) {
      return RefreshIndicator(
        onRefresh: onRefresh,
        child: MonthOverview(
          month: weekStart,
          sessions: sessions,
          onSelectDay: onSelectDay,
        ),
      );
    }

    final weekController = ref.read(calendarWeekControllerProvider.notifier);
    return Column(
      children: [
        WeekStrip(
          weekStart: weekStart,
          selectedDay: selectedDay,
          sessions: sessions,
          onSelectDay: onSelectDay,
          onPreviousWeek: weekController.previousWeek,
          onNextWeek: weekController.nextWeek,
        ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: onRefresh,
            child: _Agenda(
              sessions: sessions,
              clients: clients,
              weekStart: weekStart,
              onChanged: onRefresh,
            ),
          ),
        ),
      ],
    );
  }
}

/// The week, day by day. Days with nothing on them are skipped rather than
/// shown empty — seven "nothing scheduled" rows is a lot of nothing.
class _Agenda extends ConsumerWidget {
  const _Agenda({
    required this.sessions,
    required this.clients,
    required this.weekStart,
    required this.onChanged,
  });

  final List<CalendarSession> sessions;
  final List<TrainerClient> clients;
  final DateTime weekStart;
  final Future<void> Function() onChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    final locale = Localizations.localeOf(context).toString();
    final dayFormat = DateFormat.MMMEd(locale);

    if (sessions.isEmpty) {
      return EmptyView(
        icon: Icons.event_available_outlined,
        title: l10n.trainerNoSessionsThisWeekTitle,
        subtitle: l10n.trainerNoSessionsThisWeekMessage,
      );
    }

    final rows = <Widget>[];
    for (var i = 0; i < 7; i++) {
      final day = DateTime(weekStart.year, weekStart.month, weekStart.day + i);
      final ofDay = sessionsOfDay(sessions, day);
      if (ofDay.isEmpty) continue;

      rows.add(Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
        child: Text(
          dayFormat.format(day),
          style: theme.textTheme.labelLarge?.copyWith(
            fontWeight: FontWeight.w800,
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ));

      var untimedDividerAdded = false;
      for (final session in ofDay) {
        // Untimed occurrences sit at the end of the day under their own
        // quiet divider, rather than pretending to a time they do not have.
        if (session.scheduledTime == null && !untimedDividerAdded) {
          untimedDividerAdded = true;
          rows.add(Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
            child: Text(
              l10n.trainerDuringTheDayLabel,
              style: theme.textTheme.labelSmall
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
          ));
        }
        rows.add(Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: _AgendaCard(
            session: session,
            client: _clientOf(session),
            onChanged: onChanged,
          ),
        ));
      }
    }

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: EdgeInsets.only(bottom: MediaQuery.paddingOf(context).bottom + 90),
      children: rows,
    );
  }

  TrainerClient? _clientOf(CalendarSession session) {
    for (final client in clients) {
      if (client.userId == session.clientId) return client;
    }
    return null;
  }
}

class _AgendaCard extends ConsumerWidget {
  const _AgendaCard({
    required this.session,
    required this.client,
    required this.onChanged,
  });

  final CalendarSession session;
  final TrainerClient? client;
  final Future<void> Function() onChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final l10n = AppLocalizations.of(context)!;

    return Material(
      color: scheme.surfaceContainer,
      borderRadius: AppRadius.cardAll,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () async {
          final cancelled = await SessionPeekSheet.show(
            context,
            session: session,
            client: client,
          );
          if (cancelled ?? false) await onChanged();
        },
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              SizedBox(
                width: 44,
                child: Text(
                  session.scheduledTime == null
                      ? '—'
                      : formatScheduleTime(session.scheduledTime!),
                  style: theme.textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              if (client != null) ...[
                ClientAvatar(client: client!, size: 34),
                const SizedBox(width: 10),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      client?.displayName ??
                          session.clientEmail ??
                          l10n.trainerUnknownClientLabel,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyMedium
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    Text(
                      session.templateName ?? l10n.trainerFreeWorkoutLabel,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.labelSmall
                          ?.copyWith(color: scheme.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              OccurrenceStatusChip(status: session.status),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------

class _FilterChip extends StatelessWidget {
  const _FilterChip({required this.count, required this.onClear});

  final int count;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;

    return InkWell(
      onTap: onClear,
      borderRadius: AppRadius.pill,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: scheme.tertiaryContainer,
          borderRadius: AppRadius.pill,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              l10n.trainerCalendarFilterChipLabel(count),
              style: TextStyle(
                fontFamily: 'PlusJakartaSans',
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: scheme.onTertiaryContainer,
              ),
            ),
            const SizedBox(width: 4),
            Icon(Icons.close, size: 12, color: scheme.onTertiaryContainer),
          ],
        ),
      ),
    );
  }
}

class _ClientFilterSheet extends ConsumerWidget {
  const _ClientFilterSheet({required this.clients});

  final List<TrainerClient> clients;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final selected = ref.watch(calendarClientFilterProvider);
    final controller = ref.read(calendarClientFilterProvider.notifier);

    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 12, 4),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    l10n.trainerCalendarFilterTitle,
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(fontWeight: FontWeight.w800),
                  ),
                ),
                if (selected.isNotEmpty)
                  TextButton(
                    onPressed: controller.clear,
                    child: Text(l10n.trainerCalendarFilterClearAction),
                  ),
              ],
            ),
          ),
          Flexible(
            child: ListView(
              shrinkWrap: true,
              children: [
                for (final client in clients)
                  CheckboxListTile(
                    value: selected.contains(client.userId),
                    onChanged: (_) => controller.toggle(client.userId),
                    secondary: ClientAvatar(client: client, size: 34),
                    title: Text(client.displayName),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
