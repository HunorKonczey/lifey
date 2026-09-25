import 'package:flutter/material.dart';

import '../../../../core/format/lifey_format.dart';
import '../../../../core/theme/app_tokens.dart';
import '../../../../core/theme/app_type.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../shared/widgets/ds/animated_number.dart';
import '../../../../shared/widgets/ds/lifey_card.dart';
import '../../../../shared/widgets/ds/metric_bar.dart';
import '../../../../shared/widgets/ds/tinted_chip.dart';
import '../../../settings/domain/user_settings.dart';
import '../../domain/daily_macros.dart';

/// The selected day's budget, always on top of the Meals tab: the eaten kcal
/// against the goal with a "1,739 left" chip, one bar in which the three
/// macros take their share of the calorie goal, and the three gram lines with
/// each value in its own colour (docs/redesign/77-mobile-redesign-plan.md
/// R2.3; canvas Lifey 2 › 2.1 "Napi keret az étkezések fölött").
///
/// The bar's segments are `grams × kcal-per-gram / calorie goal` (protein and
/// carbs 4, fat 9), so an empty stretch is what is left of the budget; past
/// the goal the segments scale down together and the chip turns into the
/// overage. Without a calorie goal the bar shows the macros' relative share
/// and there is no chip; a macro without a goal shows just its grams.
class DayBudgetCard extends StatelessWidget {
  const DayBudgetCard({super.key, required this.totals, required this.settings});

  /// Null for a day without meals — everything reads 0.
  final DailyMacros? totals;
  final UserSettings settings;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final f = LifeyFormat.of(context);
    final p = context.palette;
    final mc = context.metricColors;

    final calories = totals?.calories ?? 0;
    final protein = totals?.protein ?? 0;
    final carbs = totals?.carbs ?? 0;
    final fat = totals?.fat ?? 0;
    final goal = settings.dailyCalorieGoal;
    final hasGoal = goal != null && goal > 0;
    final over = hasGoal && calories > goal;

    final bigStyle = TextStyle(
      fontFamily: AppType.fontFamily,
      fontSize: 28,
      height: 1,
      letterSpacing: -0.02 * 28,
      fontWeight: FontWeight.w800,
      color: p.text,
      fontFeatures: AppType.tabular,
    );
    final unitStyle = TextStyle(
      fontFamily: AppType.fontFamily,
      fontSize: 14,
      height: 1,
      fontWeight: FontWeight.w600,
      color: p.text2,
      fontFeatures: AppType.tabular,
    );

    final remaining = hasGoal ? (goal - calories).abs() : 0.0;
    final chip = !hasGoal
        ? null
        : TintedChip(
            label: over ? l10n.dayBudgetKcalOver(f.kcal(remaining)) : l10n.dayBudgetKcalLeft(f.kcal(remaining)),
            color: mc.calories,
          );

    return LifeyCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Wrap(
                  crossAxisAlignment: WrapCrossAlignment.end,
                  children: [
                    AnimatedNumber(
                      value: calories,
                      builder: (context, v) => Text(f.kcal(v), style: bigStyle),
                    ),
                    Text(
                      hasGoal ? ' ${l10n.dayBudgetOfGoal(f.kcal(goal))}' : ' kcal',
                      style: unitStyle,
                    ),
                  ],
                ),
              ),
              if (chip != null) ...[const SizedBox(width: AppSpacing.s8), chip],
            ],
          ),
          const SizedBox(height: AppSpacing.s12),
          RatioBar(
            total: hasGoal ? goal.toDouble() : null,
            segments: [
              (value: protein * 4, color: mc.protein),
              (value: carbs * 4, color: mc.carbs),
              (value: fat * 9, color: mc.fat),
            ],
          ),
          const SizedBox(height: AppSpacing.s12),
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            runSpacing: AppSpacing.s4,
            children: [
              _MacroLine(
                  value: protein, goal: settings.dailyProteinGoal, letter: l10n.macroLetterProtein, color: mc.protein),
              _MacroLine(
                  value: carbs, goal: settings.dailyCarbsGoal, letter: l10n.macroLetterCarbs, color: mc.carbs),
              _MacroLine(value: fat, goal: settings.dailyFatGoal, letter: l10n.macroLetterFat, color: mc.fat),
            ],
          ),
        ],
      ),
    );
  }
}

/// "29 / 129 g P": the value bold in the macro colour, the rest secondary.
class _MacroLine extends StatelessWidget {
  const _MacroLine({required this.value, required this.goal, required this.letter, required this.color});

  final double value;
  final int? goal;
  final String letter;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final f = LifeyFormat.of(context);
    final p = context.palette;
    final base = TextStyle(
      fontFamily: AppType.fontFamily,
      fontSize: 13,
      height: 1.2,
      fontWeight: FontWeight.w600,
      color: p.text2,
      fontFeatures: AppType.tabular,
    );
    final hasGoal = goal != null && goal! > 0;
    return Text.rich(
      TextSpan(style: base, children: [
        TextSpan(
          text: f.grams(value),
          style: base.copyWith(fontWeight: FontWeight.w800, color: color),
        ),
        TextSpan(text: hasGoal ? ' / ${f.grams(goal!)} g $letter' : ' g $letter'),
      ]),
      maxLines: 1,
      softWrap: false,
    );
  }
}
