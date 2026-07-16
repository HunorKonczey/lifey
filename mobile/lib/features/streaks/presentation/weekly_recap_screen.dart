import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_tokens.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/widgets/adaptive_app_bar.dart';
import '../../../shared/widgets/nav_collapse_controller.dart';
import '../application/weekly_recap_provider.dart';
import '../data/recap_preferences.dart';
import '../domain/streak.dart';
import '../domain/weekly_recap.dart';

final _rangeFmt = DateFormat('MMM d');

/// "Your week in review" — workouts, nutrition, weight trend and goal
/// consistency for a Monday–Sunday week, paged backwards from the most
/// recently *completed* week (the current week isn't over yet, so it's
/// never the default or reachable via "next").
class WeeklyRecapScreen extends ConsumerStatefulWidget {
  const WeeklyRecapScreen({super.key});

  @override
  ConsumerState<WeeklyRecapScreen> createState() => _WeeklyRecapScreenState();
}

class _WeeklyRecapScreenState extends ConsumerState<WeeklyRecapScreen> {
  late final DateTime _latestWeekStart;
  late DateTime _weekStart;

  @override
  void initState() {
    super.initState();
    _latestWeekStart = WeeklyRecap.lastCompletedWeekStart();
    _weekStart = _latestWeekStart;
    // Opening the recap — from any entry point (the dashboard's streak chip
    // row or its recap-ready card) — suppresses that card for this week,
    // regardless of which week the user later pages to from here.
    unawaited(ref.read(recapPreferencesProvider).markRecapSeen(_latestWeekStart));
  }

  void _goToPreviousWeek() {
    setState(() => _weekStart = _weekStart.subtract(const Duration(days: 7)));
  }

  void _goToNextWeek() {
    if (_weekStart == _latestWeekStart) return;
    setState(() => _weekStart = _weekStart.add(const Duration(days: 7)));
  }

