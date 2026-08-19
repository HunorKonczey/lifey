import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/format/cardio_formatter.dart';
import '../../../../core/theme/app_tokens.dart';
import '../../../../l10n/app_localizations.dart';
import '../../application/cardio_interval_plan_controller.dart';
import '../../domain/cardio_interval_plan.dart';
import '../interval_plan_editor_screen.dart';

/// What the rider chose before an indoor-bike ride starts: a plan to play
/// back, or none.
class IntervalPlanChoice {
  const IntervalPlanChoice.withPlan(String this.planClientId);

  const IntervalPlanChoice.withoutPlan() : planClientId = null;

  /// Null means "start the ride with no plan" — the screen then looks exactly
  /// as it always has (docs/cardio/61 §3 M38's "terv nélkül" state).
  final String? planClientId;
}

/// Offered once, before an indoor-bike session starts (docs/cardio/60 C7.5).
///
/// Same shape and same moment as the GAME family's setup sheet (M45): the
/// question that shapes the whole session is asked before it starts, not
/// mid-ride. It has to live here rather than on the live screen because M38
/// is explicit that a ride without a plan shows *no trace* of the feature.
///
/// Dismissing the sheet starts nothing, again like the game setup sheet — a
/// swipe means "not now", not "start something I didn't choose".
class IntervalPlanPickerSheet extends ConsumerWidget {
  const IntervalPlanPickerSheet({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final accent = context.metricColors.carbs;
    final plans = ref.watch(cardioIntervalPlanControllerProvider).maybeWhen(
          data: (plans) => plans,
          orElse: () => const <CardioIntervalPlan>[],
        );

    return SafeArea(
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l10n.intervalPlanPickerTitle,
                style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 6),
              Text(
                l10n.intervalPlanPickerBody,
                style: theme.textTheme.bodyMedium
                    ?.copyWith(color: scheme.onSurfaceVariant, height: 1.4),
              ),
              const SizedBox(height: 14),
              for (final plan in plans) ...[
                _PlanRow(
                  plan: plan,
                  accent: accent,
                  l10n: l10n,
                  onTap: () => Navigator.of(context).pop(IntervalPlanChoice.withPlan(plan.clientId)),
                ),
                const SizedBox(height: 8),
              ],
              _AddRow(
                icon: Icons.add,
                label: l10n.intervalPlanPickerNewPlan,
                onTap: () async {
                  final navigator = Navigator.of(context);
                  final result = await navigator.push<IntervalPlanEditorResult>(
                    MaterialPageRoute(builder: (_) => const IntervalPlanEditorScreen()),
                  );
                  if (result == null || !navigator.mounted) return;
                  // "Save and start" starts the ride with the new plan;
                  // "Save only" leaves the rider on this sheet, with the plan
                  // now listed above.
                  if (result.start) {
                    navigator.pop(IntervalPlanChoice.withPlan(result.planClientId));
                  }
                },
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: FilledButton.tonal(
                  onPressed: () =>
                      Navigator.of(context).pop(const IntervalPlanChoice.withoutPlan()),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(52),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                    textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
                  ),
                  child: Text(l10n.intervalPlanPickerWithoutPlan),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PlanRow extends StatelessWidget {
  const _PlanRow({
    required this.plan,
    required this.accent,
    required this.l10n,
    required this.onTap,
  });

  final CardioIntervalPlan plan;
  final Color accent;
  final AppLocalizations l10n;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.surfaceContainerLow,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              Icon(Icons.repeat, size: 18, color: accent),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      plan.name,
                      style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w800),
                    ),
                    Text(
                      l10n.intervalPlanSummaryLabel(
                        CardioFormatter.duration(Duration(seconds: plan.totalSeconds)),
                        plan.sectionCount,
                      ),
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, size: 18, color: scheme.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }
}

class _AddRow extends StatelessWidget {
  const _AddRow({required this.icon, required this.label, required this.onTap});

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.surfaceContainerLow,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 14),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 18, color: scheme.onSurfaceVariant),
              const SizedBox(width: 8),
              Text(label, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700)),
            ],
          ),
        ),
      ),
    );
  }
}

Future<IntervalPlanChoice?> showIntervalPlanPicker(BuildContext context) {
  return showModalBottomSheet<IntervalPlanChoice>(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => const IntervalPlanPickerSheet(),
  );
}
