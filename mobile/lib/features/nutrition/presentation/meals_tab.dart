import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_tokens.dart';
import '../../../l10n/app_localizations.dart';
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
  const MealsTab({super.key});

  @override
  ConsumerState<MealsTab> createState() => _MealsTabState();
}

class _MealsTabState extends ConsumerState<MealsTab> {
  static final _dateLabel = DateFormat('EEE, MMM d · HH:mm');

  /// Distance from the bottom (in px) at which the next page is requested.
  static const _loadMoreThreshold = 300.0;

  DateRangeFilter _filter = DateRangeFilter.today;

  bool _nearBottom = false;

  bool _handleScrollNotification(ScrollNotification notification) {
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
    final messenger = ScaffoldMessenger.of(context);
    final l10n = AppLocalizations.of(context)!;
    try {
      await ref.read(mealControllerProvider.notifier).deleteMeal(meal.clientId);
      messenger.showSnackBar(SnackBar(content: Text(l10n.mealDeletedMessage)));
    } catch (_) {
      messenger.showSnackBar(
          SnackBar(content: Text(l10n.couldNotDeleteMealMessage)));
      await ref.read(mealControllerProvider.notifier).refresh();
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
        if (meals.isEmpty) {
          return RefreshIndicator(
            onRefresh: () => ref.read(mealControllerProvider.notifier).refresh(),
            child: EmptyView(
              icon: Icons.lunch_dining_outlined,
              title: l10n.noMealsLoggedYetTitle,
              subtitle: l10n.tapPlusToLogOneMessage,
            ),
          );
        }
        final filtered = meals.where((m) => _filter.matches(m.dateTime)).toList();
        return Column(
          children: [
            DateRangeFilterBar(
              value: _filter,
              onChanged: (f) => setState(() => _filter = f),
            ),
            Expanded(
              child: RefreshIndicator(
                onRefresh: () => ref.read(mealControllerProvider.notifier).refresh(),
                child: filtered.isEmpty
                    ? EmptyView(
                        icon: Icons.lunch_dining_outlined,
                        title: l10n.noMealsInRangeTitle,
                        subtitle: l10n.tryWiderDateFilterMessage,
                      )
                    : NotificationListener<ScrollNotification>(
                        onNotification: _handleScrollNotification,
                        child: ListView.builder(
                          padding: EdgeInsets.fromLTRB(12, 4, 12, bottomPad + 88),
                          itemCount: filtered.length + (hasMore ? 1 : 0),
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
                            );
                          },
                        ),
                      ),
              ),
            ),
          ],
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
  });

  final Meal meal;
  final DateFormat dateLabel;
  final VoidCallback onDelete;
  final VoidCallback onEdit;

  static IconData _mealIcon(MealType type) => switch (type) {
        MealType.breakfast => Icons.free_breakfast,
        MealType.lunch => Icons.lunch_dining,
        MealType.dinner => Icons.dinner_dining,
        MealType.snack => Icons.cookie,
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
    final l10n = AppLocalizations.of(context)!;

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
      onDismissed: (_) => onDelete(),
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
                      _mealIcon(meal.mealType),
                      size: 22,
                      color: scheme.onPrimaryContainer,
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
                          Text(meal.mealType.label(l10n), style: theme.textTheme.bodyLarge),
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
                Icon(Icons.chevron_right, size: 18, color: scheme.onSurfaceVariant),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
