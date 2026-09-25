import 'package:flutter/material.dart';

import '../../../../../core/format/lifey_format.dart';
import '../../../../../core/theme/app_tokens.dart';
import '../../../../../core/theme/app_type.dart';
import '../../../../../l10n/app_localizations.dart';
import '../../../../../shared/widgets/ds/lifey_card.dart';
import '../../../shared/client_avatar.dart';
import '../../domain/compliance.dart';
import '../../domain/trainer_client.dart';
import 'compliance_badges.dart';
import 'weight_sparkline.dart';

/// One client, as a card that prioritises (canvas Lifey 6 › 9.1): the monogram,
/// the name, a status line with a coloured dot ("Active today" green, "Last
/// seen 4 days ago" orange), the weight sparkline, up to three KPI tiles —
/// Avg kcal · Workouts / wk · Weight change — and the chips that say what needs
/// the trainer.
///
/// A KPI the backend has no figure for is *hidden*, never drawn as a zero: a
/// client who logged no meals has no "0 kcal", and one weigh-in has no "Δ".
class ClientCard extends StatelessWidget {
  const ClientCard({
    super.key,
    required this.client,
    required this.now,
    this.onTap,
    this.selected = false,
  });

  final TrainerClient client;

  /// Injected so the card's "days ago" and its chips are read off the same
  /// instant as the list's sort — and so tests don't depend on wall clock.
  final DateTime now;

  /// Opens the client detail screen. Nullable so the card can be rendered in
  /// contexts that are only showing a client rather than offering one.
  final VoidCallback? onTap;

  /// Marks the card whose detail the pane beside it is showing (§8.2). Only a
  /// two-pane layout has one: on a phone the detail covers the list anyway.
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final mc = context.metricColors;
    final scheme = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;
    final l10n = AppLocalizations.of(context)!;
    final f = LifeyFormat.of(context);
    final flags = complianceFor(client, now: now);

    final change = client.weightChangeKg;
    final kpis = <_Kpi>[
      if (client.avgCalories7d != null) _Kpi(l10n.trainerClientKpiAvgKcal, f.integer(client.avgCalories7d!)),
      _Kpi(l10n.trainerClientKpiWorkouts, l10n.trainerClientKpiPerWeek(client.workoutsPerWeek)),
      if (change != null) _Kpi(l10n.trainerClientKpiWeight, '${f.signedDelta(change)} kg', color: mc.weight),
    ];

    final lastActivityAt = client.lastActivityAt;
    final days = lastActivityAt == null ? null : _wholeDaysBetween(lastActivityAt, now);
    final statusLabel = days == null
        ? l10n.trainerClientNoActivityLabel
        : days == 0
            ? l10n.trainerClientActiveTodayLabel
            : days == 1
                ? l10n.trainerClientActiveYesterdayLabel
                : l10n.trainerClientLastSeenLabel(days);
    // Green while they are around, the warning colour once they have gone quiet
    // (the compliance threshold), grey when there is nothing to judge yet.
    final statusColor = flags.inactive ? mc.calories : (days == null ? p.text2 : mc.improvement);
    final chips = ComplianceBadges(flags: flags, prCount: client.prCount7d);

    final card = LifeyCard(
      onTap: onTap,
      padding: const EdgeInsets.all(AppSpacing.s16),
      semanticsLabel: '${client.displayName}, $statusLabel',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              ClientAvatar(client: client, size: 52),
              const SizedBox(width: AppSpacing.s12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      client.displayName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: t.titleLarge!.copyWith(fontWeight: FontWeight.w800, color: p.text),
                    ),
                    const SizedBox(height: AppSpacing.s4),
                    Row(
                      children: [
                        Container(width: 8, height: 8, decoration: BoxDecoration(color: statusColor, shape: BoxShape.circle)),
                        const SizedBox(width: AppSpacing.s8),
                        Flexible(
                          child: Text(
                            statusLabel,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: t.bodyMedium!.copyWith(fontWeight: FontWeight.w600, color: statusColor),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              if (client.weightTrend.length >= 2) ...[
                const SizedBox(width: AppSpacing.s8),
                WeightSparkline(points: client.weightTrend),
              ],
            ],
          ),
          const SizedBox(height: AppSpacing.s16),
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final (i, kpi) in kpis.indexed) ...[
                  if (i > 0) const SizedBox(width: AppSpacing.s8),
                  Expanded(child: _KpiTile(kpi: kpi)),
                ],
              ],
            ),
          ),
          if (chips.hasContent) ...[
            const SizedBox(height: AppSpacing.s12),
            chips,
          ],
        ],
      ),
    );

    if (!selected) return card;
    // The card whose detail sits beside the list: a primary ring around it.
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: AppRadius.cardAll,
        border: Border.all(color: scheme.primary, width: 1.5),
      ),
      child: card,
    );
  }

}

class _Kpi {
  const _Kpi(this.label, this.value, {this.color});

  final String label;
  final String value;
  final Color? color;
}

class _KpiTile extends StatelessWidget {
  const _KpiTile({required this.kpi});

  final _Kpi kpi;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final t = Theme.of(context).textTheme;
    return LifeyCard.nested(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s12, vertical: AppSpacing.s12),
      semanticsLabel: '${kpi.label} ${kpi.value}',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(kpi.label, maxLines: 1, overflow: TextOverflow.ellipsis, style: t.labelMedium!.copyWith(color: p.text2)),
          const SizedBox(height: AppSpacing.s4),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              kpi.value,
              maxLines: 1,
              textScaler: AppType.noScale(context),
              style: AppType.number(20, color: kpi.color ?? p.text),
            ),
          ),
        ],
      ),
    );
  }
}

int _wholeDaysBetween(DateTime from, DateTime to) {
  final elapsedMs = to.millisecondsSinceEpoch - from.millisecondsSinceEpoch;
  if (elapsedMs < 0) return 0;
  return elapsedMs ~/ const Duration(days: 1).inMilliseconds;
}
