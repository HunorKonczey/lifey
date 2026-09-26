import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_tokens.dart';
import '../../../../core/theme/app_type.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../shared/widgets/ds/lifey_card.dart';
import '../../../../shared/widgets/ds/tinted_chip.dart';
import '../../domain/hr_zones.dart';

/// The colour of heart-rate zone [zone] (1–5): the cool-to-warm ramp of the
/// design's zone bar, taken from the metric colours — blue, green, gold,
/// orange, red — so the live row, the summary's zone card and the rest of the
/// app share one palette (docs/redesign/77-mobile-redesign-plan.md R3.8/R3.9).
Color hrZoneColor(BuildContext context, int zone) {
  final mc = context.metricColors;
  return switch (zone) {
    1 => mc.weight,
    2 => mc.protein,
    3 => mc.carbs,
    4 => mc.calories,
    _ => mc.heart,
  };
}

/// The name of heart-rate zone [zone] with a capital ("Tempo").
String hrZoneDisplayName(AppLocalizations l10n, int zone) {
  final name = switch (zone) {
    1 => l10n.hrZone1Name,
    2 => l10n.hrZone2Name,
    3 => l10n.hrZone3Name,
    4 => l10n.hrZone4Name,
    _ => l10n.hrZone5Name,
  };
  return toBeginningOfSentenceCase(name, l10n.localeName);
}

/// A field label in sentence case ("DISTANCE" → "Distance"): the ARB keeps the
/// upper-case forms because the same strings label form fields, the canvas
/// draws every metric label in sentence case.
String labelCase(BuildContext context, String label) =>
    toBeginningOfSentenceCase(label.toLowerCase(), Localizations.localeOf(context).languageCode);

/// A metric of the live cardio screen as a card of its own (canvas Lifey 3 ›
/// 3.3): the [label] over a big number with its unit — "Distance / 4.52 km".
/// [value] carries the unit after its last space ("5:24 /km"); a value without
/// one ("12:34", "—") is all number. [outlined] is the empty, tappable
/// "type it in" state (a dashed-in-spirit ring and an edit glyph).
class LiveMetricCard extends StatelessWidget {
  const LiveMetricCard({
    super.key,
    required this.label,
    required this.value,
    this.numberSize = 40,
    this.color,
    this.outlined = false,
    this.highlighted = false,
    this.badge,
    this.onTap,
  });

  /// Shown in sentence case — the ARB keeps field labels upper-case ("DISTANCE"),
  /// the canvas draws "Distance".
  final String label;
  final String value;

  /// A small tinted tag after the label ("ESTIMATED" while the signal is weak).
  final String? badge;

  /// 40 for the two-across row, smaller for three across.
  final double numberSize;

  /// Tints the number and the label (a weak signal's amber pace).
  final Color? color;
  final bool outlined;

  /// A frame around the card — the one metric still moving while benched.
  final bool highlighted;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final space = value.lastIndexOf(' ');
    final number = space > 0 ? value.substring(0, space) : value;
    final unit = space > 0 ? value.substring(space + 1) : null;
    final noScale = AppType.noScale(context);
    final editable = outlined && onTap != null;
    final frame = highlighted ? p.text3 : null;

    return LifeyCard(
      onTap: onTap,
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.s16, vertical: AppSpacing.s16),
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: frame == null
              ? null
              : Border(left: BorderSide(color: frame, width: 3)),
        ),
        child: Padding(
          padding: EdgeInsets.only(left: frame == null ? 0 : AppSpacing.s12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        Flexible(
                          child: Text(
                            labelCase(context, label),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context)
                                .textTheme
                                .bodyMedium!.copyWith(fontWeight: FontWeight.w600, color: color ?? p.text2),
                          ),
                        ),
                        if (badge != null) ...[
                          const SizedBox(width: AppSpacing.s8),
                          Flexible(
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color:
                                    (color ?? p.text2).withValues(alpha: 0.16),
                                borderRadius: AppRadius.tagAll,
                              ),
                              child: Text(
                                badge!,
                                style: Theme.of(context)
                                    .textTheme
                                    .labelSmall!
                                    .copyWith(
                                      fontWeight: FontWeight.w700,
                                      color: color ?? p.text2,
                                    ),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  if (editable) ...[
                    const SizedBox(width: AppSpacing.s8),
                    Icon(Icons.edit_rounded, size: 16, color: p.text2)
                  ],
                ],
              ),
              const SizedBox(height: AppSpacing.s8),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text.rich(
                  TextSpan(children: [
                    TextSpan(
                        text: number,
                        style:
                            AppType.number(numberSize, color: color ?? p.text)),
                    if (unit != null)
                      TextSpan(
                          text: ' $unit',
                          style: AppType.unit(numberSize,
                              color: color ?? p.text2)),
                  ]),
                  maxLines: 1,
                  textScaler: noScale,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The heart-rate row of the live screen: "♥ 152 bpm" with the zone as a chip
/// ("Zone 3 · Tempo") and the five zones as a bar whose current segment is lit
/// (canvas Lifey 3 › 3.3). Without a [zone] — no maximum heart rate to measure
/// against — it is just the reading.
class LiveHeartRateCard extends StatelessWidget {
  const LiveHeartRateCard({super.key, required this.bpm, this.zone});

  final int bpm;

  /// 1–5, or null when unknown.
  final int? zone;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final p = context.palette;
    final mc = context.metricColors;
    final noScale = AppType.noScale(context);
    final zone = this.zone;
    final zoneLabel = zone == null
        ? null
        : l10n.liveHeartRateZoneChip(zone, hrZoneDisplayName(l10n, zone));

    return LifeyCard(
      semanticsLabel: [
        l10n.heartRateFieldLabel,
        '$bpm ${l10n.statUnitBpm}',
        if (zoneLabel != null) zoneLabel,
      ].join(', '),
      child: ExcludeSemantics(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Icon(Icons.favorite_rounded, size: 26, color: mc.heart),
                const SizedBox(width: AppSpacing.s12),
                Flexible(
                  flex: 0,
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text.rich(
                      TextSpan(children: [
                        TextSpan(
                            text: '$bpm',
                            style: AppType.number(32, color: p.text)),
                        TextSpan(
                            text: ' ${l10n.statUnitBpm}',
                            style: AppType.unit(32, color: p.text2, size: 15)),
                      ]),
                      maxLines: 1,
                      textScaler: noScale,
                    ),
                  ),
                ),
                if (zone != null) ...[
                  const SizedBox(width: AppSpacing.s12),
                  Expanded(
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: TintedChip(
                          label: zoneLabel!,
                          color: hrZoneColor(context, zone),
                          size: TintedChipSize.medium),
                    ),
                  ),
                ],
              ],
            ),
            if (zone != null) ...[
              const SizedBox(height: AppSpacing.s12),
              Row(
                children: [
                  for (var z = 1; z <= kHeartRateZoneCount; z++) ...[
                    if (z > 1) const SizedBox(width: AppSpacing.s4),
                    Expanded(
                      child: Container(
                        height: 8,
                        decoration: BoxDecoration(
                          color: hrZoneColor(context, z)
                              .withValues(alpha: z == zone ? 1 : 0.32),
                          borderRadius: AppRadius.pill,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
