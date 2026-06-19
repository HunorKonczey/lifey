import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/sync/pull_engine.dart';
import '../../../core/sync/sync_engine_provider.dart';
import '../../auth/application/auth_controller.dart';
import '../../settings/application/settings_controller.dart';
import '../../settings/domain/user_settings.dart';
import '../../water/presentation/widgets/add_water_sheet.dart';
import '../../water/presentation/widgets/water_card.dart';
import '../../weight/application/weight_controller.dart';
import '../../weight/domain/weight_entry.dart';
import '../application/dashboard_controller.dart';
import '../domain/dashboard_data.dart';
import '../domain/recent_workout.dart';
import 'widgets/stat_card.dart';

Future<void> _openAddWaterSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => const AddWaterSheet(),
  );
}

enum WeightTrend { up, down }

/// Compares the two most recent entries (newest first). Null when there
/// aren't at least two entries, or the weight didn't change.
WeightTrend? _weightTrend(List<WeightEntry> entries) {
  if (entries.length < 2) return null;
  final diff = entries[0].weight - entries[1].weight;
  if (diff > 0) return WeightTrend.up;
  if (diff < 0) return WeightTrend.down;
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
    final weightTrend = _weightTrend(ref.watch(weightControllerProvider).value ?? const []);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard'),
        centerTitle: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            tooltip: 'Settings',
            onPressed: () => context.push('/settings'),
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Log out',
            onPressed: () => ref.read(authControllerProvider.notifier).logout(),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => _forceSync(ref),
        child: _DashboardBody(data: data, settings: settings, weightTrend: weightTrend),
      ),
    );
  }
}

class _DashboardBody extends StatelessWidget {
  const _DashboardBody({required this.data, required this.settings, this.weightTrend});

  final DashboardData data;
  final UserSettings settings;
  final WeightTrend? weightTrend;

  /// Actual-over-goal ratio, or null when no goal is set (no bar shown then).
  double? _ratio(double actual, int? goal) =>
      (goal == null || goal <= 0) ? null : actual / goal;

  @override
  Widget build(BuildContext context) {
    final stats = data.stats;
    final weight = stats.latestWeight;

    final calorieRatio = _ratio(stats.calories, settings.dailyCalorieGoal);
    final proteinRatio = _ratio(stats.protein, settings.dailyProteinGoal);
    final carbsRatio = _ratio(stats.carbs, settings.dailyCarbsGoal);
    final fatRatio = _ratio(stats.fat, settings.dailyFatGoal);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        WaterCard(
          currentLiters: stats.water,
          goalLiters: settings.dailyWaterGoalLiters,
          onAdd: () => _openAddWaterSheet(context),
        ),
        const SizedBox(height: 24),
        const _SectionTitle('Today'),
        const SizedBox(height: 8),
        StatCard(
          label: "Today's calories",
          value: stats.calories.toStringAsFixed(0),
          unit: 'kcal',
          icon: Icons.local_fire_department,
          color: Colors.deepOrange,
          ratio: calorieRatio,
          goalReached: (calorieRatio ?? 0) >= 1,
          goalTone: GoalTone.negative,
          onTap: () => context.go('/nutrition'),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: StatCard(
                label: 'Protein',
                value: stats.protein.toStringAsFixed(0),
                unit: 'g',
                icon: Icons.egg_alt,
                color: Colors.teal,
                ratio: proteinRatio,
                goalReached: (proteinRatio ?? 0) >= 1,
                goalTone: GoalTone.positive,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: StatCard(
                label: 'Carbs',
                value: stats.carbs.toStringAsFixed(0),
                unit: 'g',
                icon: Icons.bakery_dining,
                color: Colors.amber,
                ratio: carbsRatio,
                goalReached: (carbsRatio ?? 0) >= 1,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: StatCard(
                label: 'Fat',
                value: stats.fat.toStringAsFixed(0),
                unit: 'g',
                icon: Icons.water_drop,
                color: Colors.indigo,
                ratio: fatRatio,
                goalReached: (fatRatio ?? 0) >= 1,
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        const _SectionTitle('Current weight'),
        const SizedBox(height: 8),
        StatCard(
          label: 'Latest entry',
          value: weight != null ? weight.toStringAsFixed(1) : '—',
          unit: weight != null ? 'kg' : null,
          icon: Icons.monitor_weight,
          color: Colors.blueGrey,
          onTap: () => context.go('/weight'),
          trailing: weightTrend == null
              ? null
              : Icon(
                  weightTrend == WeightTrend.up ? Icons.arrow_upward : Icons.arrow_downward,
                  size: 18,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
        ),
        const SizedBox(height: 24),
        const _SectionTitle('Recent workouts'),
        const SizedBox(height: 8),
        if (data.recentWorkouts.isEmpty)
          const _EmptyHint('No workouts logged yet.')
        else
          ...data.recentWorkouts.map(
            (w) => _WorkoutTile(workout: w, onTap: () => context.go('/workouts')),
          ),
      ],
    );
  }
}

class _WorkoutTile extends StatelessWidget {
  const _WorkoutTile({required this.workout, this.onTap});

  final RecentWorkout workout;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dateLabel = DateFormat('MMM d, HH:mm').format(workout.startedAt.toLocal());
    final exercises = workout.exerciseNames.isEmpty
        ? '—'
        : workout.exerciseNames.join(', ');

    return Card(
      elevation: 0,
      color: theme.colorScheme.surfaceContainerHighest,
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        onTap: onTap,
        leading: CircleAvatar(
          backgroundColor: theme.colorScheme.primaryContainer,
          child: const Icon(Icons.fitness_center),
        ),
        title: Text(dateLabel),
        subtitle: Text(
          exercises,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: workout.inProgress
            ? Chip(
                label: const Text('In progress'),
                visualDensity: VisualDensity.compact,
                backgroundColor: theme.colorScheme.tertiaryContainer,
              )
            : Text('${workout.setCount} sets', style: theme.textTheme.labelLarge),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: Theme.of(context)
          .textTheme
          .titleMedium
          ?.copyWith(fontWeight: FontWeight.bold),
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
