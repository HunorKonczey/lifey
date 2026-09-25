import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/entitlements/ai_credit_gate.dart';
import '../../../core/entitlements/entitlement_providers.dart';
import '../../../core/sync/connectivity_status_provider.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/utils/search_normalize.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/widgets/app_snackbar.dart';
import '../../../shared/widgets/confirm_delete_dialog.dart';
import '../../../shared/widgets/ds/lifey_card.dart';
import '../../../shared/widgets/ds/lifey_sheet.dart';
import '../../../shared/widgets/ds/list_group.dart';
import '../../../shared/widgets/empty_view.dart';
import '../../../shared/widgets/error_view.dart';
import '../../nutrition/presentation/widgets/ai_credit_chip.dart';
import '../application/recipes_controller.dart';
import '../domain/recipe.dart';
import '../domain/recipe_filter.dart';
import '../generation/domain/recipe_wizard.dart';
import '../generation/presentation/generated_recipe_screen.dart';
import '../generation/presentation/recipe_wizard_sheet.dart';
import 'create_recipe_screen.dart';
import 'widgets/log_recipe_sheet.dart';
import 'widgets/recipe_grid_card.dart';

enum _RecipeAction { edit, duplicate, delete }

/// "Recipes" tab (docs/redesign/77-mobile-redesign-plan.md R2.7; canvas
/// Lifey 2 › 2.3): the "Generate a recipe" entry card, filter chips (All ·
/// Favourites · High protein · < 400 kcal, combined with the header search)
/// and a two-column grid of photo cards. Tap edits, "+ Log" logs it as a
/// meal, long-press opens Edit / Duplicate / Delete.
class RecipesTab extends ConsumerStatefulWidget {
  const RecipesTab({super.key, this.searchQuery});

  /// When non-empty, filters the (already fully-loaded) recipe list by name.
  final String? searchQuery;

  @override
  ConsumerState<RecipesTab> createState() => _RecipesTabState();
}

class _RecipesTabState extends ConsumerState<RecipesTab> {
  RecipeFilter _filter = RecipeFilter.all;

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
  Future<void> _generate(BuildContext context, bool offline) async {
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

  Future<void> _delete(BuildContext context, Recipe recipe) async {
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showConfirmDeleteDialog(
      context,
      title: l10n.deleteRecipeQuestionTitle,
      message: l10n.deleteRecipeConfirmMessage(recipe.name),
    );
    if (!confirmed || !context.mounted) return;
    final controller = ref.read(recipeControllerProvider.notifier);
    try {
      await controller.deleteRecipe(recipe.clientId);
      if (context.mounted) AppSnackbar.showSuccess(context, title: l10n.deletedFoodMessage(recipe.name));
    } catch (_) {
      if (context.mounted) AppSnackbar.showError(context, title: l10n.couldNotDeleteFoodMessage(recipe.name));
      await controller.refresh();
    }
  }

  Future<void> _duplicate(BuildContext context, Recipe recipe) async {
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
      if (context.mounted) AppSnackbar.showSuccess(context, title: l10n.recipeDuplicatedMessage);
    } catch (_) {
      if (context.mounted) AppSnackbar.showError(context, title: l10n.couldNotDuplicateRecipeMessage);
    }
  }

  /// The long-press menu — where the old duplicate button and the swipe to
  /// delete went, now that the cards are a grid.
  Future<void> _openMenu(BuildContext context, Recipe recipe) async {
    final l10n = AppLocalizations.of(context)!;
    final action = await showLifeySheet<_RecipeAction>(
      context: context,
      useRootNavigator: true,
      title: recipe.name,
      builder: (sheetContext) {
        final primary = Theme.of(sheetContext).colorScheme.primary;
        final mc = sheetContext.metricColors;
        void pick(_RecipeAction a) => Navigator.of(sheetContext).pop(a);
        return ListGroup(
          children: [
            ListRow(
              leading: ListIconHolder(icon: Icons.edit_rounded, color: primary),
              title: l10n.editMenuItem,
              onTap: () => pick(_RecipeAction.edit),
            ),
            ListRow(
              leading: ListIconHolder(icon: Icons.content_copy_rounded, color: mc.carbs),
              title: l10n.duplicateMenuItem,
              onTap: () => pick(_RecipeAction.duplicate),
            ),
            ListRow(
              leading: ListIconHolder(icon: Icons.delete_rounded, color: mc.heart),
              title: l10n.deleteButton,
              onTap: () => pick(_RecipeAction.delete),
            ),
          ],
        );
      },
    );
    if (action == null || !context.mounted) return;
    switch (action) {
      case _RecipeAction.edit:
        await _edit(context, recipe);
      case _RecipeAction.duplicate:
        await _duplicate(context, recipe);
      case _RecipeAction.delete:
        await _delete(context, recipe);
    }
  }

