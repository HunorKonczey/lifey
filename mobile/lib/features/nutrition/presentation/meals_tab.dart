import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/ads/banner_ad_slot.dart';
import '../../../core/entitlements/entitlement_providers.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/widgets/empty_view.dart';
import '../../../shared/widgets/ds/list_group.dart';
import '../../../shared/widgets/error_view.dart';
import '../../settings/application/settings_controller.dart';
import '../../settings/domain/user_settings.dart';
import '../application/daily_macros_controller.dart';
import '../application/meal_controller.dart';
import '../application/selected_meal_day_provider.dart';
import '../domain/daily_macros.dart';
import '../domain/meal.dart';
import '../domain/meal_days.dart';
import 'log_meal_screen.dart';
import 'widgets/day_budget_card.dart';
import 'widgets/meal_list_item.dart';
import 'widgets/week_strip.dart';

/// "Meals" tab: the week strip, the selected day's budget and its meals
/// (docs/redesign/77-mobile-redesign-plan.md R2.2 / R2.3; canvas Lifey 2 ›
/// 2.1).
///
/// The strip picks the day ([selectedMealDayProvider]); the budget card and
/// the list under it are that day's. Every earlier day is in the all-meals
/// screen (the calendar button in the header). A day with no meals shows the
/// empty state with "Add meal" — logging onto that day — and, for today,
/// "Copy a day".
class MealsTab extends ConsumerWidget {
  const MealsTab({super.key, this.onCopyDay});

  /// Opens the copy-a-previous-day sheet (owned by the screen, which also
  /// shows the result snackbar). Without it today's empty state offers no
  /// "Copy a day".
  final VoidCallback? onCopyDay;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final now = DateTime.now();
    final day = effectiveMealDay(ref.watch(selectedMealDayProvider), now);
    final isToday = day == dateOnly(now);
    final mealsAsync = ref.watch(mealsOnDayProvider(day));
    final settings = ref.watch(settingsControllerProvider).value ?? const UserSettings.defaults();
    final cutoff = ref.watch(historyCutoffProvider);
    final bottomPad = MediaQuery.paddingOf(context).bottom + ref.watch(bannerAdSlotHeightProvider(1));

    final dailyMacros = ref.watch(dailyMacrosProvider).value ?? const <DailyMacros>[];
    final kcalByDay = {for (final d in dailyMacros) d.day: d.calories};

    return mealsAsync.when(
      data: (all) {
        // The free history window (`67` §3.2, D-P6) — applied on top of the day
        // query, never a change to it.
        final visible = cutoff == null ? all : all.where((m) => !m.dateTime.toLocal().isBefore(cutoff)).toList();
        // A day reads top to bottom like a diary: the repository hands them
        // newest first.
        final meals = visible.reversed.toList();
        return RefreshIndicator(
          onRefresh: () => ref.read(mealControllerProvider.notifier).refresh(),
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: EdgeInsets.fromLTRB(AppSpacing.screen, AppSpacing.s8, AppSpacing.screen, bottomPad + 88),
            children: [
              WeekStrip(
                days: lastSevenDays(now),
                selected: day,
                kcalByDay: kcalByDay,
                goal: settings.dailyCalorieGoal,
                onSelect: (d) => ref.read(selectedMealDayProvider.notifier).select(d),
              ),
              const SizedBox(height: AppSpacing.s16),
              DayBudgetCard(totals: _totals(day, meals), settings: settings),
              const SizedBox(height: AppSpacing.s16),
              if (meals.isEmpty)
                EmptyStateCard(
                  icon: Icons.lunch_dining_outlined,
                  title: isToday ? l10n.mealsEmptyTodayTitle : l10n.mealsEmptyDayTitle,
                  subtitle: l10n.mealsEmptyMessage,
                  action: FilledButton(
                    onPressed: () => Navigator.of(context, rootNavigator: true).push(
                      MaterialPageRoute(builder: (_) => LogMealScreen(initialDate: day)),
                    ),
                    child: Text(l10n.mealsEmptyAddAction),
                  ),
                  secondaryAction: isToday && onCopyDay != null
                      ? OutlinedButton(onPressed: onCopyDay, child: Text(l10n.mealsEmptyCopyAction))
                      : null,
                )
              else
                ListGroup(children: [for (final meal in meals) MealListItem(meal: meal)]),
            ],
          ),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => ErrorView(
        error: error,
        onRetry: () => ref.read(mealControllerProvider.notifier).refresh(),
      ),
    );
  }

  /// The day's totals from its own meals — always in step with the list
  /// under the card. Null when nothing is logged, so the card reads zero.
  static DailyMacros? _totals(DateTime day, List<Meal> meals) {
    if (meals.isEmpty) return null;
    return DailyMacros(
      day: day,
      calories: meals.fold(0, (s, m) => s + m.totalCalories),
      protein: meals.fold(0, (s, m) => s + m.totalProtein),
      carbs: meals.fold(0, (s, m) => s + m.totalCarbs),
      fat: meals.fold(0, (s, m) => s + m.totalFat),
    );
  }
}
