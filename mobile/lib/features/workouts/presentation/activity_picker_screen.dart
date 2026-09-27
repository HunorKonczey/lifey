import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_tokens.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/widgets/activity_chip.dart';
import '../../../shared/widgets/ds/lifey_header.dart';
import '../../../shared/widgets/ds/list_group.dart';
import '../../../shared/widgets/ds/section_label.dart';
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
    final p = context.palette;
    final templates =
        ref.watch(workoutTemplateControllerProvider).value ?? const [];

    // M03 reads as a sheet that grew to full height, not as a page: no back
    // arrow, the header carries its own close button instead
    // (docs/redesign/77-mobile-redesign-plan.md R3.10).
    return Scaffold(
      appBar: LifeySubpageHeader(
        title: l10n.activityPickerTitle,
        showBack: false,
        actions: [
          HeaderIconButton(
            icon: Icons.close_rounded,
            tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
      body: ListView(
        padding: EdgeInsets.fromLTRB(
          AppSpacing.screen,
          AppSpacing.s8,
          AppSpacing.screen,
          MediaQuery.paddingOf(context).bottom + AppSpacing.s16,
        ),
        children: [
          // "A cardio blokk van felül: aki idáig eljutott, jó
          // eséllyel olyat keres, ami nincs a négy csempén" (M03).
          SectionLabel(l10n.cardioSectionLabel),
          const SizedBox(height: AppSpacing.s8),
          ListGroup(
            children: [
              for (final type in kActivityTypes)
                ListRow(
                  leading: ActivityChip(activityType: type, size: 44),
                  title: activityTypeLabel(l10n, type),
                  subtitle:
                      activityModalitySubtitle(l10n, activityFamilyOf(type)),
                  trailing: Icon(Icons.chevron_right_rounded, color: p.text3),
                  onTap: () => startCardioQuickly(context, ref, type),
                ),
            ],
          ),
          if (templates.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.s24),
            SectionLabel(l10n.strengthTemplatesSectionLabel),
            const SizedBox(height: AppSpacing.s8),
            ListGroup(
              children: [
                for (final template in templates)
                  ListRow(
                    leading:
                        const ActivityChip(activityType: 'STRENGTH', size: 44),
                    title: template.name,
                    subtitle:
                        l10n.exercisesCountLabel(template.exercises.length),
                    trailing: Icon(Icons.chevron_right_rounded, color: p.text3),
                    onTap: () =>
                        startStrengthQuickly(context, template: template),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
