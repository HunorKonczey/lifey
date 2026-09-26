import 'package:flutter/material.dart';

import '../../../../core/format/lifey_format.dart';
import '../../../../core/theme/app_tokens.dart';
import '../../../../core/theme/app_type.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../shared/widgets/ds/lifey_card.dart';
import '../../../settings/domain/user_settings.dart';
import '../../domain/week_summary.dart';

/// "3 workouts this week · 96 min this week · 5.2 km this week": the three
/// numbers over the Sessions list, so the list below has some context
/// (docs/redesign/77-mobile-redesign-plan.md R3.1; canvas Lifey 3 › 3.1 "Heti
/// összesítő elöl"). Equal-width tiles of equal height, the label wrapping
/// under a 30/800 number instead of being cut — Hungarian and 130 % text
/// included.
class WeekSummaryRow extends StatelessWidget {
  const WeekSummaryRow({super.key, required this.summary, required this.unitSystem});

  final WeekSummary summary;
  final UnitSystem unitSystem;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final f = LifeyFormat.of(context);
    final imperial = unitSystem == UnitSystem.imperial;
    final distance = imperial ? summary.distanceMeters / 1609.344 : summary.distanceMeters / 1000;

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: _Tile(
              value: f.integer(summary.workouts),
              label: l10n.weekSummaryWorkoutsLabel(summary.workouts),
            ),
          ),
          const SizedBox(width: AppSpacing.s8),
          Expanded(child: _Tile(value: f.integer(summary.minutes), label: l10n.weekSummaryMinutesLabel)),
          const SizedBox(width: AppSpacing.s8),
          Expanded(
            child: _Tile(
              value: f.decimal(distance, 1),
              label: imperial ? l10n.weekSummaryMilesLabel : l10n.weekSummaryKmLabel,
            ),
          ),
        ],
      ),
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Semantics(
      label: '$value $label',
      excludeSemantics: true,
      child: LifeyCard(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                value,
                maxLines: 1,
                style: AppType.number(30, weight: FontWeight.w800, color: p.text),
              ),
            ),
            const SizedBox(height: AppSpacing.s4),
            Text(
              label,
              style: Theme.of(context).textTheme.bodySmall!.copyWith(height: 1.3, color: p.text2),
            ),
          ],
        ),
      ),
    );
  }
}
