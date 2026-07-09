import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_tokens.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/widgets/app_snackbar.dart';
import '../../../shared/widgets/confirm_delete_dialog.dart';
import '../../../shared/widgets/date_range_filter_bar.dart';
import '../../../shared/widgets/empty_view.dart';
import '../../../shared/widgets/error_view.dart';
import '../../../shared/widgets/sync_status_indicator.dart';
import '../application/meal_controller.dart';
import '../domain/meal.dart';
import 'log_meal_screen.dart';

/// "Meals" tab: tap to edit, swipe-to-delete, filter by date range, and
/// scroll-triggered pagination over the local cache (see
/// docs/14-pagination-plan.md).
class MealsTab extends ConsumerStatefulWidget {
  const MealsTab({
    super.key,
    this.topPadding = 0,
    this.filter = DateRangeFilter.today,
  });

  final double topPadding;
  final DateRangeFilter filter;

  @override
  ConsumerState<MealsTab> createState() => _MealsTabState();
}

class _MealsTabState extends ConsumerState<MealsTab> {
  static final _dateLabel = DateFormat('EEE, MMM d · HH:mm');

  /// Distance from the bottom (in px) at which the next page is requested.
  static const _loadMoreThreshold = 300.0;

  bool _nearBottom = false;

  bool _handleScrollNotification(ScrollNotification notification, bool canLoadMore) {
    if (!canLoadMore) return false;
    final metrics = notification.metrics;
    final isNearBottom = metrics.maxScrollExtent - metrics.pixels <= _loadMoreThreshold;
    if (isNearBottom && !_nearBottom) {
      ref.read(mealControllerProvider.notifier).loadMore();
    }
    _nearBottom = isNearBottom;
    return false;
  }

  Future<void> _edit(BuildContext context, Meal meal) {
    return Navigator.of(context, rootNavigator: true).push(
      MaterialPageRoute(builder: (_) => LogMealScreen(meal: meal)),
    );
  }

  Future<void> _delete(BuildContext context, WidgetRef ref, Meal meal) async {
    final l10n = AppLocalizations.of(context)!;
    try {
      await ref.read(mealControllerProvider.notifier).deleteMeal(meal.clientId);
      if (context.mounted) {
        AppSnackbar.showSuccess(context, title: l10n.mealDeletedMessage);
      }
    } catch (_) {
      if (context.mounted) {
        AppSnackbar.showError(context, title: l10n.couldNotDeleteMealMessage);
      }
      await ref.read(mealControllerProvider.notifier).refresh();
    }
  }

