import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_tokens.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../shared/widgets/app_snackbar.dart';
import '../../../../shared/widgets/confirm_delete_dialog.dart';
import '../../../../shared/widgets/ds/lifey_sheet.dart';
import '../../../../shared/widgets/ds/list_group.dart';
import '../../application/meal_controller.dart';
import '../../domain/meal.dart';
import '../log_meal_screen.dart';
import 'duplicate_meal_dialog.dart';
import 'meal_list_row.dart';

enum _MealAction { edit, duplicate, delete }

/// A [MealListRow] with everything a logged meal can do: tap edits, swipe left
/// deletes (after a confirmation), long-press opens a menu with Edit /
/// Duplicate / Delete — the copy button that used to sit on every row now
/// lives there (docs/redesign/77-mobile-redesign-plan.md R2.3).
///
/// Used by the Meals tab and the all-meals screen, so both behave alike.
class MealListItem extends ConsumerWidget {
  const MealListItem({super.key, required this.meal});

  final Meal meal;

  Future<void> _edit(BuildContext context) {
    return Navigator.of(context, rootNavigator: true).push(
      MaterialPageRoute(builder: (_) => LogMealScreen(meal: meal)),
    );
  }

  Future<void> _delete(BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context)!;
    final controller = ref.read(mealControllerProvider.notifier);
    try {
      await controller.deleteMeal(meal.clientId);
      if (context.mounted) AppSnackbar.showSuccess(context, title: l10n.mealDeletedMessage);
    } catch (_) {
      if (context.mounted) AppSnackbar.showError(context, title: l10n.couldNotDeleteMealMessage);
      await controller.refresh();
    }
  }

  Future<bool> _confirmDelete(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return showConfirmDeleteDialog(
      context,
      title: l10n.deleteMealQuestionTitle,
      message: l10n.deleteMealConfirmMessage,
    );
  }

  Future<void> _duplicate(BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context)!;
    final dateTime = await showDuplicateMealDialog(context);
    if (dateTime == null || !context.mounted) return;
    try {
      final duplicated = await ref.read(mealControllerProvider.notifier).duplicateMeal(meal, dateTime: dateTime);
      if (context.mounted) {
        AppSnackbar.showSuccess(
          context,
          title: l10n.mealDuplicatedMessage,
          actionLabel: l10n.editMenuItem,
          onAction: () => Navigator.of(context, rootNavigator: true).push(
            MaterialPageRoute(builder: (_) => LogMealScreen(meal: duplicated)),
          ),
        );
      }
    } catch (_) {
      if (context.mounted) AppSnackbar.showError(context, title: l10n.couldNotDuplicateMealMessage);
    }
  }

  Future<void> _openMenu(BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context)!;
    final action = await showLifeySheet<_MealAction>(
      context: context,
      useRootNavigator: true,
      title: (meal.name?.trim().isNotEmpty ?? false) ? meal.name!.trim() : meal.mealType.label(l10n),
      builder: (sheetContext) {
        final primary = Theme.of(sheetContext).colorScheme.primary;
        final mc = sheetContext.metricColors;
        void pick(_MealAction a) => Navigator.of(sheetContext).pop(a);
        return ListGroup(
          children: [
            ListRow(
              leading: ListIconHolder(icon: Icons.edit_rounded, color: primary),
              title: l10n.editMenuItem,
              onTap: () => pick(_MealAction.edit),
            ),
            ListRow(
              leading: ListIconHolder(icon: Icons.content_copy_rounded, color: mc.carbs),
              title: l10n.duplicateMenuItem,
              onTap: () => pick(_MealAction.duplicate),
            ),
            ListRow(
              leading: ListIconHolder(icon: Icons.delete_rounded, color: mc.heart),
              title: l10n.deleteButton,
              onTap: () => pick(_MealAction.delete),
            ),
          ],
        );
      },
    );
    if (action == null || !context.mounted) return;
    switch (action) {
      case _MealAction.edit:
        await _edit(context);
      case _MealAction.duplicate:
        await _duplicate(context, ref);
      case _MealAction.delete:
        if (await _confirmDelete(context) && context.mounted) await _delete(context, ref);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final heart = context.metricColors.heart;
    return Dismissible(
      key: ValueKey(meal.clientId),
      direction: DismissDirection.endToStart,
      background: Container(
        color: heart.withValues(alpha: 0.16),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s20),
        child: Icon(Icons.delete_rounded, color: heart),
      ),
      // Confirm first; the local cache stream removes the row once the delete
      // lands, so Dismissible never drops it itself.
      confirmDismiss: (_) async {
        if (await _confirmDelete(context) && context.mounted) await _delete(context, ref);
        return false;
      },
      child: MealListRow(
        meal: meal,
        onTap: () => _edit(context),
        onLongPress: () => _openMenu(context, ref),
      ),
    );
  }
}
