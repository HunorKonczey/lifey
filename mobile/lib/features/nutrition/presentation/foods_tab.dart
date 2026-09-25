import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/format/lifey_format.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/utils/search_normalize.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/widgets/app_snackbar.dart';
import '../../../shared/widgets/confirm_delete_dialog.dart';
import '../../../shared/widgets/ds/grouped_list_item.dart';
import '../../../shared/widgets/ds/list_group.dart';
import '../../../shared/widgets/empty_view.dart';
import '../../../shared/widgets/error_view.dart';
import '../../../shared/widgets/sync_status_indicator.dart';
import '../application/food_controller.dart';
import '../domain/food.dart';
import 'log_meal_screen.dart';
import 'widgets/add_food_sheet.dart';

/// "Foods" tab: list of foods with tap-to-edit, swipe-to-delete, and
/// scroll-triggered pagination over the local cache (see
/// docs/14-pagination-plan.md).
class FoodsTab extends ConsumerStatefulWidget {
  const FoodsTab({super.key, this.searchQuery});


  /// When non-empty, the tab shows the full food catalog (via
  /// [foodSearchProvider], bypassing pagination) filtered by name instead of
  /// the normal paginated [foodControllerProvider] window.
  final String? searchQuery;

  @override
  ConsumerState<FoodsTab> createState() => _FoodsTabState();
}

