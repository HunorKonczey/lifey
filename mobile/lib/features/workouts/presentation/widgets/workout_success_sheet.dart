import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/format/lifey_format.dart';
import '../../../../core/theme/app_tokens.dart';
import '../../../../core/theme/app_type.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../shared/widgets/ds/list_group.dart';
import '../../domain/personal_record.dart';
import 'exercise_session_card.dart';

// ---------------------------------------------------------------------------
// Progress computation — pure, no widget dependencies.
// ---------------------------------------------------------------------------

/// Per-exercise improvement on the workout-success sheet: chips (e.g.
/// "+2.5 kg", "+2 reps") and the numbers the sheet's row shows — the top
/// weight and the biggest single-set gain. Only exercises with at least one
/// positive gain are included.
class WorkoutImprovement {
  const WorkoutImprovement({
    required this.exerciseName,
    this.category,
    required this.chips,
    this.topWeight = 0,
    this.bestWeightGain = 0,
    this.topReps = 0,
    this.bestRepsGain = 0,
  });

  final String exerciseName;

  /// Muscle-group code (e.g. "CHEST"), null if uncategorized.
  final String? category;
  final List<String> chips;

  /// Heaviest done set of the exercise this session (kg).
  final double topWeight;

  /// Biggest gain of one done set's weight over the same set last time (kg);
  /// 0 when no set got heavier.
  final double bestWeightGain;

  /// Most reps in a done set this session.
  final int topReps;

  /// Biggest gain of one done set's reps over the same set last time; 0 when
  /// no set got more reps.
  final int bestRepsGain;
}

/// One personal record earned this session, with the number that set it and
/// how far it moved the old record (null when there was no earlier record to
/// compare against — the exercise's first logged sets).
class WorkoutRecordEntry {
  const WorkoutRecordEntry({
    required this.type,
    required this.weight,
    required this.reps,
    required this.value,
    this.delta,
  });

  final PrType type;

  /// Weight and reps of the set that earned it.
  final double weight;
  final int reps;

  /// The new record's number: kg for [PrType.maxWeight] and
  /// [PrType.estimatedOneRm], reps for [PrType.repsAtWeight].
  final double value;

  /// New minus old record, same unit as [value].
  final double? delta;
}

/// Per-exercise personal-record chips (e.g. "105 kg", "12 × 80 kg", "e1RM
/// 118 kg") earned this session — one chip per (row, [PrType]) pair, see
/// [SetRow.prTypes] (docs/38-personal-records-plan.md, M4) — and [entries],
/// the same records collapsed to the best one per kind for the sheet.
class WorkoutPrRow {
  const WorkoutPrRow({
    required this.exerciseName,
    this.category,
    required this.chips,
    this.entries = const [],
  });

  final String exerciseName;

  /// Muscle-group code (e.g. "CHEST"), null if uncategorized.
  final String? category;
  final List<String> chips;
  final List<WorkoutRecordEntry> entries;
}

class WorkoutProgressResult {
  const WorkoutProgressResult({
    required this.score,
    required this.improvements,
    required this.records,
  });

  /// Net count of green up-arrows minus red down-arrows across every done
  /// set's weight and reps comparisons (mirrors [ExerciseSetRowTile]'s
  /// arrow logic in exercise_session_card.dart).
  final int score;
  final List<WorkoutImprovement> improvements;

  /// Per-exercise personal records earned this session.
  final List<WorkoutPrRow> records;

  /// Total number of individual PR chips across every exercise.
  int get totalPrCount => records.fold(0, (sum, r) => sum + r.chips.length);

  /// The records the sheet lists, one per (exercise, kind) — what its title
  /// counts.
  int get recordEntryCount => records.fold(0, (sum, r) => sum + r.entries.length);

  /// Popup shows when the user improved in at least 2 metrics net, OR any
  /// personal record was earned — a PR is a success on its own, even in an
  /// otherwise flat workout (docs/38-personal-records-plan.md, M4).
  bool get isSuccess => score >= 2 || records.isNotEmpty;
}

