import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/sync/pull_engine.dart';
import '../../../core/sync/sync_engine_provider.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/widgets/adaptive_app_bar.dart';
import '../../../shared/widgets/nav_collapse_controller.dart';
import '../../auth/application/auth_controller.dart';
import '../../settings/application/settings_controller.dart';
import '../../settings/domain/user_settings.dart';
import '../../water/presentation/widgets/add_water_sheet.dart';
import '../../water/presentation/widgets/water_card.dart';
import '../../weight/application/weight_controller.dart';
import '../../weight/domain/weight_entry.dart';
import '../../workouts/application/workout_session_controller.dart';
import '../../workouts/presentation/log_session_screen.dart';
import '../../nutrition/domain/meal.dart';
import '../../nutrition/presentation/nutrition_screen.dart';
import '../application/dashboard_controller.dart';
import '../application/today_steps_controller.dart';
import '../domain/dashboard_data.dart';
import '../domain/recent_workout.dart';
import '../domain/today_meal_group.dart';
import 'widgets/calorie_sparkline_card.dart';
import 'widgets/stat_card.dart';

// Vertical layout constants shared between DashboardScreen and _DashboardBody.
const double _kBarTopGap = 8.0;   // status-bar-bottom → bar top
const double _kBarHeight = 58.0;  // expanded AdaptiveAppBar height
const double _kBarBotGap = 12.0;  // bar bottom → first content item

Future<void> _openAddWaterSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => const AddWaterSheet(),
  );
}

/// Opens the matching session straight into edit mode, falling back to the
/// "Workouts" tab if the session isn't in the local cache (e.g. mid-sync).
Future<void> _openWorkout(BuildContext context, WidgetRef ref, String clientId) async {
  final sessions = ref.read(workoutSessionControllerProvider).value ?? const [];
  final session = sessions.where((s) => s.clientId == clientId).firstOrNull;
  if (session == null) {
    context.go('/workouts');
    return;
  }
  await Navigator.of(context).push(
    MaterialPageRoute(builder: (_) => LogSessionScreen(session: session)),
  );
}

enum WeightTrend { up, down }

typedef WeightDelta = ({WeightTrend trend, double diff});

/// Compares the two most recent entries (newest first). Null when there
/// aren't at least two entries, or the weight didn't change.
WeightDelta? _weightDelta(List<WeightEntry> entries) {
  if (entries.length < 2) return null;
  final diff = entries[0].weight - entries[1].weight;
  if (diff > 0) return (trend: WeightTrend.up, diff: diff);
  if (diff < 0) return (trend: WeightTrend.down, diff: diff.abs());
  return null;
}

