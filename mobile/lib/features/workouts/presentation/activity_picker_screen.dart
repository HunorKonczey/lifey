import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_tokens.dart';
import '../../../l10n/app_localizations.dart';
import '../application/workout_template_controller.dart';
import '../domain/activity_type.dart';
import 'quick_start_sheet.dart';

/// The full activity/template list (docs/cardio/59-cardio-implementation-plan.md
/// C2.7, M03) — reached from the quick-start sheet's "All workout types"
/// row, for when none of the top-4 tiles is what the user wants. Every row
/// starts its workout immediately, same as the sheet's tiles
/// ([startCardioQuickly]/[startStrengthQuickly] — shared, not duplicated).
///
/// **Deliberate simplification vs. the M03 mockup**: no search field, and
/// no "Empty workout" row in the strength section (the mockup itself
/// doesn't show one either — its own note is that someone who scrolled
/// this far is looking for something specific; an empty workout is still
/// one tap away from the FAB's plain-tap → `TemplatePickerScreen` path).
class ActivityPickerScreen extends ConsumerWidget {
  const ActivityPickerScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final templates = ref.watch(workoutTemplateControllerProvider).value ?? const [];

    final scheme = Theme.of(context).colorScheme;

    // M03 reads as a sheet that grew to full height, not as a page: the
    // whole surface sits one step up from the app background, and the title
    // row carries its own close button instead of an app bar.
    return Scaffold(
      backgroundColor: scheme.surfaceContainerLow,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 6, 16, 12),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      l10n.activityPickerTitle,
                      style: const TextStyle(
                        fontSize: 21,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.4,
                      ),
                    ),
                  ),
                  Material(
                    color: scheme.surfaceContainer,
                    shape: const CircleBorder(),
                    child: InkWell(
                      onTap: () => Navigator.of(context).pop(),
                      customBorder: const CircleBorder(),
                      child: SizedBox(
                        width: 36,
                        height: 36,
                        child: Icon(Icons.close, size: 20, color: scheme.onSurfaceVariant),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: EdgeInsets.fromLTRB(
                  AppSpacing.s16,
                  0,
                  AppSpacing.s16,
                  MediaQuery.paddingOf(context).bottom + AppSpacing.s16,
                ),
                children: [
                  // "A cardio blokk van felül: aki idáig eljutott, jó
                  // eséllyel olyat keres, ami nincs a négy csempén" (M03).
                  _SectionLabel(l10n.cardioSectionLabel),
                  _RowGroup(
                    children: [
                      for (final type in kActivityTypes)
                        _PickerRow(
                          icon: activityTypeIcon(type),
                          color: activityTypeColor(type, context),
                          title: activityTypeLabel(l10n, type),
                          subtitle: activityModalitySubtitle(l10n, activityFamilyOf(type)),
                          onTap: () => startCardioQuickly(context, ref, type),
                        ),
                    ],
                  ),
                  if (templates.isNotEmpty) ...[
                    const SizedBox(height: AppSpacing.s24),
                    _SectionLabel(l10n.strengthTemplatesSectionLabel),
                    _RowGroup(
                      children: [
                        for (final template in templates)
                          _PickerRow(
                            icon: activityTypeIcon('STRENGTH'),
                            color: activityTypeColor('STRENGTH', context),
                            title: template.name,
                            subtitle: l10n.exercisesCountLabel(template.exercises.length),
                            onTap: () => startStrengthQuickly(context, template: template),
                          ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 0, 4, 9),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 10.5,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.3,
          color: scheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

class _RowGroup extends StatelessWidget {
  const _RowGroup({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: scheme.surfaceContainer,
        borderRadius: BorderRadius.circular(AppRadius.card),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0) Divider(height: 1, indent: 62, color: scheme.surfaceContainerHigh),
            children[i],
          ],
        ],
      ),
    );
  }
}

class _PickerRow extends StatelessWidget {
  const _PickerRow({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 11),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration:
                  BoxDecoration(shape: BoxShape.circle, color: color.withValues(alpha: 0.16)),
              child: Icon(icon, size: 22, color: color),
            ),
            const SizedBox(width: AppSpacing.s12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                  Text(subtitle,
                      style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: scheme.onSurfaceVariant)),
                ],
              ),
            ),
            Icon(Icons.chevron_right, size: 19, color: scheme.onSurfaceVariant),
          ],
        ),
      ),
    );
  }
}
