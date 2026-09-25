import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/entitlements/ai_credit_gate.dart';
import '../../../core/sync/connectivity_status_provider.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/utils/search_normalize.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/widgets/app_snackbar.dart';
import '../../../shared/widgets/confirm_delete_dialog.dart';
import '../../../shared/widgets/empty_view.dart';
import '../../../shared/widgets/error_view.dart';
import '../../../shared/widgets/origin_trainer_badge.dart';
import '../../../shared/widgets/sync_status_indicator.dart';
import '../../nutrition/presentation/widgets/ai_credit_chip.dart';
import '../application/recipe_image_controller.dart';
import '../application/recipes_controller.dart';
import '../domain/recipe.dart';
import '../generation/domain/recipe_wizard.dart';
import '../generation/presentation/generated_recipe_screen.dart';
import '../generation/presentation/recipe_wizard_sheet.dart';
import 'create_recipe_screen.dart';
import 'widgets/log_recipe_sheet.dart';

/// "Recipes" tab: tap to edit, quick "log as meal", and swipe-to-delete.
class RecipesTab extends ConsumerWidget {
  const RecipesTab({super.key, this.searchQuery});


  /// When non-empty, filters the (already fully-loaded) recipe list by name.
  final String? searchQuery;

  Future<void> _logAsMeal(BuildContext context, Recipe recipe) {
    return showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => LogRecipeSheet(recipe: recipe),
    );
  }

  /// AI recipe generation (docs/23-ai-calorie-estimation-plan.md Phase 2):
  /// the wizard is local, only its result costs a call. The credit check is a
  /// courtesy — the server's 402 is authoritative and lands on the same
  /// paywall, from [GeneratedRecipeScreen].
  Future<void> _generate(BuildContext context, WidgetRef ref, bool offline) async {
    final l10n = AppLocalizations.of(context)!;
    if (offline) {
      AppSnackbar.showError(context, title: l10n.recipeGenerationOfflineMessage);
      return;
    }
    if (!requireAiCredits(context, ref)) return;

    final answers = await showModalBottomSheet<RecipeWizardAnswers>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => const RecipeWizardSheet(),
    );
    if (answers == null || !answers.isComplete || !context.mounted) return;

    await Navigator.of(context, rootNavigator: true).push(
      MaterialPageRoute(builder: (_) => GeneratedRecipeScreen(answers: answers)),
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

  Future<void> _duplicate(
      BuildContext context, WidgetRef ref, Recipe recipe) async {
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showAppConfirmDialog(
      context,
      icon: Icons.copy_rounded,
      title: l10n.duplicateRecipeQuestionTitle,
      message: l10n.duplicateRecipeConfirmMessage,
      confirmLabel: l10n.duplicateMenuItem,
      cancelLabel: l10n.cancelButton,
    );
    if (confirmed != true || !context.mounted) return;
    try {
      await ref.read(recipeControllerProvider.notifier).duplicateRecipe(
            recipe,
            newName: l10n.copyOfName(recipe.name),
          );
      if (context.mounted) {
        AppSnackbar.showSuccess(context, title: l10n.recipeDuplicatedMessage);
      }
    } catch (_) {
      if (context.mounted) {
        AppSnackbar.showError(context, title: l10n.couldNotDuplicateRecipeMessage);
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(recipeControllerProvider);
    final l10n = AppLocalizations.of(context)!;
    final bottomPad = MediaQuery.paddingOf(context).bottom;
    final query = normalizeForSearch(searchQuery?.trim() ?? '');
    final offline = ref.watch(isOfflineProvider).value ?? false;

    return RefreshIndicator(
      onRefresh: () => ref.read(recipeControllerProvider.notifier).refresh(),
      child: state.when(
        data: (recipes) {
          final visible = query.isEmpty
              ? recipes
              : recipes.where((r) => normalizeForSearch(r.name).contains(query)).toList();
          final showGenerate = query.isEmpty;
          if (visible.isEmpty) {
            return Column(
              children: [
                if (showGenerate)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, AppSpacing.s8, 12, 0),
                    child: _GenerateWithAiCard(
                        offline: offline, onTap: () => _generate(context, ref, offline)),
                  ),
                Expanded(child: _emptyView(l10n, query)),
              ],
            );
          }
          return ListView.builder(
            padding: EdgeInsets.fromLTRB(12, AppSpacing.s8, 12, bottomPad + 88),
            itemCount: visible.length + (showGenerate ? 1 : 0),
            itemBuilder: (context, index) {
              if (showGenerate && index == 0) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: _GenerateWithAiCard(
                        offline: offline, onTap: () => _generate(context, ref, offline)),
                );
              }
              final recipe = visible[index - (showGenerate ? 1 : 0)];
              return _RecipeCard(
                recipe: recipe,
                onDelete: () => _delete(context, ref, recipe),
                onLogAsMeal: () => _logAsMeal(context, recipe),
                onDuplicate: () => _duplicate(context, ref, recipe),
                onEdit: () => _edit(context, recipe),
                onToggleFavorite: () => _toggleFavorite(ref, recipe),
              );
            },
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

  Widget _emptyView(AppLocalizations l10n, String query) {
    return EmptyView(
              icon: query.isEmpty ? Icons.menu_book_outlined : Icons.search_off,
              title: query.isEmpty ? l10n.noRecipesYetTitle : l10n.noSearchResultsTitle,
      subtitle: query.isEmpty
          ? l10n.tapPlusToCreateOneMessage
          : l10n.tryDifferentSearchMessage,
    );
  }
}

/// The AI entry point, with the credit chip beside it — the recipe half of
/// what the Log meal screen's photo row does (`72` M7).
class _GenerateWithAiCard extends StatelessWidget {
  const _GenerateWithAiCard({required this.offline, required this.onTap});

  /// Dimmed, not disabled: tapping it offline explains why it can't run.
  final bool offline;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final theme = Theme.of(context);

    final color = offline ? scheme.onSurfaceVariant : scheme.primary;

    return Material(
      color: scheme.primaryContainer.withValues(alpha: offline ? 0.2 : 0.45),
      borderRadius: BorderRadius.circular(18),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Icon(Icons.auto_awesome, size: 21, color: color),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  AppLocalizations.of(context)!.generateRecipeWithAiButton,
                  style: theme.textTheme.labelLarge
                      ?.copyWith(fontWeight: FontWeight.w700, color: color),
                ),
              ),
              const AiCreditChip(),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Recipe card
// ---------------------------------------------------------------------------

class _RecipeCard extends ConsumerWidget {
  const _RecipeCard({
    required this.recipe,
    required this.onDelete,
    required this.onLogAsMeal,
    required this.onDuplicate,
    required this.onEdit,
    required this.onToggleFavorite,
  });

  final Recipe recipe;
  final VoidCallback onDelete;
  final VoidCallback onLogAsMeal;
  final VoidCallback onDuplicate;
  final VoidCallback onEdit;
  final VoidCallback onToggleFavorite;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    _RecipeThumbnail(recipe: recipe),
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
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  recipe.servings > 1
                                      ? l10n.perServingCaloriesProteinLabel(
                                          (recipe.totalCalories / recipe.servings)
                                              .toStringAsFixed(0),
                                          (recipe.totalProtein / recipe.servings)
                                              .toStringAsFixed(0),
                                        )
                                      : l10n.totalCaloriesProteinLabel(
                                          recipe.totalCalories.toStringAsFixed(0),
                                          recipe.totalProtein.toStringAsFixed(0),
                                        ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: theme.textTheme.labelMedium?.copyWith(
                                    color: scheme.onSurfaceVariant,
                                  ),
                                ),
                              ),
                              if (recipe.originTrainerId != null) ...[
                                const SizedBox(width: 6),
                                OriginTrainerBadge(originTrainerId: recipe.originTrainerId!),
                              ],
                            ],
                          ),
                          if (recipe.description != null &&
                              recipe.description!.trim().isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(
                              recipe.description!,
                              textAlign: TextAlign.left,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: scheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                // Actions — own row, bottom-right corner
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
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
                    const SizedBox(width: 8),
                    // Duplicate button — compact rounded square, same treatment as log-as-meal
                    Tooltip(
                      message: l10n.duplicateRecipeAria,
                      child: GestureDetector(
                        onTap: onDuplicate,
                        behavior: HitTestBehavior.opaque,
                        child: Container(
                          padding: const EdgeInsets.all(9),
                          decoration: BoxDecoration(
                            color: scheme.surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(Icons.copy_rounded, size: 16, color: scheme.onSurfaceVariant),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Recipe card thumbnail (falls back to the book icon while loading, on
// error, or when the recipe has no photo)
// ---------------------------------------------------------------------------

class _RecipeThumbnail extends ConsumerWidget {
  const _RecipeThumbnail({required this.recipe});

  final Recipe recipe;

  static const _size = 96.0;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final recipeId = recipe.id;

    Uint8List? bytes;
    if (recipeId != null && recipe.imageUpdatedAt != null) {
      bytes = ref
          .watch(recipeThumbnailProvider((
            clientId: recipe.clientId,
            serverId: recipeId,
            imageUpdatedAt: recipe.imageUpdatedAt,
          )))
          .value;
    }

    return Container(
      width: _size,
      height: _size,
      decoration: BoxDecoration(
        color: scheme.primaryContainer,
        borderRadius: BorderRadius.circular(16),
      ),
      clipBehavior: Clip.antiAlias,
      child: bytes != null
          ? Image.memory(bytes, width: _size, height: _size, fit: BoxFit.cover)
          : Center(
              child: Icon(Icons.menu_book, size: 40, color: scheme.onPrimaryContainer),
            ),
    );
  }
}
