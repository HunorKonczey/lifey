import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/widgets/empty_view.dart';
import '../../../shared/widgets/error_view.dart';
import '../application/food_controller.dart';
import '../domain/food.dart';
import 'widgets/add_food_sheet.dart';

/// "Foods" tab: list of foods with tap-to-edit and swipe-to-delete.
class FoodsTab extends ConsumerWidget {
  const FoodsTab({super.key});

  Future<void> _edit(BuildContext context, Food food) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => AddFoodSheet(food: food),
    );
  }

  String _macroLine(Food food) {
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
    return '${parts.join(' · ')}  (per 100 g)';
  }

  Future<void> _delete(BuildContext context, WidgetRef ref, Food food) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(foodControllerProvider.notifier).deleteFood(food.id);
      messenger.showSnackBar(SnackBar(content: Text('Deleted ${food.name}')));
    } on DioException catch (e) {
      final used = e.response?.statusCode == 409;
      messenger.showSnackBar(SnackBar(
        content: Text(used
            ? '${food.name} is used in a meal or recipe'
            : "Couldn't delete ${food.name}"),
      ));
      await ref.read(foodControllerProvider.notifier).refresh();
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(foodControllerProvider);

    return RefreshIndicator(
      onRefresh: () => ref.read(foodControllerProvider.notifier).refresh(),
      child: state.when(
        data: (foods) {
          if (foods.isEmpty) {
            return const EmptyView(
              icon: Icons.restaurant_outlined,
              title: 'No foods yet',
              subtitle: 'Tap + to add one',
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: foods.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final food = foods[index];
              return Dismissible(
                key: ValueKey(food.id),
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
                  // We refresh from the server ourselves, so never let the
                  // Dismissible remove the tile optimistically.
                  return false;
                },
                child: ListTile(
                  title: Text(food.name),
                  subtitle: Text(_macroLine(food)),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => _edit(context, food),
                ),
              );
            },
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