class _FoodsTabState extends ConsumerState<FoodsTab> {
  /// Distance from the bottom (in px) at which the next page is requested.
  static const _loadMoreThreshold = 300.0;

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
      ref.read(foodControllerProvider.notifier).loadMore();
    }
    _nearBottom = isNearBottom;
    return false;
  }

  Future<void> _edit(BuildContext context, Food food) {
    return showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => AddFoodSheet(food: food),
    );
  }

  /// Opens a new meal with the add-food sheet already on [food], quantity
  /// focused (docs/75-log-food-from-foods-tab-plan.md §2.6).
  void _addToMeal(BuildContext context, Food food) {
    Navigator.of(context, rootNavigator: true).push(
      MaterialPageRoute(builder: (_) => LogMealScreen(initialFood: food)),
    );
  }

  String _macroLine(BuildContext context, Food food) {
    final l10n = AppLocalizations.of(context)!;
    final f = LifeyFormat.of(context);
    final parts = <String>[
      '${f.kcal(food.caloriesPer100g)} kcal',
      '${f.grams(food.proteinPer100g)} ${l10n.macroLetterProtein}',
    ];
    if (food.carbsPer100g != null) {
      parts.add('${f.grams(food.carbsPer100g!)} ${l10n.macroLetterCarbs}');
    }
    if (food.fatPer100g != null) {
      parts.add('${f.grams(food.fatPer100g!)} ${l10n.macroLetterFat}');
    }
    return '${parts.join(' · ')}  ${l10n.perHundredGramsSuffix}';
  }

  Future<void> _delete(BuildContext context, WidgetRef ref, Food food) async {
    final l10n = AppLocalizations.of(context)!;
    try {
      // Deletes immediately offline-first; if the food still turns out to be
      // used in a meal/recipe, that 409 only surfaces later when this syncs
      // (no UI for failed-operation review yet, so it just stays queued).
      await ref.read(foodControllerProvider.notifier).deleteFood(food.clientId);
      if (context.mounted) {
        AppSnackbar.showSuccess(context, title: l10n.deletedFoodMessage(food.name));
      }
    } catch (_) {
      if (context.mounted) {
        AppSnackbar.showError(context, title: l10n.couldNotDeleteFoodMessage(food.name));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final query = widget.searchQuery?.trim() ?? '';
    if (query.isNotEmpty) {
      return _buildSearchResults(context, query);
    }

    final state = ref.watch(foodControllerProvider);
    final l10n = AppLocalizations.of(context)!;
    // .notifier access doesn't itself trigger a rebuild; `hasMore` is read
    // fresh on every rebuild, and the controller already mutates it before
    // pushing the data that triggers this rebuild via `state` above.
    final hasMore = ref.read(foodControllerProvider.notifier).hasMore;
    final bottomPad = MediaQuery.paddingOf(context).bottom;

    return RefreshIndicator(
      onRefresh: () => ref.read(foodControllerProvider.notifier).refresh(),
      child: state.when(
        data: (foods) {
          if (foods.isEmpty) {
            return EmptyView(
              icon: Icons.restaurant_outlined,
              title: l10n.noFoodsYetTitle,
              subtitle: l10n.tapPlusToAddOneMessage,
            );
          }
          final itemCount = foods.length + (hasMore ? 1 : 0);
          return NotificationListener<ScrollNotification>(
            onNotification: _handleScrollNotification,
            child: ListView.builder(
              padding: EdgeInsets.fromLTRB(AppSpacing.screen, AppSpacing.s8, AppSpacing.screen, bottomPad + 88),
              itemCount: itemCount,
              itemBuilder: (context, index) {
                if (index >= foods.length) {
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
                final food = foods[index];
                return _FoodRow(
                  first: index == 0,
                  last: index == foods.length - 1,
                  food: food,
                  macroLine: _macroLine(context, food),
                  onTap: () => _edit(context, food),
                  onAddToMeal: () => _addToMeal(context, food),
                  onDelete: () => _delete(context, ref, food),
                );
              },
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => ErrorView(
          error: error,
          onRetry: () => ref.read(foodControllerProvider.notifier).refresh(),
        ),
      ),
    );
  }

  /// Filters the full (unpaginated) [foodSearchProvider] catalog by [query] —
  /// bypasses [foodControllerProvider]'s pagination window entirely, matching
  /// the pattern already used for the meal-entry food autocomplete.
  Widget _buildSearchResults(BuildContext context, String query) {
    final foodsState = ref.watch(foodSearchProvider);
    final l10n = AppLocalizations.of(context)!;
    final bottomPad = MediaQuery.paddingOf(context).bottom;
    final normalizedQuery = normalizeForSearch(query);

    return foodsState.when(
      data: (foods) {
        final matches = foods
            .where((f) => normalizeForSearch(f.name).contains(normalizedQuery))
            .toList();
        if (matches.isEmpty) {
          return EmptyView(
            icon: Icons.search_off,
            title: l10n.noSearchResultsTitle,
            subtitle: l10n.tryDifferentSearchMessage,
          );
        }
        return ListView.builder(
          padding: EdgeInsets.fromLTRB(AppSpacing.screen, AppSpacing.s8, AppSpacing.screen, bottomPad + 88),
          itemCount: matches.length,
          itemBuilder: (context, index) {
            final food = matches[index];
            return _FoodRow(
              first: index == 0,
              last: index == matches.length - 1,
              food: food,
              macroLine: _macroLine(context, food),
              onTap: () => _edit(context, food),
              onAddToMeal: () => _addToMeal(context, food),
              onDelete: () => _delete(context, ref, food),
            );
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => ErrorView(
        error: error,
        onRetry: () => ref.invalidate(foodSearchProvider),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Food row — one lazily built row of a grouped card
// ---------------------------------------------------------------------------

/// A food as one row of the tab's grouped list (docs/redesign/77-mobile-
/// redesign-plan.md R2.9; the "fewer boxes" rule). The list is paged, so the
/// rows are built lazily rather than inside one [ListGroup]: each carries the
/// card surface, the first and last round the group's corners, and a hairline
/// separates it from the row above. Tap edits, the round + logs it into a new
/// meal, swipe deletes after a confirmation.
class _FoodRow extends StatelessWidget {
  const _FoodRow({
    required this.first,
    required this.last,
    required this.food,
    required this.macroLine,
    required this.onTap,
    required this.onAddToMeal,
    required this.onDelete,
  });

  final bool first;
  final bool last;
  final Food food;
  final String macroLine;
  final VoidCallback onTap;
  final VoidCallback onAddToMeal;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final l10n = AppLocalizations.of(context)!;
    final primary = Theme.of(context).colorScheme.primary;

    return GroupedListItem(
      first: first,
      last: last,
      dismissKey: ValueKey(food.clientId),
      confirmDismiss: () async {
        final confirmed = await showConfirmDeleteDialog(
          context,
          title: l10n.deleteFoodQuestionTitle,
          message: l10n.deleteFoodConfirmMessage(food.name),
        );
        if (confirmed) onDelete();
        // The local cache stream removes the row on its own once the delete
        // lands; don't let Dismissible do it too.
        return false;
      },
      child: ListRow(
        leading: ListIconHolder(icon: Icons.restaurant_menu_rounded, color: primary),
        title: food.name,
        subtitle: macroLine,
        onTap: onTap,
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SyncStatusIndicator(clientId: food.clientId),
            IconButton(
              icon: const Icon(Icons.add_rounded),
              tooltip: l10n.addToMealTooltip,
              onPressed: onAddToMeal,
              style: IconButton.styleFrom(
                fixedSize: const Size.square(44),
                minimumSize: const Size.square(44),
                backgroundColor: p.primaryTint,
                foregroundColor: primary,
                shape: const CircleBorder(),
                tapTargetSize: MaterialTapTargetSize.padded,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
