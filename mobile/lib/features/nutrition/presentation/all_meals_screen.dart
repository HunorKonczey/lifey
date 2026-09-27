import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/entitlements/entitlement_providers.dart';
import '../../../core/format/lifey_format.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/widgets/ds/lifey_header.dart';
import '../../../shared/widgets/ds/list_group.dart';
import '../../../shared/widgets/ds/section_label.dart';
import '../../../shared/widgets/empty_view.dart';
import '../../../shared/widgets/error_view.dart';
import '../../../shared/widgets/history_boundary_row.dart';
import '../application/meal_controller.dart';
import '../domain/day_meals_summary.dart';
import 'widgets/meal_list_item.dart';

/// Every logged meal, day by day, newest first — what the Meals tab's old
/// "All" filter showed, now behind the calendar button in the header
/// (docs/redesign/77-mobile-redesign-plan.md R2.2). The week strip covers the
/// last seven days; this is for anything older.
///
/// Pages in more meals from the local cache as the list nears its end (see
/// docs/14-pagination-plan.md) and stops at the free-tier history window with
/// the usual boundary row.
class AllMealsScreen extends ConsumerStatefulWidget {
  const AllMealsScreen({super.key});

  @override
  ConsumerState<AllMealsScreen> createState() => _AllMealsScreenState();
}

class _AllMealsScreenState extends ConsumerState<AllMealsScreen> {
  /// Distance from the bottom (in px) at which the next page is requested.
  static const _loadMoreThreshold = 300.0;

  bool _nearBottom = false;

  bool _onScroll(ScrollNotification notification, bool canLoadMore) {
    if (!canLoadMore) return false;
    final metrics = notification.metrics;
    final isNearBottom = metrics.maxScrollExtent - metrics.pixels <= _loadMoreThreshold;
    if (isNearBottom && !_nearBottom) {
      ref.read(mealControllerProvider.notifier).loadMore();
    }
    _nearBottom = isNearBottom;
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final f = LifeyFormat.of(context);
    final state = ref.watch(mealControllerProvider);
    final hasMore = ref.read(mealControllerProvider.notifier).hasMore;
    final cutoff = ref.watch(historyCutoffProvider);
    final bottomPad = MediaQuery.paddingOf(context).bottom + AppSpacing.s24;

    return Scaffold(
      appBar: LifeySubpageHeader(title: l10n.allMealsTitle),
      body: state.when(
        data: (meals) {
          // Newest first, so anything cut off by the history window is a
          // contiguous tail.
          final visible =
              cutoff == null ? meals : meals.where((m) => !m.dateTime.toLocal().isBefore(cutoff)).toList();
          final truncated = visible.length < meals.length;
          if (visible.isEmpty && !truncated) {
            return EmptyView(icon: Icons.lunch_dining_outlined, title: l10n.noMealsLoggedYetTitle);
          }
          // Once the window has cut the list, another page would only fetch
          // rows older than the cutoff — never shown.
          final canLoadMore = hasMore && !truncated;
          final days = groupMealsByDay(visible);

          return RefreshIndicator(
            onRefresh: () => ref.read(mealControllerProvider.notifier).refresh(),
            child: NotificationListener<ScrollNotification>(
              onNotification: (n) => _onScroll(n, canLoadMore),
              child: ListView(
                padding: EdgeInsets.fromLTRB(AppSpacing.screen, AppSpacing.s8, AppSpacing.screen, bottomPad),
                children: [
                  for (final day in days) ...[
                    SectionLabel(f.shortDayLabel(day.day)),
                    ListGroup(children: [
                      for (final meal in day.meals) MealListItem(meal: meal),
                    ]),
                    const SizedBox(height: AppSpacing.s8),
                  ],
                  if (truncated)
                    const HistoryBoundaryRow()
                  else if (canLoadMore)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: AppSpacing.s16),
                      child: Center(
                        child: SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2)),
                      ),
                    ),
                ],
              ),
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => ErrorView(
          error: error,
          onRetry: () => ref.read(mealControllerProvider.notifier).refresh(),
        ),
      ),
    );
  }
}