  Future<void> _duplicate(BuildContext context, WidgetRef ref, Meal meal) async {
    final l10n = AppLocalizations.of(context)!;
    try {
      await ref.read(mealControllerProvider.notifier).duplicateMeal(meal);
      if (context.mounted) {
        AppSnackbar.showSuccess(context, title: l10n.mealDuplicatedMessage);
      }
    } catch (_) {
      if (context.mounted) {
        AppSnackbar.showError(context, title: l10n.couldNotDuplicateMealMessage);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(mealControllerProvider);
    final l10n = AppLocalizations.of(context)!;
    final hasMore = ref.read(mealControllerProvider.notifier).hasMore;
    final bottomPad = MediaQuery.paddingOf(context).bottom;

    return state.when(
      data: (meals) {
        final filtered =
            meals.where((m) => widget.filter.matches(m.dateTime)).toList();

        if (meals.isEmpty || filtered.isEmpty) {
          return RefreshIndicator(
            displacement: widget.topPadding,
            onRefresh: () => ref.read(mealControllerProvider.notifier).refresh(),
            child: EmptyView(
              icon: Icons.lunch_dining_outlined,
              title: meals.isEmpty
                  ? l10n.noMealsLoggedYetTitle
                  : l10n.noMealsInRangeTitle,
              subtitle: meals.isEmpty
                  ? l10n.tapPlusToLogOneMessage
                  : l10n.tryWiderDateFilterMessage,
            ),
          );
        }

        // Only offer "load more" when the filter isn't hiding meals from the
        // current page. If filtered < meals, the extra DB rows are from other
        // date ranges and loading more won't help the current view.
        final canLoadMore = hasMore && filtered.length == meals.length;

        return RefreshIndicator(
          displacement: widget.topPadding,
          onRefresh: () => ref.read(mealControllerProvider.notifier).refresh(),
          child: NotificationListener<ScrollNotification>(
            onNotification: (n) => _handleScrollNotification(n, canLoadMore),
            child: ListView.builder(
              padding: EdgeInsets.fromLTRB(12, widget.topPadding, 12, bottomPad + 88),
              itemCount: filtered.length + (canLoadMore ? 1 : 0),
              itemBuilder: (context, index) {
                if (index >= filtered.length) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 16),
                    child: Center(
                      child: SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ),
                  );
                }
                final meal = filtered[index];
                return _MealCard(
                  meal: meal,
                  dateLabel: _dateLabel,
                  onDelete: () => _delete(context, ref, meal),
                  onEdit: () => _edit(context, meal),
                  onDuplicate: () => _duplicate(context, ref, meal),
                );
              },
            ),
          ),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => ErrorView(
        error: error,
        onRetry: () => ref.read(mealControllerProvider.notifier).refresh(),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Meal card
// ---------------------------------------------------------------------------

class _MealCard extends StatelessWidget {
  const _MealCard({
    required this.meal,
    required this.dateLabel,
    required this.onDelete,
    required this.onEdit,
    required this.onDuplicate,
  });

  final Meal meal;
  final DateFormat dateLabel;
  final VoidCallback onDelete;
  final VoidCallback onEdit;
  final VoidCallback onDuplicate;

  static ({IconData icon, Color Function(AppMetricColors mc, ColorScheme cs) color}) _mealStyle(
      MealType type) =>
      switch (type) {
        MealType.breakfast => (
            icon: Icons.bakery_dining,
            color: (mc, cs) => mc.carbs,
          ),
        MealType.lunch => (
            icon: Icons.lunch_dining,
            color: (mc, cs) => mc.calories,
          ),
        MealType.dinner => (
            icon: Icons.set_meal,
            color: (mc, cs) => mc.protein,
          ),
        MealType.snack => (
            icon: Icons.cookie,
            color: (mc, cs) => cs.tertiary,
          ),
      };

  String _macroLine(AppLocalizations l10n) {
    final parts = <String>[
      '${meal.totalCalories.toStringAsFixed(0)} kcal',
      '${meal.totalProtein.toStringAsFixed(0)} P',
    ];
    if (meal.totalCarbs > 0) parts.add('${meal.totalCarbs.toStringAsFixed(0)} C');
    if (meal.totalFat > 0) parts.add('${meal.totalFat.toStringAsFixed(0)} F');
    return parts.join(' · ');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final mc = context.metricColors;
    final l10n = AppLocalizations.of(context)!;
    final style = _mealStyle(meal.mealType);
    final iconColor = style.color(mc, scheme);

    return Dismissible(
      key: ValueKey(meal.clientId),
      direction: DismissDirection.endToStart,
      background: Container(
        decoration: BoxDecoration(
          color: scheme.errorContainer,
          borderRadius: BorderRadius.circular(AppRadius.card),
        ),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        margin: const EdgeInsets.only(bottom: 10),
        child: Icon(Icons.delete, color: scheme.onErrorContainer),
      ),
      // Confirm first; the local cache stream removes the tile once the
      // delete lands, so we never let Dismissible drop it itself.
      confirmDismiss: (_) async {
        final confirmed = await showConfirmDeleteDialog(
          context,
          title: l10n.deleteMealQuestionTitle,
          message: l10n.deleteMealConfirmMessage,
        );
        if (confirmed) onDelete();
        return false;
      },
      child: Card(
        elevation: 0,
        color: scheme.surfaceContainerHigh,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.card),
        ),
        margin: const EdgeInsets.only(bottom: 10),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onEdit,
          borderRadius: BorderRadius.circular(AppRadius.card),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            child: Row(
              children: [
                // Meal-type icon badge
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: scheme.primaryContainer,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Center(
                    child: Icon(
                      style.icon,
                      size: 22,
                      color: iconColor,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                // Content
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            meal.name ?? meal.mealType.label(l10n),
                            style: theme.textTheme.bodyLarge,
                          ),
                          const Spacer(),
                          Text(
                            dateLabel.format(meal.dateTime.toLocal()),
                            style: theme.textTheme.labelMedium?.copyWith(
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                          SyncStatusIndicator(clientId: meal.clientId),
                        ],
                      ),
                      if (meal.name != null) ...[
                        const SizedBox(height: 1),
                        Text(
                          meal.mealType.label(l10n),
                          style: theme.textTheme.labelMedium?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                      const SizedBox(height: 3),
                      Text(
                        _macroLine(l10n),
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                      if (meal.entries.isNotEmpty) ...[
                        const SizedBox(height: 3),
                        Text(
                          meal.entries.map((e) => e.foodName).join(', '),
                          style: theme.textTheme.labelMedium?.copyWith(
                            color: scheme.onSurfaceVariant.withValues(alpha: 0.7),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 4),
                IconButton(
                  icon: const Icon(Icons.copy_rounded, size: 18),
                  color: scheme.onSurfaceVariant,
                  visualDensity: VisualDensity.compact,
                  tooltip: l10n.duplicateMealAria,
                  onPressed: onDuplicate,
                ),
                Icon(Icons.chevron_right, size: 18, color: scheme.onSurfaceVariant),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
