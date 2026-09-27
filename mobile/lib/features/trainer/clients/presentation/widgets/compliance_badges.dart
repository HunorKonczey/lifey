import 'package:flutter/material.dart';

import '../../../../../core/theme/app_tokens.dart';
import '../../../../../l10n/app_localizations.dart';
import '../../../../../shared/widgets/ds/delta_chip.dart';
import '../../../../../shared/widgets/ds/tinted_chip.dart';
import '../../domain/compliance.dart';

/// The chips under a client card's KPIs (canvas Lifey 6 › 9.1): a warning per
/// thing that needs the trainer — "Missed 2 sessions" in the calorie tint,
/// "Weigh-in due" in the weight blue — and, when there is one, the gold
/// "🏆 2 PRs this week".
///
/// A client who has gone quiet is *not* a chip: the status line under their
/// name says "Last seen 4 days ago" in the warning colour, and saying it twice
/// would only make the card louder. Each chip carries the full sentence as its
/// semantics label. Renders nothing when there is nothing to say.
class ComplianceBadges extends StatelessWidget {
  const ComplianceBadges({super.key, required this.flags, this.prCount});

  final ComplianceFlags flags;

  /// Records set in the last 7 days; null (unknown) and 0 draw nothing.
  final int? prCount;

  /// Whether there is any chip to draw.
  bool get hasContent => flags.hasMissedWorkouts || flags.weightStale || (prCount ?? 0) > 0;

  @override
  Widget build(BuildContext context) {
    if (!hasContent) return const SizedBox.shrink();
    final l10n = AppLocalizations.of(context)!;
    final mc = context.metricColors;

    return Wrap(
      spacing: AppSpacing.s8,
      runSpacing: AppSpacing.s8,
      children: [
        if (flags.hasMissedWorkouts)
          TintedChip(
            label: l10n.trainerClientChipMissed(flags.missedWorkouts),
            color: mc.calories,
            semanticsLabel: l10n.trainerComplianceMissedSemanticsLabel(flags.missedWorkouts),
          ),
        if (flags.weightStale)
          TintedChip(
            label: l10n.trainerClientChipWeighInDue,
            color: mc.weight,
            semanticsLabel: l10n.trainerComplianceWeightStaleSemanticsLabel(flags.daysSinceWeight),
          ),
        if ((prCount ?? 0) > 0) RecordChip(label: l10n.trainerClientChipPrs(prCount!)),
      ],
    );
  }
}
