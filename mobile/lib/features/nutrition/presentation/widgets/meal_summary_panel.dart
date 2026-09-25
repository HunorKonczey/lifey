import 'package:flutter/material.dart';

import '../../../../core/format/lifey_format.dart';
import '../../../../core/theme/app_tokens.dart';
import '../../../../core/theme/app_type.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../shared/widgets/ds/animated_number.dart';
import '../../../../shared/widgets/ds/lifey_card.dart';
import '../../../../shared/widgets/ds/metric_bar.dart';
import '../../domain/meal_budget_preview.dart';

/// The meal editor's floating summary, pinned above the keyboard / the bottom
/// edge so it stays in view while the food list scrolls (docs/redesign/
/// 77-mobile-redesign-plan.md R2.5; canvas Lifey 2 › 2.2 "Mentés a fejlécben,
/// összesítő lebegve").
///
/// "Meal total" with the kcal counting up as foods change, the three macros as
/// tinted tiles, and — when the day has a calorie goal — "Today after this
/// meal: 1,356 kcal left" over a bar in which the day's other meals are solid
/// and this meal's share is paler, so its effect is visible.
class MealSummaryPanel extends StatelessWidget {
  const MealSummaryPanel({
    super.key,
    required this.calories,
    required this.protein,
    required this.carbs,
    required this.fat,
    this.preview,
    this.day,
  });

  final double calories;
  final double protein;
  final double carbs;
  final double fat;

  /// Null without a calorie goal — the panel is then just the meal total.
  final MealBudgetPreview? preview;

  /// The meal's day when it isn't today; the label names it.
  final DateTime? day;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final f = LifeyFormat.of(context);
    final p = context.palette;
    final mc = context.metricColors;
    final preview = this.preview;

    final small = TextStyle(
      fontFamily: AppType.fontFamily,
      fontSize: 14,
      height: 1.2,
      fontWeight: FontWeight.w600,
      color: p.text2,
    );

    return LifeyCard(
      radius: AppRadius.hero,
      color: p.nested,
      padding: const EdgeInsets.fromLTRB(AppSpacing.s16, AppSpacing.s16, AppSpacing.s16, 14),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(child: Text(l10n.mealTotalLabel, style: small)),
              AnimatedNumber(
                value: calories,
                builder: (context, v) => Text(
                  f.kcal(v),
                  style: TextStyle(
                    fontFamily: AppType.fontFamily,
                    fontSize: 34,
                    height: 1.1,
                    letterSpacing: -0.02 * 34,
                    fontWeight: FontWeight.w800,
                    color: p.text,
                    fontFeatures: AppType.tabular,
                  ),
                ),
              ),
              Expanded(child: Text('kcal', textAlign: TextAlign.end, style: small)),
            ],
          ),
          const SizedBox(height: AppSpacing.s12),
          Row(
            children: [
              Expanded(child: _MacroTile(value: protein, label: l10n.proteinLabel, color: mc.protein)),
              const SizedBox(width: AppSpacing.s8),
              Expanded(child: _MacroTile(value: carbs, label: l10n.carbsLabel, color: mc.carbs)),
              const SizedBox(width: AppSpacing.s8),
              Expanded(child: _MacroTile(value: fat, label: l10n.fatLabel, color: mc.fat)),
            ],
          ),
          if (preview != null) ...[
            const SizedBox(height: AppSpacing.s12),
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: AppSpacing.s8,
              children: [
                Text(
                  day == null ? l10n.mealSummaryAfterToday : l10n.mealSummaryAfterDay(f.shortDayLabel(day!)),
                  style: small.copyWith(fontSize: 13),
                ),
                Text(
                  preview.isOver
                      ? l10n.mealSummaryKcalOver(f.kcal(-preview.remaining))
                      : l10n.mealSummaryKcalLeft(f.kcal(preview.remaining)),
                  style: small.copyWith(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: preview.isOver ? mc.negative : mc.calories,
                    fontFeatures: AppType.tabular,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.s8),
            RatioBar(
              height: 6,
              total: preview.goal.toDouble(),
              segments: [
                (value: preview.othersKcal, color: mc.calories),
                (value: preview.draftKcal, color: mc.calories.withValues(alpha: 0.45)),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// "23 g / Protein" in a tile tinted with the macro colour.
class _MacroTile extends StatelessWidget {
  const _MacroTile({required this.value, required this.label, required this.color});

  final double value;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final f = LifeyFormat.of(context);
    final alpha = Theme.of(context).brightness == Brightness.dark ? 0.16 : 0.12;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s12, vertical: AppSpacing.s8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: alpha),
        borderRadius: BorderRadius.circular(AppRadius.control),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '${f.grams(value)} g',
            maxLines: 1,
            style: TextStyle(
              fontFamily: AppType.fontFamily,
              fontSize: 20,
              height: 1.1,
              fontWeight: FontWeight.w800,
              color: color,
              fontFeatures: AppType.tabular,
            ),
          ),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontFamily: AppType.fontFamily,
              fontSize: 14,
              height: 1.2,
              fontWeight: FontWeight.w500,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
