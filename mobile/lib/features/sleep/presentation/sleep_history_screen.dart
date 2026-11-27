import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/format/lifey_format.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/widgets/ds/lifey_header.dart';
import '../../../shared/widgets/ds/list_group.dart';
import '../../../shared/widgets/ds/metric_tile.dart';
import '../../../shared/widgets/ds/section_label.dart';
import '../../../shared/widgets/empty_view.dart';
import '../../../shared/widgets/error_view.dart';
import '../application/sleep_session_controller.dart';
import '../domain/sleep_session.dart';
import 'widgets/sleep_tile.dart';

/// Sleep history (docs/integrations/89 G2.6), opened from the Today sleep
/// tile: the 7-day average on top, then every session grouped by week,
/// newest first.
///
/// - Each row is one session: its wake-up day, bedtime–wake-up and duration.
/// - A nap (any session that is not the main sleep of its day) is marked
///   with its own icon and "Nap" in the subline, so a 40-minute nap never
///   reads as a bad night.
/// - The average counts main sleeps only, over the nights that have one.
class SleepHistoryScreen extends ConsumerWidget {
  const SleepHistoryScreen({super.key, this.now});

  /// The clock, for "today" and the week labels — injectable for tests.
  final DateTime Function()? now;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final state = ref.watch(sleepSessionControllerProvider);
    final controller = ref.read(sleepSessionControllerProvider.notifier);

    return Scaffold(
      appBar: LifeySubpageHeader(title: l10n.sleepHistoryTitle),
      body: RefreshIndicator(
        onRefresh: controller.refresh,
        child: state.when(
          data: (sessions) => sessions.isEmpty
              ? EmptyView(
                  icon: Icons.bedtime_outlined,
                  color: context.metricColors.sleep,
                  title: l10n.sleepHistoryEmptyTitle,
                  subtitle: l10n.sleepHistoryEmptyMessage,
                )
              : _History(sessions: sessions, today: (now ?? DateTime.now)()),
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => ErrorView(error: error, onRetry: controller.refresh),
        ),
      ),
    );
  }
}

class _History extends StatelessWidget {
  const _History({required this.sessions, required this.today});

  /// Newest wake-up first.
  final List<SleepSession> sessions;
  final DateTime today;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final f = LifeyFormat.of(context);
    final mc = context.metricColors;
    final average = sleepAverage(sessions, today);
    final weeks = sessionsByWeek(sessions);
    final thisWeek = weekStartOf(today);

    String weekLabel(DateTime start) {
      if (start == thisWeek) return l10n.sleepHistoryThisWeek;
      if (start == DateTime(thisWeek.year, thisWeek.month, thisWeek.day - 7)) return l10n.sleepHistoryLastWeek;
      final end = DateTime(start.year, start.month, start.day + 6);
      return l10n.sleepHistoryWeekRange(f.shortDate(start), f.shortDate(end));
    }

    return ListView(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.s20,
        AppSpacing.s8,
        AppSpacing.s20,
        MediaQuery.paddingOf(context).bottom + AppSpacing.s24,
      ),
      children: [
        MetricTile(
          icon: Icons.bedtime_rounded,
          label: l10n.sleepHistoryAverageLabel,
          value: average == null ? '—' : sleepDurationValue(average.average),
          unit: average == null ? null : l10n.durationHoursAbbrev,
          color: mc.sleep,
          subline: average == null ? l10n.sleepHistoryAverageNone : l10n.sleepHistoryAverageNights(average.nights),
        ),
        for (final week in weeks) ...[
          const SizedBox(height: AppSpacing.s16),
          SectionLabel(weekLabel(week.start)),
          const SizedBox(height: AppSpacing.s8),
          ListGroup(children: [
            for (final s in week.sessions) _SessionRow(session: s, nap: isNap(s, sessions)),
          ]),
        ],
      ],
    );
  }
}

class _SessionRow extends StatelessWidget {
  const _SessionRow({required this.session, required this.nap});

  final SleepSession session;
  final bool nap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final f = LifeyFormat.of(context);
    final mc = context.metricColors;
    final range = l10n.sleepTimeRange(f.time(session.startedAt.toLocal()), f.time(session.endedAt.toLocal()));
    return ListRow(
      leading: ListIconHolder(
        icon: nap ? Icons.snooze_rounded : Icons.bedtime_rounded,
        color: nap ? mc.steps : mc.sleep,
      ),
      title: f.shortDayLabel(session.wakeDate),
      subtitle: nap ? l10n.sleepHistoryNapSubline(range) : range,
      trailing: ListRowValue(value: sleepDurationValue(session.duration), unit: l10n.durationHoursAbbrev),
    );
  }
}
