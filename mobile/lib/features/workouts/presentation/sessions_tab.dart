import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/ads/banner_ad_slot.dart';
import '../../../core/entitlements/entitlement_providers.dart';
import '../../../core/format/lifey_format.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/workout_session_notifier/workout_session_notifier_service.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/widgets/app_snackbar.dart';
import '../../../shared/widgets/confirm_delete_dialog.dart';
import '../../../shared/widgets/date_range_filter_bar.dart';
import '../../../shared/widgets/ds/grouped_list_item.dart';
import '../../../shared/widgets/ds/lifey_sheet.dart';
import '../../../shared/widgets/ds/list_group.dart';
import '../../../shared/widgets/ds/section_label.dart';
import '../../../shared/widgets/empty_view.dart';
import '../../../shared/widgets/error_view.dart';
import '../../../shared/widgets/history_boundary_row.dart';
import '../../settings/application/settings_controller.dart';
import '../../settings/domain/user_settings.dart';
import '../application/recommended_template_provider.dart';
import '../application/session_pr_counts.dart';
import '../application/workout_session_controller.dart';
import '../domain/activity_type.dart';
import '../domain/session_groups.dart';
import '../domain/week_summary.dart';
import '../domain/workout_session.dart';
import '../domain/workout_template.dart';
import 'log_session_screen.dart';
import 'open_workout_screens.dart';
import 'widgets/recommended_workout_card.dart';
import 'widgets/session_row.dart';
import 'widgets/upcoming_sessions_section.dart';
import 'widgets/week_summary_row.dart';

/// Whether [session] passes the sessions-tab kind/type filter
/// (docs/cardio/59-cardio-implementation-plan.md C1.7).
///
/// [kindFilter] is `null` ("Mind" — no filtering), `'STRENGTH'`, or
/// `'CARDIO'`. [activityTypeFilter] narrows a `'CARDIO'` selection to one
/// specific [kActivityTypes] code; it's ignored otherwise, so a stale value
/// left over from a previous selection can never silently narrow the list.
bool matchesSessionKindFilter(
  WorkoutSession session, {
  required String? kindFilter,
  required String? activityTypeFilter,
}) {
  if (kindFilter == null) return true;
  if (kindFilter == 'STRENGTH') return !session.isCardio;
  if (!session.isCardio) return false;
  return activityTypeFilter == null || session.activityType == activityTypeFilter;
}

enum _SessionAction { open, delete }

/// One entry of the flattened, lazily built list: a ready widget (the leading
/// cards, a group header, a gap) or a session row with its place in its group.
typedef _Entry = ({Widget? widget, WorkoutSession? session, bool first, bool last, SessionRowDate date});

_Entry _widgetEntry(Widget widget) =>
    (widget: widget, session: null, first: false, last: false, date: SessionRowDate.none);

/// "Sessions" tab (docs/redesign/77-mobile-redesign-plan.md R3.1 / R3.3): the
/// week summary, then the workouts grouped under "Today" / "Earlier this
/// week" / "Last week" / one header per older week, one card per group. Tap
/// opens (or resumes) a session, long-press opens Open / Delete, swipe
/// deletes after a confirmation. The active filters are owned by the parent
/// screen and shown in its header.
class SessionsTab extends ConsumerStatefulWidget {
  const SessionsTab({
    super.key,
    this.filter = DateRangeFilter.today,
    this.kindFilter,
    this.activityTypeFilter,
  });

  final DateRangeFilter filter;

  /// `null` (all), `'STRENGTH'`, or `'CARDIO'` — see [matchesSessionKindFilter].
  final String? kindFilter;

  /// Narrows a `'CARDIO'` [kindFilter] to one [kActivityTypes] code.
  final String? activityTypeFilter;

  @override
  ConsumerState<SessionsTab> createState() => _SessionsTabState();
}

class _SessionsTabState extends ConsumerState<SessionsTab> {
  Future<void> _edit(BuildContext context, WorkoutSession session) {
    return openSessionScreen(Navigator.of(context, rootNavigator: true), session);
  }

  Future<void> _startRecommended(BuildContext context, WorkoutTemplate template) {
    return Navigator.of(context, rootNavigator: true).push(
      MaterialPageRoute(builder: (_) => LogSessionScreen(template: template)),
    );
  }

