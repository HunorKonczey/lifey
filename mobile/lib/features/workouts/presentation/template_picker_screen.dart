import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_tokens.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/widgets/ds/lifey_header.dart';
import '../../../shared/widgets/ds/list_group.dart';
import '../../../shared/widgets/ds/section_label.dart';
import '../../../shared/widgets/ds/tinted_chip.dart';
import '../application/exercise_controller.dart';
import '../application/workout_template_controller.dart';
import '../domain/activity_type.dart';
import '../domain/exercise.dart';
import '../domain/exercise_enums.dart';
import '../domain/workout_template.dart';
import 'activity_picker_screen.dart';
import 'log_session_screen.dart';

/// Full-screen template picker shown when the "Log" FAB is **tapped**
/// (a **long press** on the same FAB reaches cardio directly via the C2.7
/// quick-start sheet — see `workouts_screen.dart`). That gesture split
/// turned out to hide cardio too well: nothing on this, the plain-tap
/// screen, hinted a long press did something different. The [_PickerActionTile]
/// for [ActivityPickerScreen] below is this screen's own reachable-by-tap
/// door to the same cardio types, so cardio doesn't depend on a hidden
/// gesture to be found at all (docs/cardio/59-cardio-implementation-plan.md,
/// C2.7 discoverability follow-up, 2026-08-12).
///
/// Lists an "Empty workout" option, then "Cardio", then all saved templates.
/// Selecting "Empty workout" or a template navigates to [LogSessionScreen];
/// selecting "Cardio" navigates to [ActivityPickerScreen], where each row
/// starts its own activity type immediately.
class TemplatePickerScreen extends ConsumerWidget {
  const TemplatePickerScreen({super.key});

  void _start(BuildContext context, {WorkoutTemplate? template}) {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => LogSessionScreen(template: template),
      ),
    );
  }

  void _openActivityPicker(BuildContext context) {
    Navigator.of(context, rootNavigator: true).push(
      MaterialPageRoute(builder: (_) => const ActivityPickerScreen()),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final p = context.palette;

    final templates = ref.watch(workoutTemplateControllerProvider).maybeWhen(
          data: (list) => list,
          orElse: () => <WorkoutTemplate>[],
        );
    final exercisesMap = ref.watch(exerciseControllerProvider).maybeWhen(
          data: (exercises) => {for (final e in exercises) e.clientId: e},
          orElse: () => const <String, Exercise>{},
        );

    return Scaffold(
      appBar: LifeySubpageHeader(title: l10n.chooseTemplateTitle),
      body: ListView(
        padding: EdgeInsets.fromLTRB(
          AppSpacing.screen,
          AppSpacing.s8,
          AppSpacing.screen,
          MediaQuery.paddingOf(context).bottom + AppSpacing.s16,
        ),
        children: [
          ListGroup(
            children: [
              // ── Empty workout option ───────────────────────────────────
              ListRow(
                leading:
                    ListIconHolder(icon: Icons.add_rounded, color: p.text2),
                title: l10n.emptyWorkoutLabel,
                subtitle: l10n.emptyWorkoutSubtitle,
                trailing: Icon(Icons.chevron_right_rounded, color: p.text3),
                onTap: () => _start(context),
              ),
              // ── Cardio option — same door the FAB's long-press opens ──
              ListRow(
                leading: ListIconHolder(
                  icon: Icons.directions_run_rounded,
                  color: activityTypeColor('RUNNING', context),
                ),
                title: l10n.cardioWorkoutTileLabel,
                subtitle: l10n.cardioWorkoutTileSubtitle,
                trailing: Icon(Icons.chevron_right_rounded, color: p.text3),
                onTap: () => _openActivityPicker(context),
              ),
            ],
          ),
          if (templates.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.s24),
            SectionLabel(l10n.templatesTabLabel),
            const SizedBox(height: AppSpacing.s8),
            ListGroup(
              children: [
                for (final t in templates)
                  _PickerTemplateRow(
                    template: t,
                    exercisesMap: exercisesMap,
                    l10n: l10n,
                    onTap: () => _start(context, template: t),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Template row for the picker (tap-only, no edit/delete)
// ---------------------------------------------------------------------------

class _PickerTemplateRow extends StatelessWidget {
  const _PickerTemplateRow({
    required this.template,
    required this.exercisesMap,
    required this.l10n,
    required this.onTap,
  });

  final WorkoutTemplate template;
  final Map<String, Exercise> exercisesMap;
  final AppLocalizations l10n;
  final VoidCallback onTap;

  List<String> _categories() {
    final seen = <String>{};
    final ordered = <String>[];
    for (final code in kMuscleGroups) {
      if (template.exercises.any((te) {
        final ex = exercisesMap[te.exerciseClientId];
        return ex?.category == code;
      })) {
        if (seen.add(code)) ordered.add(code);
      }
    }
    return ordered;
  }

  IconData _icon(List<String> categories) {
    if (categories.contains('CARDIO')) return Icons.directions_run_rounded;
    final hasBodyweight = template.exercises.any(
      (te) => exercisesMap[te.exerciseClientId]?.equipment == 'BODYWEIGHT',
    );
    if (hasBodyweight) return Icons.sports_gymnastics_rounded;
    return Icons.list_alt_rounded;
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final t = Theme.of(context).textTheme;
    final categories = _categories();

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.s16, vertical: AppSpacing.s12),
        child: Row(
          children: [
            ListIconHolder(
                icon: _icon(categories),
                color: Theme.of(context).colorScheme.primary),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    template.name,
                    style: t.titleMedium!
                        .copyWith(fontSize: 15, height: 1.3, color: p.text),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    l10n.exercisesCountLabel(template.exercises.length),
                    style: t.bodySmall!.copyWith(height: 1.4, color: p.text2),
                  ),
                  if (categories.isNotEmpty) ...[
                    const SizedBox(height: AppSpacing.s8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        for (final c in categories)
                          TintedChip(
                              label: muscleGroupLabel(l10n, c),
                              color: muscleGroupColor(c, context)),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.s8),
            Icon(Icons.chevron_right_rounded, color: p.text3),
          ],
        ),
      ),
    );
  }
}
