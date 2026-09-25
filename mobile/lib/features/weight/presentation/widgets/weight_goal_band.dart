import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/format/lifey_format.dart';
import '../../../../core/theme/app_tokens.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../shared/widgets/ds/metric_bar.dart';
import '../../../onboarding/presentation/onboarding_edit_screen.dart';
import '../../application/weight_headline.dart';
import '../../application/weight_trend_data.dart';
import '../../domain/weight_trend.dart';

/// "Start 67.9 · Goal 62.0 kg · 2.5 kg to go" over a progress track — the goal
/// band under the weight hero (canvas Lifey 4 › 4.1; docs/redesign/77-mobile-
/// redesign-plan.md R4.1). Start is the first weight ever recorded, the goal
/// comes from onboarding and is edited in the profile.
///
/// Without a goal it is a "Set a goal weight" action instead of zeros. The
/// projection line of docs/76 (§4: "At this rate, around …", "moving the wrong
/// way", "not enough data yet") stays under the track as tertiary text.
class WeightGoalBand extends ConsumerWidget {
  const WeightGoalBand({super.key, required this.headline});

  final WeightHeadline headline;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final p = context.palette;
    final mc = context.metricColors;
    final t = Theme.of(context).textTheme;
    final f = LifeyFormat.of(context);

    final goal = headline.goalKg;
    if (goal == null) {
      return TextButton.icon(
        onPressed: () => Navigator.of(context).push(
          MaterialPageRoute<void>(builder: (_) => const OnboardingEditScreen()),
        ),
        style: TextButton.styleFrom(
          alignment: Alignment.centerLeft,
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s4),
          minimumSize: const Size(0, 48),
        ),
        icon: const Icon(Icons.flag_outlined, size: 20),
        label: Text(l10n.weightSetGoalAction),
      );
    }

    final projection = ref.watch(weightGoalProjectionProvider);
    final reached = headline.reached;
    final labelStyle = t.bodyMedium!.copyWith(fontSize: 15, color: p.text2, height: 1.3);
    final strong = labelStyle.copyWith(fontWeight: FontWeight.w800, color: p.text);
    final message = _projectionNote(context, l10n, projection);
    final rate = projection?.kgPerWeek;
    // "−0.3 kg/week · At this rate, around March 12, 2027"
    final note = message == null
        ? null
        : rate == null ? message : '${l10n.weightGoalRateValue(_formatRate(rate))} · $message';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // A Wrap, not a Row: the goal half drops under the start half when a
        // long language or a big text size leaves no room for both.
        Wrap(
          alignment: WrapAlignment.spaceBetween,
          spacing: AppSpacing.s12,
          children: [
            Text(l10n.weightGoalStart(f.decimal(headline.startKg, 1)), style: labelStyle),
            Text.rich(
              TextSpan(style: labelStyle, children: [
                TextSpan(text: '${l10n.weightGoalBandGoal} '),
                TextSpan(text: l10n.weightKgValue(f.decimal(goal, 1)), style: strong),
                TextSpan(
                  text: ' · ${reached ? l10n.weightGoalBandReached : l10n.weightGoalRemainingValue(f.decimal(headline.remainingKg!, 1))}',
                ),
              ]),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.s8),
        Semantics(
          label: reached ? l10n.weightGoalBandReached : l10n.weightGoalRemainingValue(f.decimal(headline.remainingKg!, 1)),
          child: ExcludeSemantics(
            child: MetricBar(progress: headline.progress ?? 0, color: mc.weight, height: 8),
          ),
        ),
        if (note != null) ...[
          const SizedBox(height: AppSpacing.s8),
          Text(note, style: t.bodySmall!.copyWith(color: p.text3, height: 1.4)),
        ],
      ],
    );
  }

  String? _projectionNote(BuildContext context, AppLocalizations l10n, WeightProjection? projection) {
    if (projection == null || headline.reached) return null;
    return switch (projection.state) {
      WeightProjectionState.reached => null,
      WeightProjectionState.wrongWay => l10n.weightGoalWrongWayMessage,
      WeightProjectionState.tooSlow => l10n.weightGoalTooSlowMessage,
      WeightProjectionState.notEnoughData => l10n.weightGoalNotEnoughDataMessage,
      WeightProjectionState.onTrack => l10n.weightGoalEtaMessage(
          DateFormat.yMMMMd(Localizations.localeOf(context).languageCode).format(projection.etaDate!)),
    };
  }

  /// Signed, because "+0.3 kg/week" and "−0.3" mean opposite things and the
  /// line is read at a glance.
  String _formatRate(double kgPerWeek) {
    final rounded = (kgPerWeek * 10).round() / 10;
    final sign = rounded > 0 ? '+' : rounded < 0 ? '−' : '';
    return '$sign${rounded.abs().toStringAsFixed(1)}';
  }
}
