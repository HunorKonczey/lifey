import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../../core/theme/app_tokens.dart';
import '../../../../../l10n/app_localizations.dart';
import '../../../../nutrition/domain/meal.dart' show MealType;
import '../../application/client_detail_providers.dart';
import '../../domain/client_data.dart';
import '../widgets/client_tab_body.dart';
import '../widgets/read_only_badge.dart';

const _mealIcons = {
  MealType.breakfast: Icons.bakery_dining_outlined,
  MealType.lunch: Icons.lunch_dining_outlined,
  MealType.dinner: Icons.dinner_dining_outlined,
  MealType.snack: Icons.icecream_outlined,
};

/// One day of the client's food log, against their goals — the read half of
/// the nutrition tab. Setting those goals is a write, and belongs to T7.
class ClientNutritionTab extends ConsumerStatefulWidget {
  const ClientNutritionTab({
    super.key,
    required this.clientId,
    required this.offline,
  });

  final int clientId;
  final bool offline;

  @override
  ConsumerState<ClientNutritionTab> createState() => _ClientNutritionTabState();
}

class _ClientNutritionTabState extends ConsumerState<ClientNutritionTab> {
  DateTime _day = dayKey(DateTime.now());

  bool get _isToday => _day == dayKey(DateTime.now());

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    final locale = Localizations.localeOf(context).toString();
    final integer = NumberFormat.decimalPattern(locale);

    final mealsKey = (clientId: widget.clientId, day: _day);
    final meals = ref.watch(clientMealsProvider(mealsKey));
    final goals = ref.watch(clientNutritionGoalsProvider(widget.clientId));

    return ClientTabBody(
      states: [meals, goals],
      offline: widget.offline,
      onRefresh: () async {
        ref.invalidate(clientMealsProvider(mealsKey));
        ref.invalidate(clientNutritionGoalsProvider(widget.clientId));
        await Future.wait([
          ref.read(clientMealsProvider(mealsKey).future),
          ref.read(clientNutritionGoalsProvider(widget.clientId).future),
        ]);
      },
      builder: (context) {
        final dayMeals = meals.requireValue;
        final dayGoals = goals.requireValue;
        final totalCalories = dayMeals.fold<double>(0, (sum, m) => sum + m.calories);

        return ListView(
          key: const ValueKey('trainerNutritionList'),
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
          children: [
            Row(
              children: [
                Expanded(child: _DayNavigator(
                  day: _day,
                  isToday: _isToday,
                  onChange: (day) => setState(() => _day = day),
                )),
                const SizedBox(width: 8),
                const ReadOnlyBadge(),
              ],
            ),
            const SizedBox(height: 12),
            _TotalsCard(meals: dayMeals, goals: dayGoals),
            const SizedBox(height: 16),
            for (final type in MealType.values) ...[
              _MealGroup(
                type: type,
                meals: dayMeals.where((meal) => meal.mealType == type).toList(),
              ),
              const SizedBox(height: 14),
            ],
            if (dayMeals.isEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  l10n.trainerNoMealsLoggedMessage,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                ),
              )
            else
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  l10n.trainerDayTotalLabel(
                    l10n.trainerKcalValue(integer.format(totalCalories.round())),
                  ),
                  textAlign: TextAlign.center,
                  style: theme.textTheme.labelSmall
                      ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                ),
              ),
          ],
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Day navigator
// ---------------------------------------------------------------------------

class _DayNavigator extends StatelessWidget {
  const _DayNavigator({
    required this.day,
    required this.isToday,
    required this.onChange,
  });

