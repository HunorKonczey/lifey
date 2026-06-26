import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_tokens.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/widgets/app_snackbar.dart';
import '../../../shared/widgets/confirm_delete_dialog.dart';
import '../../../shared/widgets/empty_view.dart';
import '../../../shared/widgets/error_view.dart';
import '../../../shared/widgets/sync_status_indicator.dart';
import '../application/recipes_controller.dart';
import '../domain/recipe.dart';
import 'create_recipe_screen.dart';
import 'widgets/log_recipe_sheet.dart';

/// "Recipes" tab: tap to edit, quick "log as meal", and swipe-to-delete.
class RecipesTab extends ConsumerWidget {
  const RecipesTab({super.key, this.topPadding = 0});

  final double topPadding;

  Future<void> _logAsMeal(BuildContext context, Recipe recipe) {
    return showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => LogRecipeSheet(recipe: recipe),
    );
  }

  Future<void> _edit(BuildContext context, Recipe recipe) {
    return Navigator.of(context, rootNavigator: true).push(
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
    final l10n = AppLocalizations.of(context)!;
    try {
      await ref.read(recipeControllerProvider.notifier).deleteRecipe(recipe.clientId);
      if (context.mounted) {
        AppSnackbar.showSuccess(context, title: l10n.deletedFoodMessage(recipe.name));
      }
    } catch (_) {
      if (context.mounted) {
        AppSnackbar.showError(context, title: l10n.couldNotDeleteFoodMessage(recipe.name));
      }
      await ref.read(recipeControllerProvider.notifier).refresh();
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(recipeControllerProvider);
    final l10n = AppLocalizations.of(context)!;
    final bottomPad = MediaQuery.paddingOf(context).bottom;

    return RefreshIndicator(
      displacement: topPadding,
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
            padding: EdgeInsets.fromLTRB(12, topPadding, 12, bottomPad + 88),
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

// ---------------------------------------------------------------------------
// Recipe card
// ---------------------------------------------------------------------------

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
    final scheme = theme.colorScheme;
    final l10n = AppLocalizations.of(context)!;

    return Dismissible(
      key: ValueKey(recipe.clientId),
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
          title: l10n.deleteRecipeQuestionTitle,
          message: l10n.deleteRecipeConfirmMessage(recipe.name),
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
                // Icon badge
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: scheme.primaryContainer,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Center(
                    child: Icon(
                      Icons.menu_book,
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
                          Expanded(
                            child: Text(
                              recipe.name,
                              style: theme.textTheme.bodyLarge,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (recipe.favorite)
                            Icon(Icons.star, size: 16, color: scheme.primary),
                          SyncStatusIndicator(clientId: recipe.clientId),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(
                        recipe.servings > 1
                            ? l10n.perServingCaloriesProteinLabel(
                                (recipe.totalCalories / recipe.servings).toStringAsFixed(0),
                                (recipe.totalProtein / recipe.servings).toStringAsFixed(0),
                              )
                            : l10n.totalCaloriesProteinLabel(
                                recipe.totalCalories.toStringAsFixed(0),
                                recipe.totalProtein.toStringAsFixed(0),
                              ),
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                // Log-as-meal button — compact rounded square
                GestureDetector(
                  onTap: onLogAsMeal,
                  behavior: HitTestBehavior.opaque,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
                    decoration: BoxDecoration(
                      color: scheme.primary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.restaurant, size: 16, color: scheme.primary),
                        const SizedBox(width: 4),
                        Text(
                          l10n.logAsMealButton,
                          style: TextStyle(
                            fontFamily: 'PlusJakartaSans',
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: scheme.primary,
                            height: 1.0,
                          ),
                        ),
                      ],
                    ),
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
