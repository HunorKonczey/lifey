import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../shared/widgets/error_view.dart';
import '../application/dashboard_controller.dart';
import '../domain/dashboard_data.dart';
import '../domain/recent_workout.dart';
import 'widgets/stat_card.dart';

/// Dashboard: today's calories & macros, current weight, recent workouts.
/// Auto-refreshes when its tab is re-selected (see MainShell).
class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dashboard = ref.watch(dashboardControllerProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard'),
        centerTitle: false,
      ),
      body: RefreshIndicator(
        onRefresh: () => ref.read(dashboardControllerProvider.notifier).refresh(),
        child: dashboard.when(
          data: (data) => _DashboardBody(data: data),
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => ErrorView(
            error: error,
            onRetry: () => ref.read(dashboardControllerProvider.notifier).refresh(),
          ),
        ),
      ),
    );
  }
}

class _DashboardBody extends StatelessWidget {
  const _DashboardBody({required this.data});

  final DashboardData data;

  @override
  Widget build(BuildContext context) {
    final stats = data.stats;
    final weight = stats.latestWeight;
    final totalMacros = stats.protein + stats.carbs + stats.fat;
    double share(double grams) => totalMacros > 0 ? grams / totalMacros : 0;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const _SectionTitle('Today'),
        const SizedBox(height: 8),
        StatCard(
          label: "Today's calories",
          value: stats.calories.toStringAsFixed(0),
          unit: 'kcal',
          icon: Icons.local_fire_department,
          color: Colors.deepOrange,
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
                ratio: share(stats.protein),
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
                ratio: share(stats.carbs),
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
                ratio: share(stats.fat),
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
        ),
        const SizedBox(height: 24),
        const _SectionTitle('Recent workouts'),
        const SizedBox(height: 8),
        if (data.recentWorkouts.isEmpty)
          const _EmptyHint('No workouts logged yet.')
        else
          ...data.recentWorkouts.map((w) => _WorkoutTile(workout: w)),
      ],
    );
  }
}

class _WorkoutTile extends StatelessWidget {
  const _WorkoutTile({required this.workout});

  final RecentWorkout workout;

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
