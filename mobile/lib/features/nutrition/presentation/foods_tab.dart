import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/app_localizations.dart';
import '../../../shared/widgets/empty_view.dart';
import '../../../shared/widgets/error_view.dart';
import '../../../shared/widgets/sync_status_indicator.dart';
import '../application/food_controller.dart';
import '../domain/food.dart';
import 'widgets/add_food_sheet.dart';

/// "Foods" tab: list of foods with tap-to-edit, swipe-to-delete, and
/// scroll-triggered pagination over the local cache (see
/// docs/14-pagination-plan.md).
class FoodsTab extends ConsumerStatefulWidget {
  const FoodsTab({super.key});

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
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => AddFoodSheet(food: food),
    );
  }

  String _macroLine(BuildContext context, Food food) {
    final l10n = AppLocalizations.of(context)!;
    final parts = <String>[
      '${food.caloriesPer100g.toStringAsFixed(0)} kcal',
      '${food.proteinPer100g.toStringAsFixed(0)} P',
    ];
    if (food.carbsPer100g != null) {
      parts.add('${food.carbsPer100g!.toStringAsFixed(0)} C');
    }
    if (food.fatPer100g != null) {
      parts.add('${food.fatPer100g!.toStringAsFixed(0)} F');
    }
    return '${parts.join(' · ')}  ${l10n.perHundredGramsSuffix}';
  }

  Future<void> _delete(BuildContext context, WidgetRef ref, Food food) async {
    final messenger = ScaffoldMessenger.of(context);
    final l10n = AppLocalizations.of(context)!;
    try {
      // Deletes immediately offline-first; if the food still turns out to be
      // used in a meal/recipe, that 409 only surfaces later when this syncs
      // (no UI for failed-operation review yet, so it just stays queued).
      await ref.read(foodControllerProvider.notifier).deleteFood(food.clientId);
      messenger.showSnackBar(SnackBar(content: Text(l10n.deletedFoodMessage(food.name))));
    } catch (_) {
      messenger.showSnackBar(SnackBar(content: Text(l10n.couldNotDeleteFoodMessage(food.name))));
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(foodControllerProvider);
    final l10n = AppLocalizations.of(context)!;
    // .notifier access doesn't itself trigger a rebuild; `hasMore` is read
    // fresh on every rebuild, and the controller already mutates it before
    // pushing the data that triggers this rebuild via `state` above.
    final hasMore = ref.read(foodControllerProvider.notifier).hasMore;

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
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: itemCount,
              separatorBuilder: (_, __) => const Divider(height: 1),
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
                return Dismissible(
                  key: ValueKey(food.clientId),
                  direction: DismissDirection.endToStart,
                  background: Container(
                    color: Theme.of(context).colorScheme.errorContainer,
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Icon(Icons.delete,
                        color: Theme.of(context).colorScheme.onErrorContainer),
                  ),
                  confirmDismiss: (_) async {
                    await _delete(context, ref, food);
                    // The local cache stream removes the tile on its own once
                    // the delete lands; don't let Dismissible do it too.
                    return false;
                  },
                  child: ListTile(
                    title: Text(food.name),
                    subtitle: Text(_macroLine(context, food)),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SyncStatusIndicator(clientId: food.clientId),
                        const Icon(Icons.chevron_right),
                      ],
                    ),
                    onTap: () => _edit(context, food),
                  ),
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
}
