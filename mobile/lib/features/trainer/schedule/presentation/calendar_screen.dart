import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/format/lifey_format.dart';
import '../../../../core/sync/connectivity_status_provider.dart';
import '../../../../core/theme/app_tokens.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../shared/widgets/ds/lifey_card.dart';
import '../../../../shared/widgets/ds/lifey_header.dart';
import '../../../../shared/widgets/ds/lifey_sheet.dart';
import '../../../../shared/widgets/ds/list_group.dart';
import '../../../../shared/widgets/ds/tinted_chip.dart';
import '../../../../shared/widgets/empty_view.dart';
import '../../../../shared/widgets/error_view.dart';
import '../../../../shared/widgets/nav_collapse_controller.dart';
import '../../../../shared/widgets/trainer_view_menu.dart';
import '../../../chat/application/conversation_list_controller.dart';
import '../../clients/application/trainer_clients_controller.dart';
import '../../clients/domain/trainer_client.dart';
import '../../shared/client_avatar.dart';
import '../../shared/trainer_layout.dart';
import '../../shared/trainer_view_badge.dart';
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
/// web, and the whole point of T5 being a redesign rather than a port. In the
/// v2 family (canvas Lifey 6): the clay TRAINER mark over a large title, the
/// view toggle / filter / chat / view switch as round header buttons, the week
/// strip and the agenda as cards under it.
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

    final header = LifeyHeader(
      title: _monthView ? DateFormat.yMMMM(locale).format(weekStart) : l10n.trainerCalendarTitle,
      badge: const TrainerViewBadge(),
      // The mark is a 12/16 caps line in a padded pill; it grows with the text.
      badgeHeight: MediaQuery.textScalerOf(context).scale(16) + 2 * AppSpacing.s4,
      actions: [
        HeaderIconButton(
          icon: _monthView ? Icons.view_agenda_rounded : Icons.calendar_month_rounded,
          tooltip: _monthView ? l10n.trainerAgendaViewTooltip : l10n.trainerMonthViewTooltip,
          onPressed: () => setState(() => _monthView = !_monthView),
        ),
        HeaderIconButton(
          icon: Icons.filter_alt_rounded,
          tooltip: l10n.trainerCalendarFilterTooltip,
          showDot: filter.isNotEmpty,
          onPressed: () => _openFilter(context, clients),
        ),
        HeaderIconButton(
          icon: Icons.chat_bubble_outline_rounded,
          tooltip: l10n.chatOpenTooltip,
          showDot: (ref.watch(unreadBadgeProvider).value ?? 0) > 0,
          onPressed: () => context.push('/chat'),
        ),
        const TrainerViewMenu(inTrainerView: true),
      ],
    );

    final List<Widget> content = sessions.when(
      data: (all) => _contentSlivers(
        context,
        sessions: visible(all),
        clients: clients,
        weekStart: weekStart,
        filterCount: filter.length,
        onRefresh: refresh,
      ),
      loading: () => const [SliverFillRemaining(child: Center(child: CircularProgressIndicator()))],
      error: (error, _) => [
        SliverFillRemaining(
          child: isOffline
              ? EmptyView(
                  icon: Icons.cloud_off,
                  title: l10n.trainerOfflineTitle,
                  subtitle: l10n.trainerOfflineMessage,
                  action: FilledButton.tonal(onPressed: refresh, child: Text(l10n.retryButton)),
                )
              : ErrorView(error: error, onRetry: refresh),
        ),
      ],
    );

    return Scaffold(
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

  /// What sits under the header once the week (or month) has loaded.
  List<Widget> _contentSlivers(
    BuildContext context, {
    required List<CalendarSession> sessions,
    required List<TrainerClient> clients,
    required DateTime weekStart,
    required int filterCount,
    required Future<void> Function() onRefresh,
  }) {
    final l10n = AppLocalizations.of(context)!;
    final weekController = ref.read(calendarWeekControllerProvider.notifier);
    // The rail replaces the floating bar on a tablet, so there is no bar to clear.
    final bottomPad = MediaQuery.paddingOf(context).bottom + (isTrainerTwoPane(context) ? AppSpacing.s24 : 96);

    void selectDay(DateTime day) => setState(() {
          _selectedDay = day;
          _monthView = false;
          weekController.showWeekOf(day);
        });

    final filterChip = filterCount == 0
        ? null
        : SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(AppSpacing.screen, 0, AppSpacing.screen, AppSpacing.s12),
              child: Align(
                alignment: Alignment.centerLeft,
                child: _FilterChip(
                  count: filterCount,
                  onClear: () => ref.read(calendarClientFilterProvider.notifier).clear(),
                ),
              ),
            ),
          );

    if (_monthView) {
      return [
        if (filterChip != null) filterChip,
        SliverToBoxAdapter(
          child: MonthOverview(month: weekStart, sessions: sessions, onSelectDay: selectDay),
        ),
        SliverToBoxAdapter(child: SizedBox(height: bottomPad)),
      ];
    }

    return [
      if (filterChip != null) filterChip,
      SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(AppSpacing.screen, AppSpacing.s8, AppSpacing.screen, AppSpacing.s8),
          child: WeekStrip(
            weekStart: weekStart,
            selectedDay: _selectedDay,
            sessions: sessions,
            onSelectDay: selectDay,
            onPreviousWeek: weekController.previousWeek,
            onNextWeek: weekController.nextWeek,
          ),
        ),
      ),
      if (sessions.isEmpty)
        SliverFillRemaining(
          child: EmptyView(
            icon: Icons.event_available_outlined,
            title: l10n.trainerNoSessionsThisWeekTitle,
            subtitle: l10n.trainerNoSessionsThisWeekMessage,
          ),
        )
      else
        ..._agendaSlivers(context, sessions: sessions, clients: clients, weekStart: weekStart, onChanged: onRefresh),
      SliverToBoxAdapter(child: SizedBox(height: bottomPad)),
    ];
  }

  void _openFilter(BuildContext context, List<TrainerClient> clients) {
    showLifeySheet<void>(
      context: context,
      title: AppLocalizations.of(context)!.trainerCalendarFilterTitle,
      useRootNavigator: true,
      builder: (_) => _ClientFilterSheet(clients: clients),
    );
  }
}