  Future<void> _delete(BuildContext context, WidgetRef ref, WorkoutSession session) async {
    final l10n = AppLocalizations.of(context)!;
    try {
      // Nothing prevents deleting a still-running session — end its Live
      // Activity / ongoing notification so it doesn't linger as an orphan
      // (see docs/24-ios-widget-live-activity-plan.md and
      // docs/25-android-widget-ongoing-notification-plan.md, orphan handling).
      if (session.inProgress) {
        unawaited(ref.read(workoutSessionNotifierServiceProvider).end());
      }
      await ref.read(workoutSessionControllerProvider.notifier).deleteSession(session.clientId);
      if (context.mounted) {
        AppSnackbar.showSuccess(context, title: l10n.workoutDeletedMessage);
      }
    } catch (_) {
      if (context.mounted) {
        AppSnackbar.showError(context, title: l10n.couldNotDeleteWorkoutMessage);
      }
      await ref.read(workoutSessionControllerProvider.notifier).refresh();
    }
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref, WorkoutSession session) async {
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showConfirmDeleteDialog(
      context,
      title: l10n.deleteWorkoutQuestionTitle,
      message: l10n.deleteWorkoutConfirmMessage,
    );
    if (confirmed && context.mounted) {
      await _delete(context, ref, session);
    }
  }

  /// The long-press menu — where the trash icon of every row went.
  Future<void> _openMenu(BuildContext context, WorkoutSession session, String title) async {
    final l10n = AppLocalizations.of(context)!;
    final action = await showLifeySheet<_SessionAction>(
      context: context,
      useRootNavigator: true,
      title: title,
      builder: (sheetContext) {
        final primary = Theme.of(sheetContext).colorScheme.primary;
        final heart = sheetContext.metricColors.heart;
        void pick(_SessionAction a) => Navigator.of(sheetContext).pop(a);
        return ListGroup(
          children: [
            ListRow(
              leading: ListIconHolder(icon: Icons.open_in_new_rounded, color: primary),
              title: l10n.sessionMenuOpen,
              onTap: () => pick(_SessionAction.open),
            ),
            ListRow(
              leading: ListIconHolder(icon: Icons.delete_rounded, color: heart),
              title: l10n.deleteButton,
              onTap: () => pick(_SessionAction.delete),
            ),
          ],
        );
      },
    );
    if (action == null || !context.mounted) return;
    switch (action) {
      case _SessionAction.open:
        await _edit(context, session);
      case _SessionAction.delete:
        await _confirmDelete(context, ref, session);
    }
  }

  String _title(AppLocalizations l10n, WorkoutSession s) => s.isCardio
      ? activityTypeLabel(l10n, s.activityType!)
      : (s.templateName?.trim().isNotEmpty ?? false)
          ? s.templateName!.trim()
          : l10n.activityTypeStrength;

  String _groupLabel(AppLocalizations l10n, LifeyFormat f, SessionGroup group) => switch (group.kind) {
        SessionGroupKind.today => l10n.sessionsGroupToday,
        SessionGroupKind.earlierThisWeek => l10n.sessionsGroupEarlierThisWeek,
        SessionGroupKind.lastWeek => l10n.sessionsGroupLastWeek,
        SessionGroupKind.olderWeek =>
          '${f.shortDate(group.weekStart)} – ${f.shortDate(DateTime(group.weekStart.year, group.weekStart.month, group.weekStart.day + 6))}',
      };

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(workoutSessionControllerProvider);
    final recommended = ref.watch(recommendedTemplateProvider);
    final prCounts = ref.watch(sessionPrCountsProvider);
    final l10n = AppLocalizations.of(context)!;
    final f = LifeyFormat.of(context);
    final bottomPad = MediaQuery.paddingOf(context).bottom + ref.watch(bannerAdSlotHeightProvider(2));
    final unitSystem = (ref.watch(settingsControllerProvider).value ?? const UserSettings.defaults()).unitSystem;

