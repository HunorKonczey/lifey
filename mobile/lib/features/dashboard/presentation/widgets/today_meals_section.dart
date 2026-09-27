import 'package:flutter/material.dart';

import '../../../../core/format/lifey_format.dart';
import '../../../../core/theme/app_tokens.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../shared/widgets/ds/list_group.dart';
import '../../../../shared/widgets/ds/section_label.dart';
import '../../../nutrition/presentation/widgets/meal_type_style.dart';
import '../../domain/today_meal_group.dart';

/// "TODAY'S MEALS · See all" and the day's meals in one card, with the
/// "+ Meal" / "Photo" quick actions inside it (docs/redesign/77-mobile-
/// redesign-plan.md R1.6; canvas Lifey 1 scrolled).
///
/// One row per meal type that has entries. A meal the user gave a name shows
/// that name over "Breakfast · 07:15"; an unnamed one shows its type over
/// "Apple, Almonds · 08:27" (its first foods). The kcal total is the row's
/// value. The icon holder is tinted per meal type, as in the canvas.
class TodayMealsSection extends StatelessWidget {
  const TodayMealsSection({
    super.key,
    required this.groups,
    required this.onSeeAll,
    required this.onMealTap,
    required this.onAddMeal,
    required this.onPhoto,
  });

  final List<TodayMealGroup> groups;
  final VoidCallback onSeeAll;
  final VoidCallback onMealTap;
  final VoidCallback onAddMeal;

  /// Meal from a photo (AI estimate). Always offered; offline and out-of-
  /// credits are handled by the estimate flow itself, as in the meal editor.
  final VoidCallback onPhoto;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final f = LifeyFormat.of(context);
    final p = context.palette;

    final rows = [
      for (final group in groups) _row(context, l10n, f, group),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionLabel(l10n.todaysMealsSectionTitle, actionLabel: l10n.dashboardSeeAll, onAction: onSeeAll),
        ListGroup(
          footer: Padding(
            // Aligned with the text of the rows above; flush left when there
            // are none.
            padding: EdgeInsets.fromLTRB(
                rows.isEmpty ? AppSpacing.s16 : 74, rows.isEmpty ? 0 : AppSpacing.s4, AppSpacing.s16, AppSpacing.s8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (rows.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: AppSpacing.s12),
                    child: Text(
                      l10n.noMealsLoggedYetPeriodMessage,
                      style: Theme.of(context).textTheme.bodyMedium!.copyWith(color: p.text2),
                    ),
                  ),
                Wrap(
                  spacing: AppSpacing.s8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    _QuickAction(
                      icon: Icons.add_rounded,
                      label: l10n.dashboardAddMealAction,
                      onTap: onAddMeal,
                      background: p.primaryTint,
                      foreground: Theme.of(context).colorScheme.primary,
                    ),
                    _QuickAction(
                      icon: Icons.photo_camera_outlined,
                      label: l10n.dashboardPhotoAction,
                      onTap: onPhoto,
                      background: p.nested,
                      foreground: p.text,
                    ),
                  ],
                ),
              ],
            ),
          ),
          children: rows,
        ),
      ],
    );
  }

  Widget _row(BuildContext context, AppLocalizations l10n, LifeyFormat f, TodayMealGroup group) {
    final meals = [...group.meals]..sort((a, b) => a.dateTime.compareTo(b.dateTime));
    final time = f.time(meals.first.dateTime.toLocal());
    final typeLabel = group.type.label(l10n);

    final named = meals.length == 1 && (meals.first.name?.trim().isNotEmpty ?? false);
    final foods = meals.expand((m) => m.entries).map((e) => e.foodName).take(3).join(', ');
    final title = named ? meals.first.name!.trim() : typeLabel;
    final subtitle = [
      if (named) typeLabel else if (foods.isNotEmpty) foods,
      time,
    ].join(' · ');

    final (icon, color) = mealTypeStyle(context, group.type);
    return ListRow(
      leading: ListIconHolder(icon: icon, color: color),
      title: title,
      subtitle: subtitle,
      trailing: ListRowValue(value: f.kcal(group.totalCalories), unit: 'kcal'),
      onTap: onMealTap,
    );
  }
}

/// The 36 px pill button inside the meals card: a 48 dp touch box around it.
class _QuickAction extends StatelessWidget {
  const _QuickAction({
    required this.icon,
    required this.label,
    required this.onTap,
    required this.background,
    required this.foreground,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color background;
  final Color foreground;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 48),
      child: Center(
        widthFactor: 1,
        child: Material(
          color: background,
          borderRadius: AppRadius.controlAll,
          child: InkWell(
            onTap: onTap,
            borderRadius: AppRadius.controlAll,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 36),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(icon, size: 18, color: foreground),
                    const SizedBox(width: 6),
                    Text(
                      label,
                      style: Theme.of(context).textTheme.bodySmall!.copyWith(fontWeight: FontWeight.w700, color: foreground),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
