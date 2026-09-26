import 'package:flutter/material.dart';

import '../../../../core/format/cardio_formatter.dart';
import '../../../../core/format/lifey_format.dart';
import '../../../../core/theme/app_tokens.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../shared/widgets/ds/list_group.dart';
import '../../../../shared/widgets/ds/section_label.dart';
import '../../../../shared/widgets/ds/tinted_chip.dart';
import '../../../settings/domain/user_settings.dart';
import '../../../workouts/domain/activity_type.dart';
import '../../domain/recent_workout.dart';

/// "RECENT WORKOUTS · See all" — the last few sessions in one card (docs/
/// redesign/77-mobile-redesign-plan.md R1.6; canvas Lifey 1 scrolled).
///
/// - **Strength:** the template name (else "Strength") over "Wed 17:30 · 34 min
///   · 2 exercises", brand-olive dumbbell holder. A "★ Rate" chip opens the
///   feedback sheet directly when the rating nudge applies
///   ([RecentWorkout.needsRatingNudge]); an unfinished one says "In progress".
/// - **Cardio:** the activity name over "Tue 07:45 · 5.21 km · 28 min", the
///   activity's own icon and colour (running = calorie orange), kcal at the
///   right when known.
class RecentWorkoutsSection extends StatelessWidget {
  const RecentWorkoutsSection({
    super.key,
    required this.workouts,
    required this.unitSystem,
    required this.onSeeAll,
    required this.onTap,
    required this.onRate,
  });

  /// Newest first; the section shows the first three.
  final List<RecentWorkout> workouts;
  final UnitSystem unitSystem;
  final VoidCallback onSeeAll;
  final ValueChanged<String> onTap;
  final ValueChanged<String> onRate;

  static const int visibleCount = 3;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final p = context.palette;
    final shown = workouts.take(visibleCount).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionLabel(l10n.recentWorkoutsSectionTitle, actionLabel: l10n.dashboardSeeAll, onAction: onSeeAll),
        if (shown.isEmpty)
          ListGroup(
            dividerInset: AppSpacing.s16,
            children: [
              Padding(
                padding: const EdgeInsets.all(AppSpacing.s16),
                child: Text(
                  l10n.noWorkoutsLoggedYetPeriodMessage,
                  style: Theme.of(context).textTheme.bodyMedium!.copyWith(color: p.text2),
                ),
              ),
            ],
          )
        else
          ListGroup(children: [for (final w in shown) _row(context, l10n, w)]),
      ],
    );
  }

  Widget _row(BuildContext context, AppLocalizations l10n, RecentWorkout w) {
    final f = LifeyFormat.of(context);
    final scheme = Theme.of(context).colorScheme;
    final started = w.startedAt.toLocal();

    final duration = _durationMinutes(w);
    final parts = <String>[
      f.weekdayTime(started),
      if (w.isCardio && (w.distanceMeters ?? 0) > 0) _distance(f, w.distanceMeters!),
      if (duration != null) l10n.workoutDurationMin(duration),
      if (!w.isCardio && w.exerciseNames.isNotEmpty) l10n.workoutExerciseCount(w.exerciseNames.length),
    ];

    final IconData icon;
    final Color color;
    final String title;
    if (w.isCardio) {
      icon = activityTypeIcon(w.activityType!);
      color = activityTypeColor(w.activityType!, context);
      title = activityTypeLabel(l10n, w.activityType!);
    } else {
      icon = Icons.fitness_center_rounded;
      color = scheme.primary;
      final name = w.templateName?.trim();
      title = (name != null && name.isNotEmpty) ? name : l10n.activityTypeStrength;
    }

    final Widget? trailing;
    if (w.inProgress) {
      trailing = TintedChip(label: l10n.inProgressLabel, color: scheme.primary);
    } else if (w.needsRatingNudge) {
      trailing = _RateChip(label: l10n.dashboardRateChip, onTap: () => onRate(w.clientId));
    } else if (w.activeCalories != null && w.activeCalories! > 0) {
      trailing = ListRowValue(value: f.kcal(w.activeCalories!), unit: 'kcal');
    } else {
      trailing = null;
    }
    return ListRow(
      leading: ListIconHolder(icon: icon, color: color),
      title: title,
      subtitle: _joinMeta(parts),
      trailing: trailing,
      onTap: () => onTap(w.clientId),
    );
  }

  /// "Wed 17:30 · 34 min · 2 exercises" — a wrapped line breaks only at the
  /// dots: every part keeps its number and unit together ("34 perc") and the
  /// separator stays with the part before it, so no line starts with a "·".
  static String _joinMeta(List<String> parts) =>
      parts.map((p) => p.replaceAll(' ', ' ')).join(' · ');

  /// Cardio: moving time (elapsed time includes pauses); strength: start →
  /// finish. Under a minute shows nothing.
  int? _durationMinutes(RecentWorkout w) {
    final seconds = w.isCardio && w.movingSeconds != null
        ? w.movingSeconds!
        : w.finishedAt?.difference(w.startedAt).inSeconds;
    if (seconds == null) return null;
    final minutes = (seconds / 60).round();
    return minutes > 0 ? minutes : null;
  }

  String _distance(LifeyFormat f, double meters) => unitSystem == UnitSystem.imperial
      ? CardioFormatter.distance(meters, unitSystem)
      : '${f.distance(meters / 1000)} km';
}

/// The "★ Rate" chip: 36 px pill on surface-2 with the star in the record
/// (gold) colour, inside a 48 dp touch box.
class _RateChip extends StatelessWidget {
  const _RateChip({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 48),
      child: Center(
        widthFactor: 1,
        child: Material(
          color: p.nested,
          borderRadius: AppRadius.controlAll,
          child: InkWell(
            onTap: onTap,
            borderRadius: AppRadius.controlAll,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 36),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.star_rounded, size: 16, color: context.metricColors.record),
                    const SizedBox(width: AppSpacing.s4),
                    Text(
                      label,
                      style: Theme.of(context).textTheme.bodySmall!.copyWith(fontWeight: FontWeight.w700, color: p.text),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
