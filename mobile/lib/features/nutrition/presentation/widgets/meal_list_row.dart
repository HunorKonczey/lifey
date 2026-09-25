import 'package:flutter/material.dart';

import '../../../../core/format/lifey_format.dart';
import '../../../../core/theme/app_tokens.dart';
import '../../../../core/theme/app_type.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../shared/widgets/ds/list_group.dart';
import '../../../../shared/widgets/sync_status_indicator.dart';
import '../../domain/meal.dart';
import 'meal_type_style.dart';

/// One logged meal in a `ListGroup` of the Meals tab and the all-meals list
/// (docs/redesign/77-mobile-redesign-plan.md R2.3; canvas Lifey 2 › 2.1).
///
/// Icon holder tinted by meal type; the name (or the type when the meal has
/// no name) over "Breakfast · 07:15" with the kcal on the right and P / C / F
/// in their metric colours under it, then the foods as one line that wraps to
/// two instead of truncating ("Blueberries", not "Bluebe…"). Tap edits,
/// long-press opens the meal's menu. Nothing in a row is fixed-width, so the
/// meta line and the macros drop under each other in Hungarian and at 130 %.
class MealListRow extends StatelessWidget {
  const MealListRow({super.key, required this.meal, required this.onTap, required this.onLongPress});

  final Meal meal;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final f = LifeyFormat.of(context);
    final p = context.palette;
    final mc = context.metricColors;
    final t = Theme.of(context).textTheme;
    final (icon, color) = mealTypeStyle(context, meal.mealType);

    final typeLabel = meal.mealType.label(l10n);
    final named = meal.name?.trim().isNotEmpty ?? false;
    final title = named ? meal.name!.trim() : typeLabel;
    final time = f.time(meal.dateTime.toLocal());
    final meta = named ? '$typeLabel · $time' : time;
    final foods = meal.entries.map((e) => e.foodName).join(', ');

    final secondary = t.bodySmall!.copyWith(fontSize: 13, height: 1.4, fontWeight: FontWeight.w500, color: p.text2);
    TextStyle macroStyle(Color c) => TextStyle(
          fontFamily: AppType.fontFamily,
          fontSize: 12,
          height: 1,
          fontWeight: FontWeight.w700,
          color: c,
          fontFeatures: AppType.tabular,
        );

    return InkWell(
      onTap: onTap,
      onLongPress: onLongPress,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s16, vertical: 14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ListIconHolder(icon: icon, color: color),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Expanded(
                        child: Text(
                          title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: t.titleMedium!.copyWith(fontSize: 16, height: 1.25, color: p.text),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.s8),
                      ListRowValue(value: f.kcal(meal.totalCalories), unit: 'kcal', size: 16),
                    ],
                  ),
                  const SizedBox(height: 5),
                  Wrap(
                    alignment: WrapAlignment.spaceBetween,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: AppSpacing.s8,
                    runSpacing: AppSpacing.s4,
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Flexible(child: Text(meta, style: secondary)),
                          SyncStatusIndicator(clientId: meal.clientId),
                        ],
                      ),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text('${l10n.macroLetterProtein} ${f.grams(meal.totalProtein)}',
                              style: macroStyle(mc.protein)),
                          const SizedBox(width: 10),
                          Text('${l10n.macroLetterCarbs} ${f.grams(meal.totalCarbs)}', style: macroStyle(mc.carbs)),
                          const SizedBox(width: 10),
                          Text('${l10n.macroLetterFat} ${f.grams(meal.totalFat)}', style: macroStyle(mc.fat)),
                        ],
                      ),
                    ],
                  ),
                  if (foods.isNotEmpty) ...[
                    const SizedBox(height: 5),
                    Text(foods, maxLines: 2, overflow: TextOverflow.ellipsis, style: secondary),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
