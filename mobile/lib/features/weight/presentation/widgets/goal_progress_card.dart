import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_tokens.dart';
import '../../../../l10n/app_localizations.dart';
import '../../application/weight_trend_data.dart';
import '../../domain/weight_trend.dart';

/// Goal weight, what is left of it, and — when the trend supports one — the
/// date it would be reached (docs/76-smarter-weight-trend-plan.md §4).
///
/// Renders nothing when there is no goal or no trend yet: an empty goal card
/// would be a permanent piece of furniture for everyone who never set one.
class GoalProgressCard extends ConsumerWidget {
  const GoalProgressCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final projection = ref.watch(weightGoalProjectionProvider);
    if (projection == null) return const SizedBox.shrink();

    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final mc = context.metricColors;
    final reached = projection.state == WeightProjectionState.reached;

    return Container(
      decoration: BoxDecoration(
        color: scheme.surfaceContainer,
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(reached ? Icons.flag : Icons.flag_outlined, size: 18, color: mc.weight),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  l10n.weightGoalCardTitle,
                  style: theme.textTheme.labelMedium
                      ?.copyWith(color: scheme.onSurfaceVariant),
                ),
              ),
              Text(
                l10n.weightKgValue(projection.goalKg.toStringAsFixed(1)),
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (!reached)
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  l10n.weightGoalRemainingValue(projection.remainingKg.toStringAsFixed(1)),
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: scheme.onSurface,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
                if (projection.kgPerWeek != null) ...[
                  const SizedBox(width: 10),
                  Text(
                    l10n.weightGoalRateValue(_formatRate(projection.kgPerWeek!)),
                    style: theme.textTheme.labelLarge
                        ?.copyWith(color: scheme.onSurfaceVariant),
                  ),
                ],
              ],
            ),
          if (!reached) const SizedBox(height: 6),
          Text(
            _message(projection, l10n, context),
            style: theme.textTheme.bodySmall?.copyWith(
              color: reached ? mc.weight : scheme.onSurfaceVariant,
              fontWeight: reached ? FontWeight.w700 : null,
            ),
          ),
        ],
      ),
    );
  }

  String _message(
      WeightProjection projection, AppLocalizations l10n, BuildContext context) {
    return switch (projection.state) {
      WeightProjectionState.reached => l10n.weightGoalReachedMessage,
      WeightProjectionState.wrongWay => l10n.weightGoalWrongWayMessage,
      WeightProjectionState.tooSlow => l10n.weightGoalTooSlowMessage,
      WeightProjectionState.notEnoughData => l10n.weightGoalNotEnoughDataMessage,
      WeightProjectionState.onTrack => l10n.weightGoalEtaMessage(
          DateFormat.yMMMMd(Localizations.localeOf(context).languageCode)
              .format(projection.etaDate!)),
    };
  }

  /// Signed, because "+0.3 kg/week" and "−0.3" mean opposite things and the
  /// card is read at a glance.
  String _formatRate(double kgPerWeek) {
    final rounded = (kgPerWeek * 10).round() / 10;
    final sign = rounded > 0 ? '+' : rounded < 0 ? '−' : '';
    return '$sign${rounded.abs().toStringAsFixed(1)}';
  }
}