  @override
  Widget build(BuildContext context) {
    final recap = ref.watch(weeklyRecapProvider(_weekStart));
    final l10n = AppLocalizations.of(context)!;

    final statusTop = MediaQuery.paddingOf(context).top;
    final barTop = statusTop + 8.0;
    final contentTop = barTop + 58.0 + 12.0;
    final bottomPad = MediaQuery.paddingOf(context).bottom + 16;

    return Scaffold(
      body: ScrollCollapseListener(
        child: Stack(
          children: [
            Positioned.fill(
              child: ListView(
                padding: EdgeInsets.fromLTRB(16, contentTop, 16, bottomPad),
                children: [
                  _WeekHeader(
                    weekStart: _weekStart,
                    canGoForward: _weekStart != _latestWeekStart,
                    onPrevious: _goToPreviousWeek,
                    onNext: _goToNextWeek,
                  ),
                  const SizedBox(height: 16),
                  _WorkoutsSection(recap: recap),
                  const SizedBox(height: 16),
                  _NutritionSection(recap: recap),
                  if (recap.weightStart != null || recap.weightEnd != null) ...[
                    const SizedBox(height: 16),
                    _WeightSection(recap: recap),
                  ],
                  if (recap.calorieGoalSet || recap.stepGoalSet || recap.waterGoalSet) ...[
                    const SizedBox(height: 16),
                    _GoalsSection(recap: recap),
                  ],
                ],
              ),
            ),
            Positioned(
              top: barTop,
              left: 12,
              right: 12,
              child: AdaptiveAppBar(
                title: l10n.recapScreenTitle,
                onBack: () => Navigator.of(context).pop(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Week header — date range + paging chevrons
// ---------------------------------------------------------------------------

class _WeekHeader extends StatelessWidget {
  const _WeekHeader({
    required this.weekStart,
    required this.canGoForward,
    required this.onPrevious,
    required this.onNext,
  });

  final DateTime weekStart;
  final bool canGoForward;
  final VoidCallback onPrevious;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    final weekEnd = weekStart.add(const Duration(days: 6));
    final rangeLabel = '${_rangeFmt.format(weekStart)} – ${_rangeFmt.format(weekEnd)}';

    return Row(
      children: [
        IconButton(
          onPressed: onPrevious,
          icon: const Icon(Icons.chevron_left),
          tooltip: l10n.recapPreviousWeekTooltip,
        ),
        Expanded(
          child: Text(
            rangeLabel,
            textAlign: TextAlign.center,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
              color: theme.colorScheme.onSurface,
            ),
          ),
        ),
        IconButton(
          onPressed: canGoForward ? onNext : null,
          icon: const Icon(Icons.chevron_right),
          tooltip: l10n.recapNextWeekTooltip,
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Shared card shell
// ---------------------------------------------------------------------------

class _RecapCard extends StatelessWidget {
  const _RecapCard({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      elevation: 0,
      color: theme.colorScheme.surfaceContainerHigh,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.card)),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              title.toUpperCase(),
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                letterSpacing: 1.2,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 10),
            child,
          ],
        ),
      ),
    );
  }
}

class _EmptyHint extends StatelessWidget {
  const _EmptyHint(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
    );
  }
}

// ---------------------------------------------------------------------------
// Workouts section — count + total minutes + per-day dot strip
// ---------------------------------------------------------------------------

class _WorkoutsSection extends StatelessWidget {
  const _WorkoutsSection({required this.recap});

  final WeeklyRecap recap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;

    return _RecapCard(
      title: l10n.recapWorkoutsSectionTitle,
      child: recap.workoutsDone == 0
          ? _EmptyHint(l10n.recapNoWorkoutsMessage)
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(
                      l10n.recapWorkoutsCount(recap.workoutsDone),
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                    if (recap.workoutMinutes > 0) ...[
                      const SizedBox(width: 8),
                      Text(
                        l10n.recapWorkoutsMinutes(recap.workoutMinutes),
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 10),
                _DotStrip(filled: recap.workoutDays, color: theme.colorScheme.primary),
              ],
            ),
    );
  }
}

/// Seven small dots, Monday first — filled where [filled] is true.
class _DotStrip extends StatelessWidget {
  const _DotStrip({required this.filled, required this.color});

  final List<bool> filled;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final mutedColor = Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.2);
    return Row(
      children: [
        for (var i = 0; i < filled.length; i++) ...[
          if (i > 0) const SizedBox(width: 6),
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: filled[i] ? color : mutedColor,
            ),
          ),
        ],
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Nutrition section — avg calories over logged days + mini bar chart
// ---------------------------------------------------------------------------

class _NutritionSection extends StatelessWidget {
  const _NutritionSection({required this.recap});

  final WeeklyRecap recap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    final mc = context.metricColors;

    if (recap.loggedDayCount == 0) {
      return _RecapCard(
        title: l10n.recapNutritionSectionTitle,
        child: _EmptyHint(l10n.recapNoNutritionMessage),
      );
    }

    return _RecapCard(
      title: l10n.recapNutritionSectionTitle,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                l10n.recapAvgCaloriesLabel,
                style: theme.textTheme.labelMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              if (recap.calorieGoalSet) ...[
                const Spacer(),
                Text(
                  l10n.recapDaysWithinGoal(recap.caloriesDaysMet),
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 6),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                recap.avgCalories!.round().toString(),
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: theme.colorScheme.onSurface,
                ),
              ),
              const SizedBox(width: 4),
              Text(
                'kcal',
                style: theme.textTheme.labelMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
          Text(
            l10n.recapLoggedDaysCaption(recap.loggedDayCount),
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
            ),
          ),
          const SizedBox(height: 12),
          _DailyCaloriesBars(values: recap.dailyCalories, color: mc.calories),
        ],
      ),
    );
  }
}

/// Seven bars, Monday first — height proportional to that day's calories,
/// scaled against the week's own max so a light week still reads clearly.
/// An unlogged day (null) renders as a flat muted stub, not a missing bar.
class _DailyCaloriesBars extends StatelessWidget {
  const _DailyCaloriesBars({required this.values, required this.color});

  final List<double?> values;
  final Color color;

  static const _maxHeight = 56.0;
  static const _minHeight = 4.0;

  @override
  Widget build(BuildContext context) {
    final mutedColor = Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.15);
    final maxValue = values.whereType<double>().fold<double>(0, (m, v) => v > m ? v : m);

