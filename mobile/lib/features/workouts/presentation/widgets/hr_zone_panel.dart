import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/format/cardio_formatter.dart';
import '../../../../core/theme/app_tokens.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../shared/widgets/ds/lifey_card.dart';
import '../../../../shared/widgets/ds/tinted_chip.dart';
import '../../domain/hr_zone_breakdown.dart';
import 'cardio_live_cards.dart';

/// The heart-rate zone card of a finished session (canvas Lifey 3 › 3.3, M43):
/// "Heart rate zones" with a verdict chip, one stacked bar in the zone colours,
/// then a row per zone — "Z3 · Tempo · 9:41 · 35 %" — and a footnote in the
/// tertiary text colour.
///
/// **One component for every cardio type** (docs/cardio/60 Q-D7) — a run, a
/// bike session and a match all get the identical card; only *where* the
/// summary places it differs by family.
///
/// Accessibility rules, load-bearing:
/// - the verdict is **said in words** in the header chip, because the bar's
///   colours alone are not readable by a colour-blind user;
/// - **the numbers are always full contrast** — colour appears only on the
///   zone code and the bar, never on the time or the percentage;
/// - the percentages are the largest-remainder split ([HrZoneBreakdown.percents])
///   and always add up to 100.
class HrZonePanel extends StatelessWidget {
  const HrZonePanel({super.key, required this.breakdown});

  final HrZoneBreakdown breakdown;

  String _verdict(AppLocalizations l10n) => switch (breakdown.intensity) {
        HrZoneIntensity.hard => l10n.hrZoneVerdictHard,
        HrZoneIntensity.balanced => l10n.hrZoneVerdictBalanced,
        HrZoneIntensity.easy => l10n.hrZoneVerdictEasy,
      };

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final p = context.palette;
    final t = Theme.of(context).textTheme;
    final mc = context.metricColors;
    final percents = breakdown.percents;
    final verdictColor = switch (breakdown.intensity) {
      HrZoneIntensity.hard => mc.calories,
      HrZoneIntensity.balanced => mc.protein,
      HrZoneIntensity.easy => mc.weight,
    };

    return LifeyCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // A Wrap, not a Row: a long verdict ("Kiegyensúlyozott edzés") at a
          // large text size goes under the title instead of squeezing it.
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: AppSpacing.s12,
            runSpacing: AppSpacing.s8,
            children: [
              Semantics(
                header: true,
                child: Text(
                  toBeginningOfSentenceCase(
                      l10n.hrZonesSectionLabel.toLowerCase(), l10n.localeName),
                  style: t.titleLarge!.copyWith(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      height: 1.2,
                      color: p.text),
                ),
              ),
              TintedChip(
                  label: _verdict(l10n),
                  color: verdictColor,
                  size: TintedChipSize.medium),
            ],
          ),
          const SizedBox(height: AppSpacing.s16),
          _StackedZoneBar(breakdown: breakdown, hatchColor: p.text3),
          if (breakdown.isPartial) ...[
            const SizedBox(height: AppSpacing.s12),
            Row(
              children: [
                Icon(Icons.timelapse, size: 14, color: p.text3),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    l10n.hrZonePartialCoverage(
                        (breakdown.coverageFraction * 100).round().toString()),
                    style: t.bodySmall!.copyWith(color: p.text3),
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: AppSpacing.s16),
          for (final slice in breakdown.slices)
            _ZoneRow(
              slice: slice,
              name: hrZoneDisplayName(l10n, slice.zone),
              percent: percents[slice.zone - 1],
              color: hrZoneColor(context, slice.zone),
            ),
          const SizedBox(height: AppSpacing.s4),
          Text(
            l10n.hrZoneSourceNote,
            style: t.bodySmall!
                .copyWith(fontSize: 13, height: 1.4, color: p.text3),
          ),
        ],
      ),
    );
  }
}