// ---------------------------------------------------------------------------

/// The week, day by day. Days with nothing on them are skipped rather than
/// shown empty — seven "nothing scheduled" rows is a lot of nothing.
List<Widget> _agendaSlivers(
  BuildContext context, {
  required List<CalendarSession> sessions,
  required List<TrainerClient> clients,
  required DateTime weekStart,
  required Future<void> Function() onChanged,
}) {
  final t = Theme.of(context).textTheme;
  final p = context.palette;
  final l10n = AppLocalizations.of(context)!;
  final f = LifeyFormat.of(context);

  TrainerClient? clientOf(CalendarSession session) {
    for (final client in clients) {
      if (client.userId == session.clientId) return client;
    }
    return null;
  }

  final rows = <Widget>[];
  for (var i = 0; i < 7; i++) {
    final day = DateTime(weekStart.year, weekStart.month, weekStart.day + i);
    final ofDay = sessionsOfDay(sessions, day);
    if (ofDay.isEmpty) continue;

    rows.add(Padding(
      padding: const EdgeInsets.fromLTRB(AppSpacing.screen + AppSpacing.s4, AppSpacing.s12, AppSpacing.screen, AppSpacing.s8),
      child: Text(
        f.shortDayLabel(day),
        style: t.labelLarge?.copyWith(fontWeight: FontWeight.w700, color: p.text2),
      ),
    ));

    var untimedDividerAdded = false;
    for (final session in ofDay) {
      // Untimed occurrences sit at the end of the day under their own
      // quiet divider, rather than pretending to a time they do not have.
      if (session.scheduledTime == null && !untimedDividerAdded) {
        untimedDividerAdded = true;
        rows.add(Padding(
          padding: const EdgeInsets.fromLTRB(AppSpacing.screen + AppSpacing.s4, AppSpacing.s4, AppSpacing.screen, AppSpacing.s4),
          child: Text(l10n.trainerDuringTheDayLabel, style: t.labelSmall?.copyWith(color: p.text2)),
        ));
      }
      rows.add(Padding(
        padding: const EdgeInsets.fromLTRB(AppSpacing.screen, 0, AppSpacing.screen, AppSpacing.s8),
        child: _AgendaCard(session: session, client: clientOf(session), onChanged: onChanged),
      ));
    }
  }

  return [SliverList(delegate: SliverChildListDelegate(rows))];
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
    final t = Theme.of(context).textTheme;
    final p = context.palette;
    final l10n = AppLocalizations.of(context)!;

    return LifeyCard(
      padding: const EdgeInsets.all(AppSpacing.s12),
      onTap: () async {
        final cancelled = await SessionPeekSheet.show(
          context,
          session: session,
          client: client,
        );
        if (cancelled ?? false) await onChanged();
      },
      child: Row(
        children: [
          SizedBox(
            width: 48,
            child: Text(
              session.scheduledTime == null ? '—' : formatScheduleTime(session.scheduledTime!),
              style: t.labelLarge?.copyWith(fontWeight: FontWeight.w700, fontFeatures: const [FontFeature.tabularFigures()]),
            ),
          ),
          const SizedBox(width: AppSpacing.s8),
          if (client != null) ...[
            ClientAvatar(client: client!, size: 36),
            const SizedBox(width: AppSpacing.s12),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  client?.displayName ?? session.clientEmail ?? l10n.trainerUnknownClientLabel,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: t.titleSmall,
                ),
                Text(
                  session.templateName ?? l10n.trainerFreeWorkoutLabel,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: t.bodySmall?.copyWith(color: p.text2),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.s8),
          OccurrenceStatusChip(status: session.status),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------

/// "1 client ✕" under the header while the agenda is narrowed: says so, and one
/// tap lifts the filter.
class _FilterChip extends StatelessWidget {
  const _FilterChip({required this.count, required this.onClear});

  final int count;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return InkWell(
      onTap: onClear,
      borderRadius: AppRadius.pill,
      child: TintedChip(
        label: l10n.trainerCalendarFilterChipLabel(count),
        color: Theme.of(context).colorScheme.primary,
        icon: Icons.close_rounded,
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

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (selected.isNotEmpty)
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              onPressed: controller.clear,
              child: Text(l10n.trainerCalendarFilterClearAction),
            ),
          ),
        ListGroup(
          dividerInset: 76,
          children: [
            for (final client in clients)
              ListRow(
                leading: ClientAvatar(client: client, size: 44),
                title: client.displayName,
                trailing: Checkbox(
                  value: selected.contains(client.userId),
                  onChanged: (_) => controller.toggle(client.userId),
                ),
                onTap: () => controller.toggle(client.userId),
              ),
          ],
        ),
      ],
    );
  }
}