    return SizedBox(
      height: _maxHeight,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (var i = 0; i < values.length; i++) ...[
            if (i > 0) const SizedBox(width: 5),
            Expanded(
              child: _Bar(
                fraction: (values[i] == null || maxValue == 0) ? null : values[i]! / maxValue,
                color: color,
                mutedColor: mutedColor,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _Bar extends StatelessWidget {
  const _Bar({required this.fraction, required this.color, required this.mutedColor});

  /// Null when the day had no meal logged — renders as the flat muted stub.
  final double? fraction;
  final Color color;
  final Color mutedColor;

  @override
  Widget build(BuildContext context) {
    final height = fraction == null
        ? _DailyCaloriesBars._minHeight
        : (fraction! * (_DailyCaloriesBars._maxHeight - _DailyCaloriesBars._minHeight)) +
            _DailyCaloriesBars._minHeight;
    return Container(
      height: height,
      decoration: BoxDecoration(
        color: fraction == null ? mutedColor : color,
        borderRadius: BorderRadius.circular(3),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Weight section — start → end with a delta badge
// ---------------------------------------------------------------------------

class _WeightSection extends StatelessWidget {
  const _WeightSection({required this.recap});

  final WeeklyRecap recap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;

    return _RecapCard(
      title: l10n.recapWeightSectionTitle,
      child: recap.weightEnd == null
          ? _EmptyHint(l10n.recapNoWeighInMessage)
          : Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                if (recap.weightStart != null) ...[
                  Text(
                    '${recap.weightStart!.toStringAsFixed(1)} kg',
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Icon(Icons.arrow_forward, size: 14, color: theme.colorScheme.onSurfaceVariant),
                  const SizedBox(width: 6),
                ],
                Text(
                  '${recap.weightEnd!.toStringAsFixed(1)} kg',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
                if (recap.weightDelta != null && recap.weightDelta != 0) ...[
                  const SizedBox(width: 8),
                  _WeightDeltaBadge(delta: recap.weightDelta!),
                ],
              ],
            ),
    );
  }
}

/// Positive [delta] means gained. Weight going down is framed as positive
/// (green) and up as a mild warning (orange) — same convention the
/// dashboard's own weight-delta badge uses.
class _WeightDeltaBadge extends StatelessWidget {
  const _WeightDeltaBadge({required this.delta});

  final double delta;

  @override
  Widget build(BuildContext context) {
    final mc = context.metricColors;
    final isDown = delta < 0;
    final color = isDown ? mc.positive : mc.negative;
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Icon(isDown ? Icons.arrow_downward : Icons.arrow_upward, size: 13, color: color),
        Text(
          delta.abs().toStringAsFixed(1),
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

// ---------------------------------------------------------------------------
// Goals & streaks section — per set goal: "N/7 days met" + streak caption
// ---------------------------------------------------------------------------

class _GoalsSection extends StatelessWidget {
  const _GoalsSection({required this.recap});

  final WeeklyRecap recap;

  Streak? _streakFor(StreakMetric metric) =>
      recap.streaks.where((s) => s.metric == metric).firstOrNull;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final mc = context.metricColors;

    final rows = <Widget>[
      if (recap.calorieGoalSet)
        _GoalRow(
          icon: Icons.local_fire_department,
          color: mc.calories,
          daysMetText: l10n.recapDaysWithinGoal(recap.caloriesDaysMet),
          streak: _streakFor(StreakMetric.calories),
        ),
      if (recap.stepGoalSet)
        _GoalRow(
          icon: Icons.directions_walk,
          color: mc.steps,
          daysMetText: l10n.recapDaysMet(recap.stepsDaysMet),
          streak: _streakFor(StreakMetric.steps),
        ),
      if (recap.waterGoalSet)
        _GoalRow(
          icon: Icons.water_drop,
          color: mc.water,
          daysMetText: l10n.recapDaysMet(recap.waterDaysMet),
          streak: _streakFor(StreakMetric.water),
        ),
    ];

    return _RecapCard(
      title: l10n.recapGoalsSectionTitle,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var i = 0; i < rows.length; i++) ...[
            if (i > 0) const SizedBox(height: 12),
            rows[i],
          ],
        ],
      ),
    );
  }
}

class _GoalRow extends StatelessWidget {
  const _GoalRow({
    required this.icon,
    required this.color,
    required this.daysMetText,
    required this.streak,
  });

  final IconData icon;
  final Color color;
  final String daysMetText;
  final Streak? streak;

  String _metricLabel(AppLocalizations l10n, StreakMetric metric) => switch (metric) {
        StreakMetric.calories => l10n.streakMetricCalories,
        StreakMetric.steps => l10n.streakMetricSteps,
        StreakMetric.water => l10n.streakMetricWater,
      };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    final currentStreak = streak;
    final streakText = currentStreak == null
        ? null
        : currentStreak.isActive
            ? l10n.streakActiveTooltip(currentStreak.current, _metricLabel(l10n, currentStreak.metric))
            : l10n.streakNotStartedTooltip(_metricLabel(l10n, currentStreak.metric));

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                daysMetText,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: theme.colorScheme.onSurface,
                ),
              ),
              if (streakText != null)
                Text(
                  streakText,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}