/// The line under the sheet's title: what the session was.
class WorkoutSummary {
  const WorkoutSummary({this.title, this.duration, this.volume = 0});

  /// The template's name, when the session came from one.
  final String? title;
  final Duration? duration;

  /// Σ weight × reps of the done sets (kg).
  final double volume;
}

/// Σ weight × reps of the done sets of [blocks] (kg).
double computeWorkoutVolume(List<ExerciseBlock> blocks) {
  var volume = 0.0;
  for (final block in blocks) {
    for (final row in block.rows) {
      if (!row.isDone) continue;
      volume += (row.weight ?? 0) * (row.reps ?? 0);
    }
  }
  return volume;
}

/// Computes the workout-success trigger score and per-exercise improvement
/// chips from the session's blocks, comparing each done row positionally
/// against [ExerciseBlock.previousSets].
WorkoutProgressResult computeWorkoutProgress(
  List<ExerciseBlock> blocks,
  AppLocalizations l10n,
) {
  final weightFormat = NumberFormat('0.#', l10n.localeName);
  int score = 0;
  final improvements = <WorkoutImprovement>[];
  final records = <WorkoutPrRow>[];

  for (final block in blocks) {
    double weightGain = 0;
    int repsGain = 0;
    double bestWeightGain = 0;
    int bestRepsGain = 0;
    double topWeight = 0;
    int topReps = 0;
    for (var i = 0; i < block.rows.length; i++) {
      final row = block.rows[i];
      if (!row.isDone) continue;
      if (row.weight != null && row.weight! > topWeight) topWeight = row.weight!;
      if (row.reps != null && row.reps! > topReps) topReps = row.reps!;
      if (i >= block.previousSets.length) continue;
      final previous = block.previousSets[i];

      if (row.weight != null) {
        if (row.weight! > previous.weight) {
          score++;
          final gain = row.weight! - previous.weight;
          weightGain += gain;
          if (gain > bestWeightGain) bestWeightGain = gain;
        } else if (row.weight! < previous.weight) {
          score--;
        }
      }
      if (row.reps != null) {
        if (row.reps! > previous.reps) {
          score++;
          final gain = row.reps! - previous.reps;
          repsGain += gain;
          if (gain > bestRepsGain) bestRepsGain = gain;
        } else if (row.reps! < previous.reps) {
          score--;
        }
      }
    }

    final chips = <String>[];
    if (weightGain > 0) {
      chips.add('+${weightFormat.format(weightGain)} ${l10n.statUnitKg}');
    }
    if (repsGain > 0) {
      chips.add('+$repsGain ${l10n.workoutSuccessRepsAbbrev}');
    }
    if (chips.isNotEmpty) {
      improvements.add(
        WorkoutImprovement(
          exerciseName: block.exerciseName,
          category: block.exerciseCategory,
          chips: chips,
          topWeight: topWeight,
          bestWeightGain: bestWeightGain,
          topReps: topReps,
          bestRepsGain: bestRepsGain,
        ),
      );
    }

    final prChips = <String>[];
    // The best set per kind (per weight for reps records) — several sets of a
    // session can each beat the old record, the sheet shows where it ended.
    final best = <(PrType, double?), WorkoutRecordEntry>{};
    for (final row in block.rows) {
      final weight = row.weight;
      final reps = row.reps;
      if (!row.isDone ||
          row.prTypes.isEmpty ||
          weight == null ||
          reps == null) {
        continue;
      }
      for (final type in row.prTypes) {
        switch (type) {
          case PrType.maxWeight:
            prChips.add('${weightFormat.format(weight)} ${l10n.statUnitKg}');
          case PrType.repsAtWeight:
            prChips.add(
                '$reps × ${weightFormat.format(weight)} ${l10n.statUnitKg}');
          case PrType.estimatedOneRm:
            prChips.add(
                'e1RM ${weightFormat.format(estimateOneRepMax(weight, reps))} ${l10n.statUnitKg}');
        }
        final entry = _recordEntry(type, weight, reps, block.prBaseline);
        final key = (type, type == PrType.repsAtWeight ? weight : null);
        final current = best[key];
        if (current == null || entry.value > current.value) best[key] = entry;
      }
    }
    if (prChips.isNotEmpty) {
      final entries = best.values.toList()
        ..sort((a, b) {
          final byType = a.type.index.compareTo(b.type.index);
          return byType != 0 ? byType : b.weight.compareTo(a.weight);
        });
      records.add(WorkoutPrRow(
        exerciseName: block.exerciseName,
        category: block.exerciseCategory,
        chips: prChips,
        entries: entries,
      ));
    }
  }

  return WorkoutProgressResult(
      score: score, improvements: improvements, records: records);
}