  final DateTime day;
  final bool isToday;
  final ValueChanged<DateTime> onChange;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    final locale = Localizations.localeOf(context).toString();

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainer,
        borderRadius: AppRadius.pill,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left, size: 20),
            tooltip: l10n.trainerPreviousDayTooltip,
            onPressed: () => onChange(day.subtract(const Duration(days: 1))),
          ),
          Expanded(
            child: Text(
              isToday ? l10n.todayGroupLabel : DateFormat.MMMEd(locale).format(day),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.labelLarge
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right, size: 20),
            tooltip: l10n.trainerNextDayTooltip,
            // There is nothing logged in the future, and letting the trainer
            // walk into empty days would look like missing data.
            onPressed: isToday
                ? null
                : () => onChange(day.add(const Duration(days: 1))),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Totals against goals
// ---------------------------------------------------------------------------

class _TotalsCard extends StatelessWidget {
  const _TotalsCard({required this.meals, required this.goals});

  final List<ClientMeal> meals;
  final ClientNutritionGoals goals;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    final metrics = context.metricColors;
    final integer =
        NumberFormat.decimalPattern(Localizations.localeOf(context).toString());

    final calories = meals.fold<double>(0, (sum, m) => sum + m.calories);
    final protein = meals.fold<double>(0, (sum, m) => sum + m.protein);
    final carbs = meals.fold<double>(0, (sum, m) => sum + m.carbs);
    final fat = meals.fold<double>(0, (sum, m) => sum + m.fat);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainer,
        borderRadius: AppRadius.lgAll,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _GoalRow(
            label: l10n.caloriesLabel,
            value: calories,
            goal: goals.dailyCalorieGoal,
            color: metrics.calories,
            formatValue: (v) => l10n.trainerKcalValue(integer.format(v.round())),
          ),
          const SizedBox(height: 10),
          _GoalRow(
            label: l10n.proteinLabel,
            value: protein,
            goal: goals.dailyProteinGoal,
            color: metrics.protein,
            formatValue: (v) => l10n.trainerGramsValue(integer.format(v.round())),
          ),
          const SizedBox(height: 10),
          _GoalRow(
            label: l10n.carbsLabel,
            value: carbs,
            goal: goals.dailyCarbsGoal,
            color: metrics.carbs,
            formatValue: (v) => l10n.trainerGramsValue(integer.format(v.round())),
          ),
          const SizedBox(height: 10),
          _GoalRow(
            label: l10n.fatLabel,
            value: fat,
            goal: goals.dailyFatGoal,
            color: metrics.fat,
            formatValue: (v) => l10n.trainerGramsValue(integer.format(v.round())),
          ),
          if (goals.isEmpty) ...[
            const SizedBox(height: 12),
            Text(
              l10n.trainerNoNutritionGoalsMessage,
              style: theme.textTheme.labelSmall
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
          ],
        ],
      ),
    );
  }
}

class _GoalRow extends StatelessWidget {
  const _GoalRow({
    required this.label,
    required this.value,
    required this.goal,
    required this.color,
    required this.formatValue,
  });

  final String label;
  final double value;
  final double? goal;
  final Color color;
  final String Function(double) formatValue;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final goal = this.goal;
    // No goal means no bar at all — a full-width empty track would read as
    // "zero progress" rather than "nothing to progress towards".
    final progress = goal == null || goal <= 0 ? null : (value / goal).clamp(0.0, 1.0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
            ),
            Text(
              goal == null
                  ? formatValue(value)
                  : '${formatValue(value)} / ${formatValue(goal)}',
              style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w700),
            ),
          ],
        ),
        if (progress != null) ...[
          const SizedBox(height: 5),
          ClipRRect(
            borderRadius: AppRadius.pill,
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 5,
              backgroundColor: theme.colorScheme.surfaceContainerHighest,
              valueColor: AlwaysStoppedAnimation(color),
            ),
          ),
        ],
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// One meal type's meals
// ---------------------------------------------------------------------------

class _MealGroup extends StatelessWidget {
  const _MealGroup({required this.type, required this.meals});

  final MealType type;
  final List<ClientMeal> meals;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    final metrics = context.metricColors;
    final integer =
        NumberFormat.decimalPattern(Localizations.localeOf(context).toString());
    final groupCalories = meals.fold<double>(0, (sum, m) => sum + m.calories);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 6),
          child: Row(
            children: [
              Icon(_mealIcons[type], size: 18, color: metrics.calories),
              const SizedBox(width: 8),
              Text(
                type.label(l10n),
                style: theme.textTheme.titleSmall
                    ?.copyWith(fontWeight: FontWeight.w800),
              ),
              const Spacer(),
              if (meals.isNotEmpty)
                Text(
                  l10n.trainerKcalValue(integer.format(groupCalories.round())),
                  style: theme.textTheme.labelMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: metrics.calories,
                  ),
                ),
            ],
          ),
        ),
        if (meals.isEmpty)
          Padding(
            padding: const EdgeInsets.only(left: 4),
            child: Text(
              l10n.trainerNothingLoggedLabel,
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
          )
        else
          for (final meal in meals) _MealCard(meal: meal),
      ],
    );
  }
}

class _MealCard extends StatelessWidget {
  const _MealCard({required this.meal});

  final ClientMeal meal;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    final integer =
        NumberFormat.decimalPattern(Localizations.localeOf(context).toString());

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainer,
        borderRadius: AppRadius.cardAll,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (meal.name.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Text(
                meal.name,
                style: theme.textTheme.bodyMedium
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
            ),
          for (final entry in meal.entries)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      entry.foodName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    l10n.trainerGramsValue(integer.format(entry.quantityInGrams.round())),
                    style: theme.textTheme.labelSmall
                        ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    l10n.trainerKcalValue(integer.format(entry.calories.round())),
                    style: theme.textTheme.labelSmall
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
