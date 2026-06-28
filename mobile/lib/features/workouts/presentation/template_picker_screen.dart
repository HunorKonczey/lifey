import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_tokens.dart';
import '../../../l10n/app_localizations.dart';
import '../application/exercise_controller.dart';
import '../application/workout_template_controller.dart';
import '../domain/exercise.dart';
import '../domain/exercise_enums.dart';
import '../domain/workout_template.dart';
import 'log_session_screen.dart';

/// Full-screen template picker shown when the "Log" FAB is tapped.
///
/// Lists an "Empty workout" option followed by all saved templates.
/// Selecting any option navigates to [LogSessionScreen].
class TemplatePickerScreen extends ConsumerWidget {
  const TemplatePickerScreen({super.key});

  void _start(BuildContext context, {WorkoutTemplate? template}) {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => LogSessionScreen(template: template),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;

    final templates = ref.watch(workoutTemplateControllerProvider).maybeWhen(
          data: (list) => list,
          orElse: () => <WorkoutTemplate>[],
        );
    final exercisesMap = ref.watch(exerciseControllerProvider).maybeWhen(
          data: (exercises) => {for (final e in exercises) e.clientId: e},
          orElse: () => const <String, Exercise>{},
        );

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.chooseTemplateTitle),
        centerTitle: true,
      ),
      body: ListView(
        padding: EdgeInsets.fromLTRB(
          12,
          8,
          12,
          MediaQuery.paddingOf(context).bottom + 16,
        ),
        children: [
          // ── Empty workout option ─────────────────────────────────────────
          _EmptyWorkoutTile(
            l10n: l10n,
            onTap: () => _start(context),
          ),

          if (templates.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 20, 4, 8),
              child: Text(
                l10n.templatesTabLabel,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: scheme.onSurfaceVariant,
                  letterSpacing: 0.4,
                ),
              ),
            ),
            ...templates.map(
              (t) => _PickerTemplateCard(
                template: t,
                exercisesMap: exercisesMap,
                l10n: l10n,
                onTap: () => _start(context, template: t),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Empty workout tile
// ---------------------------------------------------------------------------

class _EmptyWorkoutTile extends StatelessWidget {
  const _EmptyWorkoutTile({required this.l10n, required this.onTap});

  final AppLocalizations l10n;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Card(
      elevation: 0,
      color: scheme.surfaceContainerHigh,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.card),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: scheme.secondaryContainer,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Center(
                  child: Icon(
                    Icons.add_rounded,
                    size: 24,
                    color: scheme.onSecondaryContainer,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.emptyWorkoutLabel,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ).copyWith(color: scheme.onSurface),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      l10n.emptyWorkoutSubtitle,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ).copyWith(color: scheme.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded,
                  color: scheme.onSurfaceVariant, size: 22),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Template card for the picker (tap-only, no edit/delete)
// ---------------------------------------------------------------------------

class _PickerTemplateCard extends StatelessWidget {
  const _PickerTemplateCard({
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
    if (categories.contains('CARDIO')) return Icons.directions_run;
    final hasBodyweight = template.exercises.any(
      (te) => exercisesMap[te.exerciseClientId]?.equipment == 'BODYWEIGHT',
    );
    if (hasBodyweight) return Icons.sports_gymnastics;
    return Icons.list_alt;
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final categories = _categories();

    return Card(
      elevation: 0,
      color: scheme.surfaceContainerHigh,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.card),
      ),
      margin: const EdgeInsets.only(bottom: 10),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: scheme.primaryContainer,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Center(
                  child: Icon(
                    _icon(categories),
                    size: 24,
                    color: scheme.onPrimaryContainer,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      template.name,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ).copyWith(color: scheme.onSurface),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      l10n.exercisesCountLabel(template.exercises.length),
                      style: const TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                      ).copyWith(color: scheme.onSurfaceVariant),
                    ),
                    if (categories.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: categories
                            .map((c) => _CategoryChip(
                                  label: muscleGroupLabel(l10n, c),
                                  color: muscleGroupColor(c, context),
                                ))
                            .toList(),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(Icons.chevron_right_rounded,
                  color: scheme.onSurfaceVariant, size: 22),
            ],
          ),
        ),
      ),
    );
  }
}

class _CategoryChip extends StatelessWidget {
  const _CategoryChip({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: AppRadius.pill,
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          height: 1.0,
        ).copyWith(color: color),
      ),
    );
  }
}