    return state.when(
      data: (sessions) {
        // Trainer-scheduled, not-yet-started sessions within the 7-day
        // visibility window get their own pinned section, never mixed into
        // history — the history filter (today/week/all) never matches them
        // since they have no startedAt.
        bool matchesKind(WorkoutSession s) => matchesSessionKindFilter(
              s,
              kindFilter: widget.kindFilter,
              activityTypeFilter: widget.activityTypeFilter,
            );
        final upcoming = sessions.where(isWithinUpcomingWindow).where(matchesKind).toList();
        final filtered = sessions
            .where((s) => !s.isUpcoming && widget.filter.matches(s.startedAt!))
            .where(matchesKind)
            .toList();

        // The free history window (`67` §3.2, D-P6) — a presentation filter
        // applied on top of the today/week/all filter above, never a change
        // to the `workoutSessionControllerProvider` query itself. `filtered`
        // is already newest-first, so anything cut off is a contiguous tail.
        final cutoff = ref.watch(historyCutoffProvider);
        final visible = cutoff == null
            ? filtered
            : filtered.where((s) => !s.startedAt!.toLocal().isBefore(cutoff)).toList();
        final truncated = visible.length < filtered.length;

        if (sessions.isEmpty || (filtered.isEmpty && upcoming.isEmpty)) {
          return RefreshIndicator(
            onRefresh: () => ref.read(workoutSessionControllerProvider.notifier).refresh(),
            child: EmptyView(
              icon: Icons.fitness_center_outlined,
              title: sessions.isEmpty ? l10n.noWorkoutsLoggedYetTitle : l10n.noWorkoutsInRangeTitle,
              subtitle: sessions.isEmpty ? l10n.tapPlusToLogOneMessage : l10n.tryWiderDateFilterMessage,
            ),
          );
        }

        // The week summary counts the whole calendar week, whatever the list
        // is filtered to (same rules as the weekly recap).
        final summary = computeWeekSummary(sessions, DateTime.now());
        final entries = <_Entry>[
          if (recommended != null)
            _widgetEntry(Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.s12),
              child: RecommendedWorkoutCard(
                template: recommended,
                onTap: () => _startRecommended(context, recommended),
              ),
            )),
          _widgetEntry(Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.s8),
            child: WeekSummaryRow(summary: summary, unitSystem: unitSystem),
          )),
          if (upcoming.isNotEmpty)
            _widgetEntry(UpcomingSessionsSection(
              sessions: upcoming,
              onStart: (s) => _edit(context, s),
              onDelete: (s) => _confirmDelete(context, ref, s),
            )),
          for (final group in groupSessionsByWeek(visible, DateTime.now())) ...[
            _widgetEntry(SectionLabel(_groupLabel(l10n, f, group))),
            for (final (i, s) in group.sessions.indexed)
              (
                widget: null,
                session: s,
                first: i == 0,
                last: i == group.sessions.length - 1,
                date: switch (group.kind) {
                  SessionGroupKind.today => SessionRowDate.none,
                  SessionGroupKind.olderWeek => SessionRowDate.date,
                  _ => SessionRowDate.weekday,
                },
              ),
            _widgetEntry(const SizedBox(height: AppSpacing.s8)),
          ],
          if (truncated) _widgetEntry(const HistoryBoundaryRow()),
        ];

        return RefreshIndicator(
          onRefresh: () => ref.read(workoutSessionControllerProvider.notifier).refresh(),
          child: ListView.builder(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: EdgeInsets.fromLTRB(AppSpacing.screen, AppSpacing.s8, AppSpacing.screen, bottomPad + 88),
            itemCount: entries.length,
            itemBuilder: (context, index) {
              final entry = entries[index];
              final session = entry.session;
              if (session == null) return entry.widget!;
              return GroupedListItem(
                first: entry.first,
                last: entry.last,
                dismissKey: ValueKey(session.clientId),
                confirmDismiss: () async {
                  await _confirmDelete(context, ref, session);
                  // The list's own stream removes the row once the delete lands.
                  return false;
                },
                child: SessionRow(
                  session: session,
                  unitSystem: unitSystem,
                  prCount: prCounts[session.clientId] ?? 0,
                  date: entry.date,
                  onTap: () => _edit(context, session),
                  onLongPress: () => _openMenu(context, session, _title(l10n, session)),
                ),
              );
            },
          ),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => ErrorView(
        error: error,
        onRetry: () => ref.read(workoutSessionControllerProvider.notifier).refresh(),
      ),
    );
  }
}
