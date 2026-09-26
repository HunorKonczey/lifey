import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/format/lifey_format.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/widgets/charts/bar_chart.dart';
import '../../../shared/widgets/ds/delta_chip.dart';
import '../../../shared/widgets/ds/lifey_card.dart';
import '../../../shared/widgets/ds/lifey_header.dart';
import '../../../shared/widgets/ds/list_group.dart';
import '../../../shared/widgets/ds/metric_value.dart';
import '../../../shared/widgets/ds/section_label.dart';
import '../application/weekly_recap_provider.dart';
import '../data/recap_preferences.dart';
import '../domain/streak.dart';
import '../domain/weekly_recap.dart';

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

    final bottomPad = MediaQuery.paddingOf(context).bottom + AppSpacing.s32;

    return Scaffold(
      appBar: LifeySubpageHeader(title: l10n.recapScreenTitle),
      body: ListView(
        padding: EdgeInsets.fromLTRB(AppSpacing.s20, AppSpacing.s8, AppSpacing.s20, bottomPad),
        children: [
          _WeekHeader(
            weekStart: _weekStart,
            canGoForward: _weekStart != _latestWeekStart,
            onPrevious: _goToPreviousWeek,
            onNext: _goToNextWeek,
          ),
          const SizedBox(height: AppSpacing.s16),
          _WorkoutsSection(recap: recap),
          const SizedBox(height: AppSpacing.s24),
          _NutritionSection(recap: recap),
          if (recap.weightStart != null || recap.weightEnd != null) ...[
            const SizedBox(height: AppSpacing.s24),
            _WeightSection(recap: recap),
          ],
          if (recap.calorieGoalSet || recap.stepGoalSet || recap.waterGoalSet) ...[
            const SizedBox(height: AppSpacing.s24),
            _GoalsSection(recap: recap),
          ],
        ],
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
    final t = Theme.of(context).textTheme;
    final l10n = AppLocalizations.of(context)!;
    final f = LifeyFormat.of(context);
    final weekEnd = weekStart.add(const Duration(days: 6));
    final rangeLabel = '${f.shortDate(weekStart)} – ${f.shortDate(weekEnd)}';

    return Row(
      children: [
        HeaderIconButton(
          icon: Icons.chevron_left_rounded,
          onPressed: onPrevious,
          tooltip: l10n.recapPreviousWeekTooltip,
        ),
        Expanded(
          child: Text(
            rangeLabel,
            textAlign: TextAlign.center,
            style: t.titleLarge!.copyWith(fontWeight: FontWeight.w800, color: context.palette.text),
          ),
        ),
        HeaderIconButton(
          icon: Icons.chevron_right_rounded,
          onPressed: canGoForward ? onNext : null,
          tooltip: l10n.recapNextWeekTooltip,
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Shared card shell
// ---------------------------------------------------------------------------

/// The caps section label over one card — the same pattern as the
/// dashboard's sections.
class _RecapCard extends StatelessWidget {
  const _RecapCard({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionLabel(title),
        const SizedBox(height: AppSpacing.s8),
        LifeyCard(child: child),
      ],
    );
  }
}

class _EmptyHint extends StatelessWidget {
  const _EmptyHint(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(text, style: Theme.of(context).textTheme.bodyMedium!.copyWith(color: context.palette.text2));
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
    final t = Theme.of(context).textTheme;
    final p = context.palette;
    final l10n = AppLocalizations.of(context)!;
    final f = LifeyFormat.of(context);
    final meta = t.labelMedium!.copyWith(color: p.text2);

    return _RecapCard(
      title: l10n.recapWorkoutsSectionTitle,
      child: recap.workoutsDone == 0
          ? _EmptyHint(l10n.recapNoWorkoutsMessage)
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  crossAxisAlignment: WrapCrossAlignment.end,
                  spacing: AppSpacing.s12,
                  runSpacing: AppSpacing.s4,
                  children: [
                    Text(
                      l10n.recapWorkoutsCount(recap.workoutsDone),
                      style: t.titleLarge!.copyWith(fontWeight: FontWeight.w800, color: p.text),
                    ),
                    if (recap.workoutMinutes > 0) Text(l10n.recapWorkoutsMinutes(recap.workoutMinutes), style: meta),
                    // Only when there was cardio this week (D-C3.5's
                    // "missing, not zero" — weeklyCardioDistanceMeters is
                    // null, not 0, on a cardio-free week).
                    if (recap.weeklyCardioDistanceMeters != null)
                      Text(
                        l10n.recapWorkoutsDistance(f.decimal(recap.weeklyCardioDistanceMeters! / 1000.0, 1)),
                        style: meta,
                      ),
                  ],
                ),
                const SizedBox(height: AppSpacing.s12),
                _DotStrip(filled: recap.workoutDays, color: Theme.of(context).colorScheme.primary),
              ],
            ),
    );
  }
}

/// Seven dots, Monday first — filled where [filled] is true — each with its
/// weekday letter underneath.
class _DotStrip extends StatelessWidget {
  const _DotStrip({required this.filled, required this.color});

  final List<bool> filled;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final f = LifeyFormat.of(context);
    // Any Monday gives the same seven letters.
    final monday = WeeklyRecap.lastCompletedWeekStart();
    final label = Theme.of(context).textTheme.labelSmall!.copyWith(height: 1, color: p.text3);
    return Row(
      children: [
        for (var i = 0; i < filled.length; i++)
          Expanded(
            child: Column(
              children: [
                Container(
                  width: 14,
                  height: 14,
                  decoration: BoxDecoration(shape: BoxShape.circle, color: filled[i] ? color : p.control),
                ),
                const SizedBox(height: 6),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(f.weekdayNarrow(monday.add(Duration(days: i))), style: label),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Nutrition section — avg calories over logged days + bar chart
// ---------------------------------------------------------------------------

class _NutritionSection extends StatelessWidget {
  const _NutritionSection({required this.recap});

  final WeeklyRecap recap;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final p = context.palette;
    final l10n = AppLocalizations.of(context)!;
    final f = LifeyFormat.of(context);
    final mc = context.metricColors;

    if (recap.loggedDayCount == 0) {
      return _RecapCard(
        title: l10n.recapNutritionSectionTitle,
        child: _EmptyHint(l10n.recapNoNutritionMessage),
      );
    }

    // Any Monday gives the same seven letters.
    final monday = WeeklyRecap.lastCompletedWeekStart();

    return _RecapCard(
      title: l10n.recapNutritionSectionTitle,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            spacing: AppSpacing.s8,
            children: [
              Text(l10n.recapAvgCaloriesLabel, style: t.labelMedium!.copyWith(color: p.text2)),
              if (recap.calorieGoalSet)
                Text(l10n.recapDaysWithinGoal(recap.caloriesDaysMet), style: t.labelSmall!.copyWith(color: p.text2)),
            ],
          ),
          const SizedBox(height: AppSpacing.s8),
          Align(
            alignment: Alignment.centerLeft,
            child: MetricValue(value: f.kcal(recap.avgCalories!), unit: 'kcal', size: 28),
          ),
          const SizedBox(height: AppSpacing.s4),
          Text(l10n.recapLoggedDaysCaption(recap.loggedDayCount), style: t.labelSmall!.copyWith(color: p.text3)),
          const SizedBox(height: AppSpacing.s16),
          // An unlogged day is an empty column, not a zero.
          LifeyBarChart(
            height: 80,
            color: mc.calories,
            bars: [
              for (var i = 0; i < recap.dailyCalories.length; i++)
                BarDatum(
                  label: f.weekdayNarrow(monday.add(Duration(days: i))),
                  value: recap.dailyCalories[i],
                  highlighted: true,
                ),
            ],
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Weight section — start → end with a delta chip
// ---------------------------------------------------------------------------

class _WeightSection extends StatelessWidget {
  const _WeightSection({required this.recap});

  final WeeklyRecap recap;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final p = context.palette;
    final l10n = AppLocalizations.of(context)!;
    final f = LifeyFormat.of(context);

    return _RecapCard(
      title: l10n.recapWeightSectionTitle,
      child: recap.weightEnd == null
          ? _EmptyHint(l10n.recapNoWeighInMessage)
          : Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: AppSpacing.s8,
              runSpacing: AppSpacing.s8,
              children: [
                if (recap.weightStart != null) ...[
                  Text('${f.weight(recap.weightStart!)} kg', style: t.bodyLarge!.copyWith(color: p.text2)),
                  Icon(Icons.arrow_forward_rounded, size: 16, color: p.text3),
                ],
                MetricValue(value: f.weight(recap.weightEnd!), unit: 'kg', size: 28),
                // Direction colour, not good/bad: whether a change is good
                // depends on the user's goal (same rule as the dashboard tile).
                if (recap.weightDelta != null && recap.weightDelta != 0)
                  DeltaChip.arrow(value: recap.weightDelta!, unit: 'kg'),
              ],
            ),
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
          icon: Icons.local_fire_department_rounded,
          color: mc.calories,
          daysMetText: l10n.recapDaysWithinGoal(recap.caloriesDaysMet),
          streak: _streakFor(StreakMetric.calories),
        ),
      if (recap.stepGoalSet)
        _GoalRow(
          icon: Icons.directions_walk_rounded,
          color: mc.steps,
          daysMetText: l10n.recapDaysMet(recap.stepsDaysMet),
          streak: _streakFor(StreakMetric.steps),
        ),
      if (recap.waterGoalSet)
        _GoalRow(
          icon: Icons.water_drop_rounded,
          color: mc.water,
          daysMetText: l10n.recapDaysMet(recap.waterDaysMet),
          streak: _streakFor(StreakMetric.water),
        ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionLabel(l10n.recapGoalsSectionTitle),
        const SizedBox(height: AppSpacing.s8),
        // One card, a row per goal — not a card of loose rows.
        ListGroup(children: rows),
      ],
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
        // Never actually reached today — this section only renders a row
        // per *goal* (calorieGoalSet/stepGoalSet/waterGoalSet), and the
        // workout streak isn't a goal (Q1: "Nem beállítás"), so no
        // `_GoalRow` is ever built for it here. Still required for
        // exhaustiveness — `StreakMetric` grew a fourth value.
        StreakMetric.workout => l10n.streakMetricWorkout,
      };

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final currentStreak = streak;
    final streakText = currentStreak == null
        ? null
        : currentStreak.isActive
            ? l10n.streakActiveTooltip(currentStreak.current, _metricLabel(l10n, currentStreak.metric))
            : l10n.streakNotStartedTooltip(_metricLabel(l10n, currentStreak.metric));

    return ListRow(
      leading: ListIconHolder(icon: icon, color: color),
      title: daysMetText,
      subtitle: streakText,
    );
  }
}