/// Dashboard: today's calories & macros, current weight, recent workouts.
/// Fully local-first — works offline, and updates the instant a write lands
/// in any of the underlying feature repositories (see
/// `dashboardControllerProvider`), so unlike before, no manual refresh is
/// needed to see a just-logged meal/weight/workout/water entry show up.
class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  /// Pull-to-refresh now means "sync now" (push then pull) rather than
  /// re-fetching this screen's own data, since that's already live —
  /// useful for forcing a sync attempt without waiting for the next
  /// automatic trigger.
  Future<void> _forceSync(WidgetRef ref) async {
    try {
      await ref.read(syncEngineProvider).sync();
      await ref.read(pullEngineProvider).pullAll();
    } catch (_) {
      // Best-effort, same as the automatic triggers — no connectivity or a
      // backend error just means try again later.
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data = ref.watch(dashboardControllerProvider);
    final settings = ref.watch(settingsControllerProvider).value ?? const UserSettings.defaults();
    final weightDelta = _weightDelta(ref.watch(weightControllerProvider).value ?? const []);
    final todaySteps = ref.watch(todayStepsControllerProvider).value;
    final l10n = AppLocalizations.of(context)!;

    final statusTop = MediaQuery.paddingOf(context).top;
    final barTop = statusTop + _kBarTopGap;
    final contentTop = barTop + _kBarHeight + _kBarBotGap;

    return Scaffold(
      body: ScrollCollapseListener(
        child: Stack(
          children: [
            Positioned.fill(
              child: RefreshIndicator(
                displacement: contentTop,
                onRefresh: () => _forceSync(ref),
                child: _DashboardBody(
                  data: data,
                  settings: settings,
                  weightDelta: weightDelta,
                  todaySteps: todaySteps,
                  onWorkoutTap: (clientId) => _openWorkout(context, ref, clientId),
                  onMealsTap: () {
                    ref.read(nutritionPendingTabProvider.notifier).set(1);
                    context.go('/nutrition');
                  },
                ),
              ),
            ),
            Positioned(
              top: barTop,
              left: 12,
              right: 12,
              child: AdaptiveAppBar(
                title: l10n.dashboardTodayTitle,
                actions: [
                  AdaptiveAppBarAction(
                    icon: Icons.settings_outlined,
                    tooltip: l10n.settingsTitle,
                    onPressed: () => context.push('/settings'),
                  ),
                  AdaptiveAppBarAction(
                    icon: Icons.logout,
                    tooltip: l10n.logOutTooltip,
                    onPressed: () => ref.read(authControllerProvider.notifier).logout(),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DashboardBody extends StatelessWidget {
  const _DashboardBody({
    required this.data,
    required this.settings,
    required this.onWorkoutTap,
    required this.onMealsTap,
    this.weightDelta,
    this.todaySteps,
  });

  final DashboardData data;
  final UserSettings settings;
  final WeightDelta? weightDelta;
  final int? todaySteps;
  final ValueChanged<String> onWorkoutTap;
  final VoidCallback onMealsTap;

  double? _ratio(double actual, int? goal) =>
      (goal == null || goal <= 0) ? null : actual / goal;

  @override
  Widget build(BuildContext context) {
    final stats = data.stats;
    final weight = stats.latestWeight;
    final l10n = AppLocalizations.of(context)!;
    final mc = context.metricColors;

    final calorieRatio = _ratio(stats.calories, settings.dailyCalorieGoal);
    final proteinRatio = _ratio(stats.protein, settings.dailyProteinGoal);
    final carbsRatio = _ratio(stats.carbs, settings.dailyCarbsGoal);
    final fatRatio = _ratio(stats.fat, settings.dailyFatGoal);

    // ── Badge texts ───────────────────────────────────────────────────────
    final calGoal = settings.dailyCalorieGoal;
    final String? calorieBadge = calGoal == null
        ? null
        : stats.calories < calGoal
            ? l10n.kcalLeftBadge((calGoal - stats.calories).round())
            : l10n.kcalOverBadge((stats.calories - calGoal).round());
    final Color calorieBadgeColor = (calorieRatio ?? 0) >= 1 ? mc.negative : mc.positive;

    final protGoal = settings.dailyProteinGoal;
    final String? proteinBadge = (protGoal == null || stats.protein >= protGoal)
        ? null
        : l10n.proteinMoreBadge((protGoal - stats.protein).round());

    final statusTop = MediaQuery.paddingOf(context).top;
    final contentTop = statusTop + _kBarTopGap + _kBarHeight + _kBarBotGap;
    final bottomPad = MediaQuery.paddingOf(context).bottom + 16;

    return ListView(
      padding: EdgeInsets.fromLTRB(16, contentTop, 16, bottomPad),
      children: [
        // ── Water ────────────────────────────────────────────────────────
        WaterCard(
          currentLiters: stats.water,
          goalLiters: settings.dailyWaterGoalLiters,
          onAdd: () => _openAddWaterSheet(context),
        ),
        const SizedBox(height: 16),

        // ── Greeting ─────────────────────────────────────────────────
        _DayGreeting(l10n: l10n),
        const SizedBox(height: 4),

        // ── Calories — hero metric, full width ────────────────────────
        StatCard(
          label: l10n.todaysCaloriesLabel,
          value: stats.calories.toStringAsFixed(0),
          unit: 'kcal',
          icon: Icons.local_fire_department,
          color: mc.calories,
          ratio: calorieRatio,
          goalReached: (calorieRatio ?? 0) >= 1,
          goalTone: GoalTone.negative,
          onTap: () => context.go('/nutrition'),
          badgeText: calorieBadge,
          badgeColor: calorieBadgeColor,
        ),
        const SizedBox(height: 12),

        // ── Macro row: protein | carbs | fat ──────────────────────────
        Row(
          children: [
            Expanded(
              child: StatCard(
                label: l10n.proteinLabel,
                value: stats.protein.toStringAsFixed(0),
                unit: 'g',
                icon: Icons.egg_alt,
                color: mc.protein,
                ratio: proteinRatio,
                goalReached: (proteinRatio ?? 0) >= 1,
                goalTone: GoalTone.positive,
                compact: true,
                badgeText: proteinBadge,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: StatCard(
                label: l10n.carbsLabel,
                value: stats.carbs.toStringAsFixed(0),
                unit: 'g',
                icon: Icons.bakery_dining,
                color: mc.carbs,
                ratio: carbsRatio,
                goalReached: (carbsRatio ?? 0) >= 1,
                compact: true,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: StatCard(
                label: l10n.fatLabel,
                value: stats.fat.toStringAsFixed(0),
                unit: 'g',
                icon: Icons.water_drop,
                color: mc.fat,
                ratio: fatRatio,
                goalReached: (fatRatio ?? 0) >= 1,
                compact: true,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // ── Steps + Weight row ────────────────────────────────────────
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (todaySteps != null) ...[
              Expanded(
                child: _StepsCard(
                  steps: todaySteps!,
                  goal: settings.dailyStepGoal,
                ),
              ),
              const SizedBox(width: 10),
            ],
            Expanded(
              child: StatCard(
                label: l10n.latestEntryLabel,
                value: weight != null ? weight.toStringAsFixed(1) : '—',
                unit: weight != null ? 'kg' : null,
                icon: Icons.monitor_weight,
                color: mc.weight,
                onTap: () => context.go('/weight'),
                valueTrailing: weightDelta == null
                    ? null
                    : _WeightDeltaBadge(delta: weightDelta!),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),

        // ── Weekly calorie sparkline ───────────────────────────────────
        CalorieSparklineCard(points: data.weeklyCalories),
        const SizedBox(height: 24),

        // ── Today's meals ─────────────────────────────────────────────
        _SectionTitle(l10n.todaysMealsSectionTitle),
        const SizedBox(height: 10),
        if (data.todaysMealGroups.isEmpty)
          _EmptyHint(l10n.noMealsLoggedYetPeriodMessage)
        else
          ...data.todaysMealGroups.map(
            (g) => _MealGroupTile(group: g, onTap: onMealsTap),
          ),
        const SizedBox(height: 24),

        // ── Recent workouts ───────────────────────────────────────────
        _SectionTitle(l10n.recentWorkoutsSectionTitle),
        const SizedBox(height: 10),
        if (data.recentWorkouts.isEmpty)
          _EmptyHint(l10n.noWorkoutsLoggedYetPeriodMessage)
        else
          ...data.recentWorkouts.take(3).map(
            (w) => _WorkoutTile(workout: w, onTap: () => onWorkoutTap(w.clientId)),
          ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Recent workout tile
// ---------------------------------------------------------------------------

class _WorkoutTile extends StatelessWidget {
  const _WorkoutTile({required this.workout, this.onTap});

  final RecentWorkout workout;
  final VoidCallback? onTap;

  String _statsLine(AppLocalizations l10n) {
    final parts = <String>[];
    if (workout.finishedAt != null) {
      final mins = workout.finishedAt!.difference(workout.startedAt).inMinutes;
      if (mins > 0) parts.add(l10n.workoutDurationMin(mins));
    }
    final exCount = workout.exerciseNames.length;
    if (exCount > 0) parts.add(l10n.workoutExerciseCount(exCount));
    if (workout.activeCalories != null) {
      parts.add(l10n.workoutKcal(workout.activeCalories!.round()));
    }
    return parts.join(' · ');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    final dateLabel = DateFormat('MMM d, HH:mm').format(workout.startedAt.toLocal());
    final exercises = workout.exerciseNames.isEmpty ? '—' : workout.exerciseNames.join(', ');
    final statsLine = _statsLine(l10n);

    return Card(
      elevation: 0,
      color: theme.colorScheme.surfaceContainerHigh,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.card),
      ),
      margin: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.card),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              // Rounded icon box
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: theme.colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Center(
                  child: Icon(
                    Icons.fitness_center,
                    size: 22,
                    color: theme.colorScheme.onPrimaryContainer,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      dateLabel,
                      style: theme.textTheme.bodyLarge,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      exercises,
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (statsLine.isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Text(
                        statsLine,
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.75),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              if (workout.inProgress)
                _StatusChip(
                  label: l10n.inProgressLabel,
                  color: theme.colorScheme.tertiary,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Today's meal group tile
// ---------------------------------------------------------------------------

class _MealGroupTile extends StatelessWidget {
  const _MealGroupTile({required this.group, this.onTap});

  final TodayMealGroup group;
  final VoidCallback? onTap;

  IconData _icon() => switch (group.type) {
        MealType.breakfast => Icons.free_breakfast,
        MealType.lunch => Icons.lunch_dining,
        MealType.dinner => Icons.dinner_dining,
        MealType.snack => Icons.cookie,
      };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    final foods = group.meals
        .expand((m) => m.entries)
        .map((e) => e.foodName)
        .take(3)
        .join(', ');

    return Card(
      elevation: 0,
      color: theme.colorScheme.surfaceContainerHigh,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.card),
      ),
      margin: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.card),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: theme.colorScheme.secondaryContainer,
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Center(
                  child: Icon(
                    _icon(),
                    size: 22,
                    color: theme.colorScheme.onSecondaryContainer,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      group.type.label(l10n),
                      style: theme.textTheme.bodyLarge,
                    ),
                    if (foods.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        foods,
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '${group.totalCalories.toStringAsFixed(0)} kcal',
                style: theme.textTheme.labelMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(width: 4),
              Icon(
                Icons.chevron_right,
                size: 20,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(99),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontFamily: 'PlusJakartaSans',
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: color,
          height: 1.0,
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Section title — small all-caps label
// ---------------------------------------------------------------------------

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Text(
      text.toUpperCase(),
      style: theme.textTheme.labelSmall?.copyWith(
        color: theme.colorScheme.onSurfaceVariant,
        letterSpacing: 1.2,
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Day greeting — time-of-day label shown at the top of the content area
// ---------------------------------------------------------------------------

class _DayGreeting extends StatelessWidget {
  const _DayGreeting({required this.l10n});

  final AppLocalizations l10n;

  String _greeting() {
    final hour = DateTime.now().hour;
    if (hour >= 5 && hour < 12) return l10n.greetingMorning;
    if (hour >= 12 && hour < 18) return l10n.greetingAfternoon;
    return l10n.greetingEvening;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Text(
      _greeting(),
      style: theme.textTheme.headlineSmall?.copyWith(
        fontWeight: FontWeight.w800,
        letterSpacing: -0.5,
        color: theme.colorScheme.onSurface,
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Steps card — shows today's steps with optional goal progress
// ---------------------------------------------------------------------------

class _StepsCard extends StatelessWidget {
  const _StepsCard({required this.steps, this.goal});

  final int steps;
  final int? goal;

  @override
  Widget build(BuildContext context) {
    final mc = context.metricColors;
    final l10n = AppLocalizations.of(context)!;
    final fmt = NumberFormat.decimalPattern();
    final ratio = (goal == null || goal! <= 0) ? null : steps / goal!;
    final goalReached = ratio != null && ratio >= 1.0;
    final subtitle = goal == null ? null : '/ ${fmt.format(goal)}';

    return StatCard(
      label: l10n.todaysStepsLabel,
      value: fmt.format(steps),
      icon: Icons.directions_walk,
      color: mc.steps,
      ratio: ratio,
      goalReached: goalReached,
      goalTone: GoalTone.positive,
      subtitle: subtitle,
    );
  }
}

// ---------------------------------------------------------------------------
// Weight delta badge — colored arrow + diff shown next to weight value
// ---------------------------------------------------------------------------

class _WeightDeltaBadge extends StatelessWidget {
  const _WeightDeltaBadge({required this.delta});

  final WeightDelta delta;

  @override
  Widget build(BuildContext context) {
    final mc = context.metricColors;
    final isDown = delta.trend == WeightTrend.down;
    final color = isDown ? mc.positive : mc.negative;
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Icon(
          isDown ? Icons.arrow_downward : Icons.arrow_upward,
          size: 13,
          color: color,
        ),
        Text(
          delta.diff.toStringAsFixed(1),
          style: TextStyle(
            fontFamily: 'PlusJakartaSans',
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: color,
            height: 1.0,
          ),
        ),
      ],
    );
  }
}

class _EmptyHint extends StatelessWidget {
  const _EmptyHint(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Text(
        text,
        style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
      ),
    );
  }
}
