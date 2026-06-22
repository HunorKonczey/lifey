import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

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

  DateRangeFilter _filter = DateRangeFilter.all;

  /// Edge-triggered: true while the viewport is within [_loadMoreThreshold]
  /// of the bottom. [loadMore] only fires on the transition into this zone
  /// (false -> true), not on every scroll notification while lingering in
  /// it. It resets on its own once new rows are appended (pushing the
  /// bottom further away) or the user scrolls back up.
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
    return Navigator.of(context).push(
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
    // .notifier access doesn't itself trigger a rebuild; `hasMore` is read
    // fresh on every rebuild, and the controller already mutates it before
    // pushing the data that triggers this rebuild via `state` above.
    final hasMore = ref.read(mealControllerProvider.notifier).hasMore;

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
        final filtered =
            meals.where((m) => _filter.matches(m.dateTime)).toList();
        return Column(
          children: [
            DateRangeFilterBar(
              value: _filter,
              onChanged: (f) => setState(() => _filter = f),
            ),
            Expanded(
              child: RefreshIndicator(
                onRefresh: () =>
                    ref.read(mealControllerProvider.notifier).refresh(),
                child: filtered.isEmpty
                    ? EmptyView(
                        icon: Icons.lunch_dining_outlined,
                        title: l10n.noMealsInRangeTitle,
                        subtitle: l10n.tryWiderDateFilterMessage,
                      )
                    : NotificationListener<ScrollNotification>(
                        onNotification: _handleScrollNotification,
                        child: ListView.builder(
                          padding: const EdgeInsets.all(12),
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
                            return _MealCard(
                              meal: filtered[index],
                              dateLabel: _dateLabel,
                              onDelete: () => _delete(context, ref, filtered[index]),
                              onEdit: () => _edit(context, filtered[index]),
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    return Dismissible(
      key: ValueKey(meal.clientId),
      direction: DismissDirection.endToStart,
      background: Container(
        decoration: BoxDecoration(
          color: theme.colorScheme.errorContainer,
          borderRadius: BorderRadius.circular(12),
        ),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        margin: const EdgeInsets.only(bottom: 12),
        child: Icon(Icons.delete, color: theme.colorScheme.onErrorContainer),
      ),
      onDismissed: (_) => onDelete(),
      child: Card(
        elevation: 0,
        color: theme.colorScheme.surfaceContainerHighest,
        margin: const EdgeInsets.only(bottom: 12),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onEdit,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Chip(
                      label: Text(meal.mealType.label(l10n)),
                      visualDensity: VisualDensity.compact,
                      backgroundColor: theme.colorScheme.primaryContainer,
                    ),
                    const SizedBox(width: 8),
                    Chip(
                      avatar: const Icon(Icons.local_fire_department,
                          size: 16, color: Colors.deepOrange),
                      label: Text('${meal.totalCalories.toStringAsFixed(0)} kcal'),
                      visualDensity: VisualDensity.compact,
                      backgroundColor: theme.colorScheme.surfaceContainerHigh,
                    ),
                    Expanded(
                      child: Text(
                        dateLabel.format(meal.dateTime.toLocal()),
                        textAlign: TextAlign.end,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall,
                      ),
                    ),
                    SyncStatusIndicator(clientId: meal.clientId),
                  ],
                ),
                const SizedBox(height: 8),
                ...meal.entries.map(
                  (e) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Text(
                        '${e.foodName} — ${l10n.gramsValue(e.quantityInGrams.toStringAsFixed(0))}'),
                  ),
                ),
                const Divider(height: 16),
                Text(
                  l10n.totalProteinLabel(meal.totalProtein.toStringAsFixed(0)),
                  style: theme.textTheme.labelLarge
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
