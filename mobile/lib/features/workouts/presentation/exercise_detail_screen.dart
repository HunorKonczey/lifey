import 'package:drift/drift.dart' show OrderingTerm;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/local_db/app_database.dart';
import '../../../core/local_db/database_provider.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/widgets/adaptive_app_bar.dart';
import '../../../shared/widgets/charts/time_series_chart.dart';
import '../domain/exercise.dart';
import '../domain/exercise_enums.dart';
import 'widgets/add_exercise_sheet.dart';

// ---------------------------------------------------------------------------
// Provider
// ---------------------------------------------------------------------------

final _setsForExerciseProvider =
    StreamProvider.family<List<ExerciseSetRow>, String>((ref, exerciseClientId) {
  final db = ref.watch(appDatabaseProvider);
  return (db.select(db.exerciseSets)
        ..where((t) => t.exerciseClientId.equals(exerciseClientId))
        ..orderBy([(t) => OrderingTerm.desc(t.performedAt)]))
      .watch();
});

// ---------------------------------------------------------------------------
// Screen
// ---------------------------------------------------------------------------

class ExerciseDetailScreen extends ConsumerWidget {
  const ExerciseDetailScreen({super.key, required this.exercise});

  final Exercise exercise;

  void _openEdit(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => AddExerciseSheet(exercise: exercise),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final setsAsync = ref.watch(_setsForExerciseProvider(exercise.clientId));

    final statusTop = MediaQuery.paddingOf(context).top;
    final barTop = statusTop + 8.0;
    final contentTop = barTop + 58.0 + 12.0;

    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(
            child: setsAsync.when(
              data: (sets) => _DetailBody(
                exercise: exercise,
                sets: sets,
                l10n: l10n,
                contentTop: contentTop,
              ),
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text(e.toString())),
            ),
          ),
          Positioned(
            top: barTop,
            left: 12,
            right: 12,
            child: AdaptiveAppBar(
              title: exercise.name,
              onBack: () => Navigator.of(context).pop(),
              actions: [
                AdaptiveAppBarAction(
                  icon: Icons.edit_outlined,
                  tooltip: l10n.editMenuItem,
                  onPressed: () => _openEdit(context),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Body
// ---------------------------------------------------------------------------

class _DetailBody extends StatelessWidget {
  const _DetailBody({
    required this.exercise,
    required this.sets,
    required this.l10n,
    required this.contentTop,
  });

  final Exercise exercise;
  final List<ExerciseSetRow> sets;
  final AppLocalizations l10n;
  final double contentTop;

  /// Epley formula: weight × (1 + reps / 30)
  double _epley(double weight, int reps) => weight * (1 + reps / 30);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final mc = context.metricColors;

    // PR = set with the highest estimated 1RM
    ExerciseSetRow? prSet;
    double bestOneRM = 0;
    for (final s in sets) {
      final orm = _epley(s.weight, s.reps);
      if (orm > bestOneRM) {
        bestOneRM = orm;
        prSet = s;
      }
    }

    // 8-week trend: group by ISO week, take max 1RM per week
    final now = DateTime.now();
    final cutoff = now.subtract(const Duration(days: 56));
    final recentSets = sets.where((s) => s.performedAt.isAfter(cutoff)).toList();
    final weeklyBest = <String, double>{};
    for (final s in recentSets) {
      final weekKey = _isoWeekKey(s.performedAt);
      final orm = _epley(s.weight, s.reps);
      final current = weeklyBest[weekKey] ?? 0;
      weeklyBest[weekKey] = orm > current ? orm : current;
    }
    final trendPoints = weeklyBest.entries
        .map((e) => TimeSeriesPoint(date: _weekKeyDate(e.key), value: e.value))
        .toList()
      ..sort((a, b) => a.date.compareTo(b.date));

    // % change from oldest to newest data point
    String? trendPct;
    if (trendPoints.length >= 2) {
      final first = trendPoints.first.value;
      final last = trendPoints.last.value;
      final pct = (last - first) / first * 100;
      final sign = pct >= 0 ? '+' : '';
      trendPct = '$sign${pct.round()}%';
    }

    // Recent sets — take 10, group by calendar day
    final recentVisible = sets.take(10).toList();
    final todayDate = DateTime(now.year, now.month, now.day);
    final yesterdayDate = todayDate.subtract(const Duration(days: 1));

    final dayGroupKeys = <String>[];
    final dayGroupMap = <String, List<ExerciseSetRow>>{};
    for (final s in recentVisible) {
      final d = DateTime(s.performedAt.year, s.performedAt.month, s.performedAt.day);
      final key = '${d.year}-${d.month}-${d.day}';
      if (!dayGroupMap.containsKey(key)) {
        dayGroupKeys.add(key);
        dayGroupMap[key] = [];
      }
      dayGroupMap[key]!.add(s);
    }

    final shortDateFmt = DateFormat.MMMd();
    final weightFormat = NumberFormat('0.#');

    String _dayLabel(String key) {
      final parts = key.split('-');
      final d = DateTime(int.parse(parts[0]), int.parse(parts[1]), int.parse(parts[2]));
      if (d == todayDate) return l10n.weightHistoryTodayLabel;
      if (d == yesterdayDate) return l10n.weightHistoryYesterdayLabel;
      return DateFormat('EEE').format(d);
    }

    return ListView(
      padding: EdgeInsets.fromLTRB(
        16,
        contentTop,
        16,
        MediaQuery.paddingOf(context).bottom + 24,
      ),
      children: [
          // Category + equipment chips
          if (exercise.category != null || exercise.equipment != null) ...[
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                if (exercise.category != null)
                  _CategoryChip(
                    label: muscleGroupLabel(l10n, exercise.category!),
                    color: muscleGroupColor(exercise.category!, context),
                  ),
                if (exercise.equipment != null)
                  _EquipmentChip(label: equipmentLabel(l10n, exercise.equipment!)),
              ],
            ),
            const SizedBox(height: 20),
          ],

          // PR + 1RM stat row
          if (prSet != null) ...[
            Row(
              children: [
                Expanded(
                  child: _StatCard(
                    icon: Icons.emoji_events,
                    iconColor: mc.carbs,
                    label: l10n.personalRecordLabel,
                    valueWidget: RichText(
                      text: TextSpan(children: [
                        TextSpan(
                          text: weightFormat.format(prSet.weight),
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w800,
                            color: scheme.onSurface,
                            fontFamily: 'PlusJakartaSans',
                          ),
                        ),
                        TextSpan(
                          text: ' kg × ${prSet.reps}',
                          style: TextStyle(
                            fontSize: 13,
                            color: scheme.onSurfaceVariant,
                            fontFamily: 'PlusJakartaSans',
                          ),
                        ),
                      ]),
                    ),
                    subtitle: shortDateFmt.format(prSet.performedAt),
                  ),
                ),
                const SizedBox(width: 11),
                Expanded(
                  child: _StatCard(
                    icon: Icons.history,
                    iconColor: scheme.primary,
                    label: l10n.estimatedOneRepMaxLabel,
                    valueWidget: RichText(
                      text: TextSpan(children: [
                        TextSpan(
                          text: weightFormat.format(bestOneRM),
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w800,
                            color: scheme.primary,
                            fontFamily: 'PlusJakartaSans',
                          ),
                        ),
                        TextSpan(
                          text: ' kg',
                          style: TextStyle(
                            fontSize: 13,
                            color: scheme.onSurfaceVariant,
                            fontFamily: 'PlusJakartaSans',
                          ),
                        ),
                      ]),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
          ],

          // 8-week trend chart — title + pill + chart all inside one card
          if (trendPoints.isNotEmpty) ...[
            Container(
              decoration: BoxDecoration(
                color: scheme.surfaceContainerHigh,
                borderRadius: BorderRadius.circular(AppRadius.card),
              ),
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          l10n.trendLast8WeeksLabel,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                      if (trendPct != null)
                        _TrendPill(pct: trendPct, positive: !trendPct.startsWith('-')),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TimeSeriesChart(
                    points: trendPoints,
                    height: 130,
                    areaColor: scheme.primary.withValues(alpha: 0.12),
                    dateLabelBuilder: (d) => shortDateFmt.format(d),
                    valueLabelBuilder: (v) => l10n.weightKgValue(weightFormat.format(v)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
          ],

          // Recent sets grouped by day — one compact row per day
          Text(
            l10n.recentSetsLabel.toUpperCase(),
            style: theme.textTheme.labelSmall?.copyWith(
              color: scheme.onSurfaceVariant,
              letterSpacing: 0.8,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          if (recentVisible.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Text(
                  l10n.noSetsForExerciseMessage,
                  style: theme.textTheme.bodyMedium
                      ?.copyWith(color: scheme.onSurfaceVariant),
                ),
              ),
            )
          else
            for (final key in dayGroupKeys)
              _DaySetRow(
                dayLabel: _dayLabel(key),
                sets: dayGroupMap[key]!,
                weightFormat: weightFormat,
              ),
      ],
    );
  }

  String _isoWeekKey(DateTime dt) {
    // ISO week: Monday-based. Simple approximation: round to Monday.
    final monday = dt.subtract(Duration(days: dt.weekday - 1));
    return '${monday.year}-${monday.month.toString().padLeft(2, '0')}-${monday.day.toString().padLeft(2, '0')}';
  }

  DateTime _weekKeyDate(String key) {
    final parts = key.split('-');
    return DateTime(int.parse(parts[0]), int.parse(parts[1]), int.parse(parts[2]));
  }
}

// ---------------------------------------------------------------------------
// Widgets
// ---------------------------------------------------------------------------

/// Category chip — muscleColor 15 % opacity bg, muscleColor text + icon, pill shape.
class _CategoryChip extends StatelessWidget {
  const _CategoryChip({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 7),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: AppRadius.pill,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.accessibility_new, size: 16, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, height: 1.0)
                .copyWith(color: color),
          ),
        ],
      ),
    );
  }
}

/// Equipment chip — neutral surfaceContainerLow bg, onSurfaceVariant text + icon.
class _EquipmentChip extends StatelessWidget {
  const _EquipmentChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = scheme.onSurfaceVariant;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 7),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: AppRadius.pill,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.fitness_center, size: 16, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              height: 1.0,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.valueWidget,
    this.subtitle,
  });

  final IconData icon;
  final Color iconColor;
  final String label;
  final Widget valueWidget;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(AppRadius.card),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: iconColor),
              const SizedBox(width: 7),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    color: scheme.onSurfaceVariant,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 9),
          valueWidget,
          if (subtitle != null) ...[
            const SizedBox(height: 2),
            Text(
              subtitle!,
              style: const TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w600,
              ).copyWith(color: scheme.onSurfaceVariant),
            ),
          ],
        ],
      ),
    );
  }
}

class _TrendPill extends StatelessWidget {
  const _TrendPill({required this.pct, required this.positive});

  final String pct;
  final bool positive;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final bg = positive ? scheme.primary : scheme.error;
    final fg = positive ? scheme.onPrimary : scheme.onError;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: bg, borderRadius: AppRadius.pill),
      child: Text(
        pct,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: fg,
          height: 1.0,
        ),
      ),
    );
  }
}

class _DaySetRow extends StatelessWidget {
  const _DaySetRow({
    required this.dayLabel,
    required this.sets,
    required this.weightFormat,
  });

  final String dayLabel;
  final List<ExerciseSetRow> sets;
  final NumberFormat weightFormat;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    final summary = sets
        .map((s) => '${weightFormat.format(s.weight)}×${s.reps}')
        .join(' · ');

    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: scheme.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(AppRadius.card),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 68,
              child: Text(
                dayLabel,
                style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700)
                    .copyWith(color: scheme.onSurface),
              ),
            ),
            Expanded(
              child: Text(
                summary,
                textAlign: TextAlign.end,
                style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700)
                    .copyWith(color: scheme.onSurfaceVariant),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
