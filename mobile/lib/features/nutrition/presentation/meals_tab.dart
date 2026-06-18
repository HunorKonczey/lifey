import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../shared/widgets/empty_view.dart';
import '../../../shared/widgets/error_view.dart';
import '../application/meal_controller.dart';
import '../domain/meal.dart';

/// "Meals" tab: list of logged meals with swipe-to-delete.
class MealsTab extends ConsumerWidget {
  const MealsTab({super.key});

  static final _dateLabel = DateFormat('EEE, MMM d · HH:mm');

  Future<void> _delete(BuildContext context, WidgetRef ref, Meal meal) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(mealControllerProvider.notifier).deleteMeal(meal.id);
      messenger.showSnackBar(const SnackBar(content: Text('Meal deleted')));
    } catch (_) {
      messenger.showSnackBar(const SnackBar(content: Text("Couldn't delete the meal")));
      await ref.read(mealControllerProvider.notifier).refresh();
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(mealControllerProvider);

    return RefreshIndicator(
      onRefresh: () => ref.read(mealControllerProvider.notifier).refresh(),
      child: state.when(
        data: (meals) {
          if (meals.isEmpty) {
            return const EmptyView(
              icon: Icons.lunch_dining_outlined,
              title: 'No meals logged yet',
              subtitle: 'Tap + to log one',
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: meals.length,
            itemBuilder: (context, index) => _MealCard(
              meal: meals[index],
              dateLabel: _dateLabel,
              onDelete: () => _delete(context, ref, meals[index]),
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

class _MealCard extends StatelessWidget {
  const _MealCard({
    required this.meal,
    required this.dateLabel,
    required this.onDelete,
  });

  final Meal meal;
  final DateFormat dateLabel;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Dismissible(
      key: ValueKey(meal.id),
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
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Chip(
                    label: Text(meal.mealType.label),
                    visualDensity: VisualDensity.compact,
                    backgroundColor: theme.colorScheme.primaryContainer,
                  ),
                  const Spacer(),
                  Text(dateLabel.format(meal.dateTime.toLocal()),
                      style: theme.textTheme.bodySmall),
                ],
              ),
              const SizedBox(height: 8),
              ...meal.entries.map(
                (e) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Text(
                      '${e.foodName} — ${e.quantityInGrams.toStringAsFixed(0)} g'),
                ),
              ),
              const Divider(height: 16),
              Text(
                '≈ ${meal.totalCalories.toStringAsFixed(0)} kcal · '
                '${meal.totalProtein.toStringAsFixed(0)} g protein',
                style: theme.textTheme.labelLarge
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
