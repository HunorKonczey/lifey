import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/app_localizations.dart';
import '../../../shared/widgets/empty_view.dart';
import '../../../shared/widgets/error_view.dart';
import '../../../shared/widgets/sync_status_indicator.dart';
import '../application/recipes_controller.dart';
import '../domain/recipe.dart';
import 'create_recipe_screen.dart';
import 'widgets/log_recipe_sheet.dart';

/// "Recipes" tab: tap to edit, quick "log as meal", and swipe-to-delete.
class RecipesTab extends ConsumerWidget {
  const RecipesTab({super.key});

  Future<void> _logAsMeal(BuildContext context, Recipe recipe) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => LogRecipeSheet(recipe: recipe),
    );
  }

  Future<void> _edit(BuildContext context, Recipe recipe) {
    return Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => CreateRecipeScreen(recipe: recipe)),
    );
  }

  Future<void> _toggleFavorite(WidgetRef ref, Recipe recipe) {
    return ref
        .read(recipeControllerProvider.notifier)
        .toggleFavorite(recipe.clientId, !recipe.favorite);
  }

  Future<void> _delete(
      BuildContext context, WidgetRef ref, Recipe recipe) async {
    final messenger = ScaffoldMessenger.of(context);
    final l10n = AppLocalizations.of(context)!;
    try {
      await ref.read(recipeControllerProvider.notifier).deleteRecipe(recipe.clientId);
      messenger.showSnackBar(SnackBar(content: Text(l10n.deletedFoodMessage(recipe.name))));
    } catch (_) {
      messenger.showSnackBar(
          SnackBar(content: Text(l10n.couldNotDeleteFoodMessage(recipe.name))));
      await ref.read(recipeControllerProvider.notifier).refresh();
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(recipeControllerProvider);
    final l10n = AppLocalizations.of(context)!;

    return RefreshIndicator(
      onRefresh: () => ref.read(recipeControllerProvider.notifier).refresh(),
      child: state.when(
        data: (recipes) {
          if (recipes.isEmpty) {
            return EmptyView(
              icon: Icons.menu_book_outlined,
              title: l10n.noRecipesYetTitle,
              subtitle: l10n.tapPlusToCreateOneMessage,
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: recipes.length,
            itemBuilder: (context, index) => _RecipeCard(
              recipe: recipes[index],
              onDelete: () => _delete(context, ref, recipes[index]),
              onLogAsMeal: () => _logAsMeal(context, recipes[index]),
              onEdit: () => _edit(context, recipes[index]),
              onToggleFavorite: () => _toggleFavorite(ref, recipes[index]),
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => ErrorView(
          error: error,
          onRetry: () => ref.read(recipeControllerProvider.notifier).refresh(),
        ),
      ),
    );
  }
}

class _RecipeCard extends StatelessWidget {
  const _RecipeCard({
    required this.recipe,
    required this.onDelete,
    required this.onLogAsMeal,
    required this.onEdit,
    required this.onToggleFavorite,
  });

  final Recipe recipe;
  final VoidCallback onDelete;
  final VoidCallback onLogAsMeal;
  final VoidCallback onEdit;
  final VoidCallback onToggleFavorite;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    final ingredients = recipe.ingredients
        .map((i) => '${i.foodName} (${i.quantityInGrams.toStringAsFixed(0)} g)')
        .join(', ');

    return Dismissible(
      key: ValueKey(recipe.clientId),
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
                    Expanded(
                      child: Text(recipe.name, style: theme.textTheme.titleMedium),
                    ),
                    IconButton(
                      tooltip: recipe.favorite ? l10n.removeFavorite : l10n.markFavorite,
                      icon: Icon(recipe.favorite ? Icons.star : Icons.star_border),
                      color: recipe.favorite ? theme.colorScheme.primary : null,
                      onPressed: onToggleFavorite,
                    ),
                    SyncStatusIndicator(clientId: recipe.clientId),
                  ],
                ),
                if (recipe.description != null &&
                    recipe.description!.trim().isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(recipe.description!,
                      style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant)),
                ],
                const SizedBox(height: 8),
                Text(
                  ingredients.isEmpty ? l10n.noIngredientsMessage : ingredients,
                  style: theme.textTheme.bodySmall,
                ),
                const SizedBox(height: 6),
                Text(
                  l10n.totalCaloriesProteinLabel(recipe.totalCalories.toStringAsFixed(0),
                      recipe.totalProtein.toStringAsFixed(0)),
                  style: theme.textTheme.labelLarge
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    onPressed: onLogAsMeal,
                    icon: const Icon(Icons.restaurant, size: 18),
                    label: Text(l10n.logAsMealButton),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