WorkoutRecordEntry _recordEntry(
    PrType type, double weight, int reps, PrBaseline? baseline) {
  switch (type) {
    case PrType.maxWeight:
      final old = baseline?.maxWeight;
      return WorkoutRecordEntry(
        type: type,
        weight: weight,
        reps: reps,
        value: weight,
        delta: old == null ? null : weight - old,
      );
    case PrType.estimatedOneRm:
      final value = estimateOneRepMax(weight, reps);
      final old = baseline?.bestOneRm;
      return WorkoutRecordEntry(
        type: type,
        weight: weight,
        reps: reps,
        value: value,
        delta: old == null ? null : value - old,
      );
    case PrType.repsAtWeight:
      final old = baseline?.maxRepsByWeight[weight];
      return WorkoutRecordEntry(
        type: type,
        weight: weight,
        reps: reps,
        value: reps.toDouble(),
        delta: old == null ? null : (reps - old).toDouble(),
      );
  }
}

// ---------------------------------------------------------------------------
// WorkoutSuccessSheet
// ---------------------------------------------------------------------------

/// The celebration sheet shown when [WorkoutProgressResult.isSuccess]
/// (docs/redesign/77-mobile-redesign-plan.md R3.7; canvas Lifey 3 › 3.2 "PR
/// sheet"): a trophy in a halo, "2 new personal records", the session's
/// name · duration · volume, then one row per record — trophy in the record
/// colour, the exercise, the kind, the new value and how far it moved — and
/// the exercises that simply got better in the improvement colour. The
/// entrance plays once: the trophy pops, then the rows follow 60 ms apart;
/// under reduced motion everything is already in place.
class WorkoutSuccessSheet extends StatefulWidget {
  const WorkoutSuccessSheet({super.key, required this.result, this.summary});

  final WorkoutProgressResult result;
  final WorkoutSummary? summary;

  @override
  State<WorkoutSuccessSheet> createState() => _WorkoutSuccessSheetState();
}