  String _filterLabel(AppLocalizations l10n, RecipeFilter filter) => switch (filter) {
        RecipeFilter.all => l10n.recipeFilterAll,
        RecipeFilter.favourites => l10n.recipeFilterFavourites,
        RecipeFilter.highProtein => l10n.recipeFilterHighProtein,
        RecipeFilter.lowCalorie => l10n.recipeFilterUnder400,
      };

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(recipeControllerProvider);
    final l10n = AppLocalizations.of(context)!;
    final bottomPad = MediaQuery.paddingOf(context).bottom;
    final query = normalizeForSearch(widget.searchQuery?.trim() ?? '');
    final offline = ref.watch(isOfflineProvider).value ?? false;

    return RefreshIndicator(
      onRefresh: () => ref.read(recipeControllerProvider.notifier).refresh(),
      child: state.when(
        data: (recipes) {
          final bySearch =
              query.isEmpty ? recipes : recipes.where((r) => normalizeForSearch(r.name).contains(query)).toList();
          final visible = bySearch.where((r) => matchesRecipeFilter(r, _filter)).toList();
          final showGenerate = query.isEmpty;

          Widget empty() => EmptyStateCard(
                icon: recipes.isEmpty && query.isEmpty ? Icons.menu_book_outlined : Icons.search_off,
                title: recipes.isEmpty && query.isEmpty ? l10n.noRecipesYetTitle : l10n.noSearchResultsTitle,
                subtitle: recipes.isEmpty && query.isEmpty
                    ? l10n.tapPlusToCreateOneMessage
                    : query.isNotEmpty
                        ? l10n.tryDifferentSearchMessage
                        : l10n.noRecipesMatchMessage,
              );

          // header items (generate card, chips), then one row per two recipes
          final headerCount = (showGenerate ? 1 : 0) + (recipes.isEmpty ? 0 : 1);
          final rows = (visible.length / 2).ceil();
          final tail = visible.isEmpty ? 1 : rows;
          return ListView.builder(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: EdgeInsets.fromLTRB(AppSpacing.screen, AppSpacing.s8, AppSpacing.screen, bottomPad + 88),
            itemCount: headerCount + tail,
            itemBuilder: (context, index) {
              var i = index;
              if (showGenerate) {
                if (i == 0) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.s16),
                    child: _GenerateCard(offline: offline, onTap: () => _generate(context, offline)),
                  );
                }
                i--;
              }
              if (recipes.isNotEmpty) {
                if (i == 0) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.s12),
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          for (final filter in RecipeFilter.values) ...[
                            if (filter != RecipeFilter.all) const SizedBox(width: AppSpacing.s8),
                            ChoiceChip(
                              label: Text(_filterLabel(l10n, filter)),
                              selected: _filter == filter,
                              showCheckmark: false,
                              // Tighter than the theme's 12 so all four fit a 411 dp
                              // row, as in the canvas.
                              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s4, vertical: AppSpacing.s8),
                              onSelected: (_) => setState(() => _filter = filter),
                            ),
                          ],
                        ],
                      ),
                    ),
                  );
                }
                i--;
              }
              if (visible.isEmpty) return empty();
              final first = i * 2;
              Widget cell(int n) {
                if (n >= visible.length) return const SizedBox.shrink();
                final recipe = visible[n];
                return RecipeGridCard(
                  recipe: recipe,
                  onTap: () => _edit(context, recipe),
                  onLongPress: () => _openMenu(context, recipe),
                  onLog: () => _logAsMeal(context, recipe),
                  onToggleFavorite: () =>
                      ref.read(recipeControllerProvider.notifier).toggleFavorite(recipe.clientId, !recipe.favorite),
                );
              }

              return Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.s12),
                child: IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(child: cell(first)),
                      const SizedBox(width: AppSpacing.s12),
                      Expanded(child: cell(first + 1)),
                    ],
                  ),
                ),
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
}

/// The AI entry point, with the credit chip inside it — the recipe half of
/// what the Log meal screen's photo tile does (`72` M7). Dimmed, not
/// disabled, offline: tapping it explains why it can't run.
class _GenerateCard extends ConsumerWidget {
  const _GenerateCard({required this.offline, required this.onTap});

  final bool offline;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final p = context.palette;
    final t = Theme.of(context).textTheme;
    final primary = Theme.of(context).colorScheme.primary;
    final color = offline ? p.text2 : primary;
    final hasCredits = ref.watch(aiCreditsProvider) != null;

    return LifeyCard(
      color: offline ? p.card : p.primaryTint,
      onTap: onTap,
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(AppRadius.control),
            ),
            child: Icon(Icons.auto_awesome_rounded, size: 26, color: color),
          ),
          const SizedBox(width: AppSpacing.s16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.generateRecipeWithAiButton,
                  style: t.titleMedium!.copyWith(fontSize: 17, height: 1.3, color: p.text),
                ),
                const SizedBox(height: 2),
                Text(
                  l10n.generateRecipeSubtitle,
                  style: t.bodyMedium!.copyWith(fontSize: 14, height: 1.4, color: p.text2),
                ),
                if (hasCredits) ...[const SizedBox(height: AppSpacing.s8), const AiCreditChip()],
              ],
            ),
          ),
          Icon(Icons.chevron_right_rounded, color: p.text2),
        ],
      ),
    );
  }
}
