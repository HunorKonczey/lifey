import 'package:flutter/material.dart';

import '../../../../core/format/cardio_formatter.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/hr_zone_breakdown.dart';

/// M43's heart-rate zone panel: a 22 px stacked bar, a verdict chip, and one
/// row per zone.
///
/// **One component for every cardio type** (docs/cardio/60 Q-D7) — a run, a
/// bike session and a match all get the identical panel; only *where* the
/// summary places it differs by family. It is the first thing to display the
/// `hrZone1..5Seconds` columns, which have been carried from the watch all
/// the way to the domain since C5 without ever being shown.
///
/// Two accessibility rules from the frame, both load-bearing:
/// - the verdict is **said in words** in the header chip, because the bar's
///   colours alone are not readable by a colour-blind user;
/// - **the numbers are always full contrast** — colour appears only on the
///   zone code chip and the small per-row bar, never on the time or the
///   percentage.
class HrZonePanel extends StatelessWidget {
  const HrZonePanel({super.key, required this.breakdown});

  final HrZoneBreakdown breakdown;

  /// Cool-to-warm ramp, one step per zone. Local to this widget rather than in
  /// `AppMetricColors`: these five are only ever used together, as a scale —
  /// unlike the metric colours, which are each an identity for one metric.
  static const _zoneColors = <Color>[
    Color(0xFF6E8FA8), // Z1 warm-up
    Color(0xFF5FA88C), // Z2 base
    Color(0xFFD8B35A), // Z3 tempo
    Color(0xFFD98A4E), // Z4 threshold
    Color(0xFFC4564E), // Z5 maximum
  ];

  String _zoneName(AppLocalizations l10n, int zone) => switch (zone) {
        1 => l10n.hrZone1Name,
        2 => l10n.hrZone2Name,
        3 => l10n.hrZone3Name,
        4 => l10n.hrZone4Name,
        _ => l10n.hrZone5Name,
      };

  String _verdict(AppLocalizations l10n) => switch (breakdown.intensity) {
        HrZoneIntensity.hard => l10n.hrZoneVerdictHard,
        HrZoneIntensity.balanced => l10n.hrZoneVerdictBalanced,
        HrZoneIntensity.easy => l10n.hrZoneVerdictEasy,
      };

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final endLabelStyle = TextStyle(fontSize: 10, color: scheme.outline);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                l10n.hrZonesSectionLabel,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.2,
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ),
            _VerdictChip(
              label: _verdict(l10n),
              color: _zoneColors[breakdown.intensity == HrZoneIntensity.hard ? 4 : 2],
            ),
          ],
        ),
        const SizedBox(height: 12),
        _StackedZoneBar(
          breakdown: breakdown,
          colors: _zoneColors,
          hatchColor: scheme.outlineVariant,
        ),
        const SizedBox(height: 6),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(l10n.hrZoneEasyEndLabel, style: endLabelStyle),
            Text(l10n.hrZoneHardEndLabel, style: endLabelStyle),
          ],
        ),
        if (breakdown.isPartial) ...[
          const SizedBox(height: 10),
          Row(
            children: [
              Icon(Icons.timelapse, size: 13, color: scheme.outline),
              const SizedBox(width: 6),
              Text(
                l10n.hrZonePartialCoverage(
                  (breakdown.coverageFraction * 100).round().toString(),
                ),
                style: TextStyle(fontSize: 10.5, color: scheme.outline),
              ),
            ],
          ),
        ],
        const SizedBox(height: 14),
        for (final slice in breakdown.slices)
          _ZoneRow(
            slice: slice,
            name: _zoneName(l10n, slice.zone),
            color: _zoneColors[slice.zone - 1],
          ),
        const SizedBox(height: 4),
        Text(
          l10n.hrZoneSourceNote,
          style: TextStyle(fontSize: 10, height: 1.35, color: scheme.outline),
        ),
      ],
    );
  }
}

class _VerdictChip extends StatelessWidget {
  const _VerdictChip({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.local_fire_department, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            // Full contrast, like every other number/word in this panel — the
            // colour is carried by the icon and the wash, not the text.
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w800,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
        ],
      ),
    );
  }
}

/// The 22 px stacked bar. Zone slices fill the measured part of the track; an
/// unmeasured remainder is **hatched**, never stretched over (M43's partial
/// state) — stretching would claim heart-rate data for minutes that have
/// none.
class _StackedZoneBar extends StatelessWidget {
  const _StackedZoneBar({
    required this.breakdown,
    required this.colors,
    required this.hatchColor,
  });

  final HrZoneBreakdown breakdown;
  final List<Color> colors;
  final Color hatchColor;

  @override
  Widget build(BuildContext context) {
    final coverage = breakdown.coverageFraction;
    return ClipRRect(
      borderRadius: BorderRadius.circular(6),
      child: SizedBox(
        height: 22,
        child: Row(
          children: [
            for (final slice in breakdown.slices)
              if (slice.fraction > 0)
                Expanded(
                  // Integer-ish flex from a 0..1 fraction: scaled up so small
                  // slices survive rounding rather than vanishing.
                  flex: (slice.fraction * coverage * 10000).round().clamp(1, 1 << 30),
                  child: ColoredBox(color: colors[slice.zone - 1]),
                ),
            if (breakdown.isPartial)
              Expanded(
                flex: ((1 - coverage) * 10000).round().clamp(1, 1 << 30),
                child: CustomPaint(painter: _HatchPainter(color: hatchColor)),
              ),
          ],
        ),
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
      Offset.zero & size,
      Paint()..color = color.withValues(alpha: 0.35),
    );
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

/// One row: `Z3` chip · zone name · a small share bar · time · percentage.
/// Every one of the five is listed, including the untouched ones — seeing that
/// no time was spent at threshold is information, not an empty row.
class _ZoneRow extends StatelessWidget {
  const _ZoneRow({required this.slice, required this.name, required this.color});

  final HrZoneSlice slice;
  final String name;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final empty = slice.seconds <= 0;
    return Padding(
      padding: const EdgeInsets.only(bottom: 9),
      child: Row(
        children: [
          Container(
            width: 24,
            padding: const EdgeInsets.symmetric(vertical: 2),
            decoration: BoxDecoration(
              color: color.withValues(alpha: empty ? 0.10 : 0.22),
              borderRadius: BorderRadius.circular(5),
            ),
            child: Text(
              'Z${slice.zone}',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w800,
                color: empty ? scheme.outline : scheme.onSurface,
              ),
            ),
          ),
          const SizedBox(width: 9),
          SizedBox(
            width: 74,
            child: Text(
              name,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 11.5,
                color: empty ? scheme.outline : scheme.onSurfaceVariant,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: Container(
                height: 8,
                color: scheme.surfaceContainer,
                child: FractionallySizedBox(
                  alignment: Alignment.centerLeft,
                  widthFactor: slice.fraction.clamp(0.0, 1.0),
                  child: ColoredBox(color: color),
                ),
              ),
            ),
          ),
          const SizedBox(width: 9),
          SizedBox(
            width: 44,
            child: Text(
              CardioFormatter.duration(Duration(seconds: slice.seconds)),
              textAlign: TextAlign.right,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                // Full contrast even for an untouched zone: the number is the
                // fact, the colour is decoration (M43).
                color: empty ? scheme.outline : scheme.onSurface,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 34,
            child: Text(
              '${(slice.fraction * 100).round()}%',
              textAlign: TextAlign.right,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: empty ? scheme.outline : scheme.onSurfaceVariant,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