/// The stacked bar: zone slices fill the measured part of the track, 3 dp
/// apart; an unmeasured remainder is **hatched**, never stretched over (M43's
/// partial state) — stretching would claim heart-rate data for minutes that
/// have none.
class _StackedZoneBar extends StatelessWidget {
  const _StackedZoneBar({required this.breakdown, required this.hatchColor});

  final HrZoneBreakdown breakdown;
  final Color hatchColor;

  static const double _height = 12;
  static const double _gap = 3;

  @override
  Widget build(BuildContext context) {
    final coverage = breakdown.coverageFraction;
    final segments = <Widget>[
      for (final slice in breakdown.slices)
        if (slice.fraction > 0)
          Expanded(
            // Integer-ish flex from a 0..1 fraction: scaled up so small
            // slices survive rounding rather than vanishing.
            flex: (slice.fraction * coverage * 10000).round().clamp(1, 1 << 30),
            child: DecoratedBox(
              decoration: BoxDecoration(
                  color: hrZoneColor(context, slice.zone),
                  borderRadius: AppRadius.pill),
            ),
          ),
      if (breakdown.isPartial)
        Expanded(
          flex: ((1 - coverage) * 10000).round().clamp(1, 1 << 30),
          child: ClipRRect(
            borderRadius: AppRadius.pill,
            child: CustomPaint(painter: _HatchPainter(color: hatchColor)),
          ),
        ),
    ];
    return SizedBox(
      height: _height,
      child: Row(
        children: [
          for (var i = 0; i < segments.length; i++) ...[
            if (i > 0) const SizedBox(width: _gap),
            segments[i],
          ],
        ],
      ),
    );
  }
}

class _HatchPainter extends CustomPainter {
  const _HatchPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(
        Offset.zero & size, Paint()..color = color.withValues(alpha: 0.25));
    final line = Paint()
      ..color = color
      ..strokeWidth = 1;
    // 45° hatching, spaced 6 px — reads as "no data here" rather than as a
    // sixth zone.
    for (var x = -size.height; x < size.width; x += 6) {
      canvas.drawLine(Offset(x, size.height), Offset(x + size.height, 0), line);
    }
  }

  @override
  bool shouldRepaint(_HatchPainter oldDelegate) => oldDelegate.color != color;
}

/// One row: `Z3` in the zone colour · the zone's name · the time · the
/// percentage. Every one of the five is listed, including the untouched ones —
/// seeing that no time was spent at threshold is information, not an empty row.
class _ZoneRow extends StatelessWidget {
  const _ZoneRow(
      {required this.slice,
      required this.name,
      required this.percent,
      required this.color});

  final HrZoneSlice slice;
  final String name;
  final int percent;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final t = Theme.of(context).textTheme;
    final tabular = const [FontFeature.tabularFigures()];
    final time = CardioFormatter.duration(Duration(seconds: slice.seconds));
    return Semantics(
      label: '${slice.zone}. $name, $time, $percent %',
      excludeSemantics: true,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.s4),
        child: Row(
          children: [
            SizedBox(
              width: 34,
              child: Text(
                'Z${slice.zone}',
                style: t.titleSmall!.copyWith(
                    fontSize: 15, fontWeight: FontWeight.w800, color: color),
              ),
            ),
            Expanded(
              child: Text(name,
                  style: t.bodyLarge!.copyWith(fontSize: 17, color: p.text2)),
            ),
            const SizedBox(width: AppSpacing.s8),
            // Full contrast even for an untouched zone: the number is the fact,
            // the colour is decoration (M43).
            Text(
              time,
              style: t.titleSmall!.copyWith(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: p.text,
                  fontFeatures: tabular),
            ),
            SizedBox(
              width: 56,
              child: Text(
                '$percent%',
                textAlign: TextAlign.right,
                style: t.bodyLarge!.copyWith(
                    fontSize: 17, color: p.text2, fontFeatures: tabular),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