class _WorkoutSuccessSheetState extends State<WorkoutSuccessSheet>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  bool _started = false;

  /// Improvement rows shown before "+N more".
  static const _maxImprovements = 5;

  /// Share of the entrance the trophy takes before the rows start.
  static const _heroShare = 0.3;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: AppMotion.celebration);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    if (AppMotion.of(context, AppMotion.celebration) == Duration.zero) {
      _controller.value = 1;
    } else {
      _controller.forward();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// 0..1 progress of the [index]-th row's entrance.
  double _rowProgress(int index) {
    final total = AppMotion.celebration.inMilliseconds;
    final start = _heroShare + AppMotion.staggered(index).inMilliseconds / total;
    final end = (start + 0.3).clamp(0.0, 1.0);
    if (start >= end) return _controller.value;
    return Interval(start, end, curve: AppMotion.enter).transform(_controller.value);
  }

  String? _summaryLine(BuildContext context, AppLocalizations l10n) {
    final summary = widget.summary;
    if (summary == null) return null;
    final parts = <String>[
      if (summary.title != null && summary.title!.trim().isNotEmpty) summary.title!.trim(),
      if (summary.duration != null && summary.duration!.inMinutes > 0)
        l10n.workoutDurationMin(summary.duration!.inMinutes),
      if (summary.volume > 0) l10n.workoutDoneVolume(LifeyFormat.of(context).integer(summary.volume)),
    ];
    return parts.isEmpty ? null : parts.join(' · ');
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final p = context.palette;
    final mc = context.metricColors;
    final t = Theme.of(context).textTheme;
    final result = widget.result;
    final entryCount = result.recordEntryCount;
    final hasRecords = entryCount > 0;
    final accent = hasRecords ? mc.record : mc.improvement;
    // An exercise that set a record already has its rows — "better than last
    // time" would only repeat it.
    final recordNames = {for (final r in result.records) r.exerciseName};
    final better = [for (final i in result.improvements) if (!recordNames.contains(i.exerciseName)) i];
    final improvements = better.take(_maxImprovements).toList();
    final remaining = better.length - improvements.length;
    final summaryLine = _summaryLine(context, l10n);
    final safeBottom = MediaQuery.paddingOf(context).bottom;

    _rowCounter = 0;
    final rows = <Widget>[
      for (final record in result.records)
        for (final entry in record.entries) _recordRow(context, l10n, record, entry),
      for (final improvement in improvements) _improvementRow(context, l10n, improvement),
    ];

    return Padding(
      padding: EdgeInsets.fromLTRB(AppSpacing.screen, 10, AppSpacing.screen, AppSpacing.s20 + safeBottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: p.text3.withValues(alpha: 0.6),
                borderRadius: AppRadius.pill,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.s16),
          Flexible(
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(child: _hero(accent, hasRecords)),
                  const SizedBox(height: AppSpacing.s20),
                  Semantics(
                    header: true,
                    child: Text(
                      hasRecords ? l10n.workoutDonePrTitle(entryCount) : l10n.workoutSuccessTitle,
                      textAlign: TextAlign.center,
                      style: t.headlineMedium!.copyWith(fontWeight: FontWeight.w800, height: 1.15, letterSpacing: -0.56, color: p.text),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.s8),
                  Text(
                    (hasRecords ? summaryLine : null) ?? l10n.workoutSuccessSubtitle(result.improvements.length),
                    textAlign: TextAlign.center,
                    style: t.bodyMedium!.copyWith(fontWeight: FontWeight.w600, height: 1.4, color: p.text2),
                  ),
                  if (rows.isNotEmpty) ...[
                    const SizedBox(height: AppSpacing.s20),
                    ListGroup(dividerInset: 70, children: rows),
                  ],
                  if (remaining > 0) ...[
                    const SizedBox(height: AppSpacing.s12),
                    Text(
                      l10n.workoutSuccessMoreCount(remaining),
                      textAlign: TextAlign.center,
                      style: t.bodyMedium!.copyWith(fontWeight: FontWeight.w700, color: p.text2),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.s16),
          SizedBox(
            height: 56,
            child: FilledButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(l10n.workoutSuccessContinueButton),
            ),
          ),
        ],
      ),
    );
  }

  /// The trophy: 96 dp rounded square in the record tint with a soft halo; it
  /// pops in during the first [_heroShare] of the entrance.
  Widget _hero(Color accent, bool hasRecords) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final t = const Interval(0, _heroShare, curve: Curves.easeOutBack).transform(_controller.value);
        return Opacity(
          opacity: t.clamp(0.0, 1.0),
          child: Transform.scale(scale: 0.6 + 0.4 * t, child: child),
        );
      },
      child: Container(
        width: 96,
        height: 96,
        margin: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: accent.withValues(alpha: Theme.of(context).brightness == Brightness.dark ? 0.16 : 0.12),
          borderRadius: AppRadius.heroAll,
          boxShadow: [BoxShadow(color: accent.withValues(alpha: 0.06), spreadRadius: 10)],
        ),
        child: Icon(
          hasRecords ? Icons.emoji_events_rounded : Icons.check_circle_rounded,
          size: 52,
          color: accent,
        ),
      ),
    );
  }

  Widget _animated(int index, Widget child) => AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          final t = _rowProgress(index);
          return Opacity(
            opacity: t,
            child: Transform.translate(offset: Offset(0, 12 * (1 - t)), child: child),
          );
        },
        child: child,
      );

  int _rowCounter = 0;

  Widget _row({
    required Color color,
    required IconData icon,
    required String title,
    required String subtitle,
    required String value,
    String? delta,
  }) {
    final p = context.palette;
    final mc = context.metricColors;
    final index = _rowCounter++;
    return _animated(
      index,
      ListRow(
        leading: ListIconHolder(icon: icon, color: color, size: 40),
        title: title,
        subtitle: subtitle,
        trailing: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 132),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerRight,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(value, style: AppType.number(20, color: p.text).copyWith(height: 1)),
                if (delta != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 3),
                    child: Text(
                      delta,
                      style: AppType.number(12, weight: FontWeight.w700, color: mc.improvement)
                          .copyWith(height: 1.4),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _recordRow(BuildContext context, AppLocalizations l10n, WorkoutPrRow record, WorkoutRecordEntry entry) {
    final weightFormat = NumberFormat('0.#', l10n.localeName);
    final kind = switch (entry.type) {
      PrType.maxWeight => l10n.workoutDonePrKindHeaviest,
      PrType.estimatedOneRm => l10n.workoutDonePrKindOneRm,
      PrType.repsAtWeight => l10n.workoutDonePrKindReps(weightFormat.format(entry.weight)),
    };
    final isReps = entry.type == PrType.repsAtWeight;
    final unit = isReps ? l10n.workoutSuccessRepsAbbrev : l10n.statUnitKg;
    final number = isReps ? entry.value.round().toString() : weightFormat.format(entry.value);
    final delta = entry.delta;
    return _row(
      color: context.metricColors.record,
      icon: Icons.emoji_events_rounded,
      title: record.exerciseName,
      subtitle: kind,
      value: '$number $unit',
      delta: delta == null || delta <= 0
          ? null
          : '+${isReps ? delta.round().toString() : weightFormat.format(double.parse(delta.toStringAsFixed(1)))} $unit',
    );
  }

  Widget _improvementRow(BuildContext context, AppLocalizations l10n, WorkoutImprovement improvement) {
    final weightFormat = NumberFormat('0.#', l10n.localeName);
    final byWeight = improvement.bestWeightGain > 0;
    final unit = byWeight ? l10n.statUnitKg : l10n.workoutSuccessRepsAbbrev;
    return _row(
      color: context.metricColors.improvement,
      icon: Icons.arrow_upward_rounded,
      title: improvement.exerciseName,
      subtitle: l10n.workoutDoneBetterThanLast,
      value: byWeight
          ? '${weightFormat.format(improvement.topWeight)} $unit'
          : '${improvement.topReps} $unit',
      delta: byWeight
          ? '+${weightFormat.format(double.parse(improvement.bestWeightGain.toStringAsFixed(1)))} $unit'
          : '+${improvement.bestRepsGain} $unit',
    );
  }
}

/// Shows [WorkoutSuccessSheet] if [result] is a success; no-op otherwise.
/// Awaits the sheet's dismissal so callers can navigate away afterward.
Future<void> showWorkoutSuccessSheet(
  BuildContext context,
  WorkoutProgressResult result, {
  WorkoutSummary? summary,
}) async {
  if (!result.isSuccess) return;
  final duration = AppMotion.of(context, AppMotion.sheet);
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    useRootNavigator: true,
    constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.88),
    sheetAnimationStyle: AnimationStyle(
      duration: duration,
      reverseDuration: duration,
      curve: AppMotion.enter,
      reverseCurve: AppMotion.exit,
    ),
    builder: (_) => WorkoutSuccessSheet(result: result, summary: summary),
  );
}
