import 'package:flutter/material.dart';

import '../../domain/elevation_profile.dart';

/// The real elevation profile (docs/cardio/60 C8.3, docs/cardio/61 §4 M40):
/// altitude against actual cumulative distance, gap-free segments joined by
/// **shaded bands** (not interpolated lines) wherever the GPS signal was
/// lost, and a tap-to-select point with no floating tooltip — M40 is
/// explicit that a tooltip would either overflow or cover the curve on a
/// 390 px screen. The three-number readout for a selected point is drawn by
/// the caller (`cardio_summary_screen.dart`), from the same [selectedIndex]
/// this widget is given — the same controlled-selection shape
/// `PaceBarChart`'s `selectedIndex`/`onBarTap` already uses for splits, so
/// one tap drives both a chart highlight and a card row simultaneously.
class ElevationProfileChart extends StatelessWidget {
  const ElevationProfileChart({
    super.key,
    required this.profile,
    required this.selectedIndex,
    required this.onPointTap,
    required this.gapLabel,
    this.height = 140,
  });

  final ElevationProfile profile;

  /// Index into [ElevationProfile.allPoints] — null when nothing is selected.
  final int? selectedIndex;
  final ValueChanged<int> onPointTap;

  /// The already-localized "hézag" caption drawn inside a wide-enough gap
  /// band — passed in rather than read from `AppLocalizations` here, so this
  /// widget stays as context-light as `RoutePainter`/`TimeSeriesChart`.
  final String gapLabel;

  final double height;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final points = profile.allPoints;

    return SizedBox(
      height: height,
      width: double.infinity,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final size = constraints.biggest;
          final geometry = _ElevationGeometry(profile, size);
          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapDown: points.isEmpty
                ? null
                : (details) {
                    final nearest = geometry.nearestIndex(details.localPosition);
                    if (nearest != null) onPointTap(nearest);
                  },
            child: CustomPaint(
              size: size,
              painter: _ElevationProfilePainter(
                geometry: geometry,
                selectedIndex: selectedIndex,
                gapLabel: gapLabel,
                lineColor: scheme.primary,
                areaColor: scheme.primary.withValues(alpha: 0.12),
                gridColor: scheme.outlineVariant,
                gapFillColor: scheme.secondary,
                selectedPointColor: scheme.secondary,
                peakColor: scheme.primary,
                labelStyle: Theme.of(context).textTheme.bodySmall!.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                gapLabelColor: scheme.onSurfaceVariant,
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Layout math for the plot area, shared by the painter and the tap handler
/// — same split `time_series_chart.dart`'s `_ChartGeometry` uses, so a tap
/// always resolves against exactly the geometry that was drawn.
class _ElevationGeometry {
  _ElevationGeometry(this.profile, this.size)
      : plotTop = _topPadding,
        plotBottom = size.height - _bottomPadding,
        plotLeft = _sidePadding,
        plotRight = size.width - _sidePadding {
    final points = profile.allPoints;
    if (points.isEmpty) {
      minY = 0;
      maxY = 1;
      return;
    }
    var lo = points.first.altitudeMeters;
    var hi = points.first.altitudeMeters;
    for (final p in points) {
      if (p.altitudeMeters < lo) lo = p.altitudeMeters;
      if (p.altitudeMeters > hi) hi = p.altitudeMeters;
    }
    if (lo == hi) {
      lo -= 1;
      hi += 1;
    } else {
      final pad = (hi - lo) * 0.15;
      lo -= pad;
      hi += pad;
    }
    minY = lo;
    maxY = hi;
  }

  final ElevationProfile profile;
  final Size size;

  static const _topPadding = 12.0;
  static const _bottomPadding = 12.0;
  static const _sidePadding = 4.0;

  final double plotTop;
  final double plotBottom;
  final double plotLeft;
  final double plotRight;
  late final double minY;
  late final double maxY;

  double get _totalDistance =>
      profile.totalDistanceMeters > 0 ? profile.totalDistanceMeters : 1;

  double xForDistance(double distanceMeters) =>
      plotLeft + (plotRight - plotLeft) * distanceMeters / _totalDistance;

  double yForAltitude(double altitude) =>
      plotBottom - (altitude - minY) / (maxY - minY) * (plotBottom - plotTop);

  Offset offsetFor(ElevationProfilePoint point) =>
      Offset(xForDistance(point.cumulativeDistanceMeters), yForAltitude(point.altitudeMeters));

  /// The vertex whose distance along the route is closest to the tapped x —
  /// a tap inside a gap band snaps to whichever real point sits nearer,
  /// never to a phantom point inside the gap itself.
  int? nearestIndex(Offset position) {
    final points = profile.allPoints;
    if (points.isEmpty) return null;
    final tappedDistance =
        (position.dx - plotLeft) / (plotRight - plotLeft) * _totalDistance;
    var bestIndex = 0;
    var bestDelta = (points[0].cumulativeDistanceMeters - tappedDistance).abs();
    for (var i = 1; i < points.length; i++) {
      final delta = (points[i].cumulativeDistanceMeters - tappedDistance).abs();
      if (delta < bestDelta) {
        bestDelta = delta;
        bestIndex = i;
      }
    }
    return bestIndex;
  }
}

class _ElevationProfilePainter extends CustomPainter {
  _ElevationProfilePainter({
    required this.geometry,
    required this.selectedIndex,
    required this.gapLabel,
    required this.lineColor,
    required this.areaColor,
    required this.gridColor,
    required this.gapFillColor,
    required this.selectedPointColor,
    required this.peakColor,
    required this.labelStyle,
    required this.gapLabelColor,
  });

  final _ElevationGeometry geometry;
  final int? selectedIndex;
  final String gapLabel;
  final Color lineColor;
  final Color areaColor;
  final Color gridColor;
  final Color gapFillColor;
  final Color selectedPointColor;
  final Color peakColor;
  final TextStyle labelStyle;
  final Color gapLabelColor;

  static const _dashLength = 4.0;
  static const _dashGap = 3.0;

  /// Below this pixel width the "hézag" caption would either not fit or
  /// crowd the band's own dashed borders — M40 doesn't specify a number, so
  /// this errs toward "no label" over an overlapping one.
  static const _minGapWidthForLabel = 36.0;

  @override
  void paint(Canvas canvas, Size size) {
    final profile = geometry.profile;
    if (profile.allPoints.isEmpty) return;

    // Baseline grid line, drawn first so everything else sits on top of it.
    canvas.drawLine(
      Offset(geometry.plotLeft, geometry.plotBottom),
      Offset(geometry.plotRight, geometry.plotBottom),
      Paint()
        ..color = gridColor
        ..strokeWidth = 1,
    );

    // Gap bands — proportional-width shaded rectangles with a dashed left/
    // right border, drawn before the segments so the segment lines and the
    // peak marker sit visually on top (M40: "a hézag sáv, nem vonal").
    for (final gap in profile.gaps) {
      final left = geometry.xForDistance(gap.startDistanceMeters);
      final right = geometry.xForDistance(gap.endDistanceMeters);
      final rect = Rect.fromLTRB(left, geometry.plotTop, right, geometry.plotBottom);
      canvas.drawRect(rect, Paint()..color = gapFillColor.withValues(alpha: 0.09));

      final borderPaint = Paint()
        ..color = gapFillColor.withValues(alpha: 0.6)
        ..strokeWidth = 1.5;
      _drawDashedLine(canvas, Offset(left, geometry.plotTop), Offset(left, geometry.plotBottom),
          borderPaint);
      _drawDashedLine(canvas, Offset(right, geometry.plotTop), Offset(right, geometry.plotBottom),
          borderPaint);

      if (right - left >= _minGapWidthForLabel) {
        _drawCenteredText(
          canvas,
          gapLabel,
          Offset((left + right) / 2, (geometry.plotTop + geometry.plotBottom) / 2),
          labelStyle.copyWith(color: gapLabelColor, fontWeight: FontWeight.w600),
        );
      }
    }

    // Each segment: filled area, then its own line on top — never bridged
    // across a gap by a straight line pretending to be real motion.
    for (final segment in profile.segments) {
      if (segment.isEmpty) continue;
      final offsets = [for (final p in segment) geometry.offsetFor(p)];

      if (offsets.length > 1) {
        final areaPath = Path()
          ..moveTo(offsets.first.dx, geometry.plotBottom)
          ..lineTo(offsets.first.dx, offsets.first.dy);
        for (final o in offsets.skip(1)) {
          areaPath.lineTo(o.dx, o.dy);
        }
        areaPath
          ..lineTo(offsets.last.dx, geometry.plotBottom)
          ..close();
        canvas.drawPath(areaPath, Paint()..color = areaColor..style = PaintingStyle.fill);

        final linePath = Path()..moveTo(offsets.first.dx, offsets.first.dy);
        for (final o in offsets.skip(1)) {
          linePath.lineTo(o.dx, o.dy);
        }
        canvas.drawPath(
          linePath,
          Paint()
            ..color = lineColor
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2.5
            ..strokeCap = StrokeCap.round,
        );
      }
    }

    // The peak: a marker drawn directly on the curve. Its caption is a
    // separate widget under the chart (M40: "a tengely alatt"), not drawn
    // here.
    final peak = profile.peak;
    if (peak != null) {
      final peakOffset = geometry.offsetFor(peak);
      canvas.drawCircle(peakOffset, 4.5, Paint()..color = peakColor);
      canvas.drawCircle(
        peakOffset,
        4.5,
        Paint()
          ..color = Colors.white.withValues(alpha: 0.9)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5,
      );
    }

    // The selected point: a drop-line to the axis plus a highlighted dot —
    // no floating tooltip (M40's explicit call).
    final index = selectedIndex;
    if (index != null && index < profile.allPoints.length) {
      final point = profile.allPoints[index];
      final offset = geometry.offsetFor(point);
      _drawDashedLine(
        canvas,
        Offset(offset.dx, offset.dy),
        Offset(offset.dx, geometry.plotBottom),
        Paint()
          ..color = selectedPointColor.withValues(alpha: 0.6)
          ..strokeWidth = 1.5,
      );
      canvas.drawCircle(offset, 6, Paint()..color = selectedPointColor);
    }
  }

  void _drawDashedLine(Canvas canvas, Offset start, Offset end, Paint paint) {
    final total = (end - start).distance;
    if (total == 0) return;
    final direction = (end - start) / total;
    var traveled = 0.0;
    while (traveled < total) {
      final segStart = start + direction * traveled;
      final segEnd = start + direction * (traveled + _dashLength).clamp(0.0, total);
      canvas.drawLine(segStart, segEnd, paint);
      traveled += _dashLength + _dashGap;
    }
  }

  void _drawCenteredText(Canvas canvas, String text, Offset center, TextStyle style) {
    final painter = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.center,
    )..layout();
    painter.paint(canvas, center - Offset(painter.width / 2, painter.height / 2));
  }

  @override
  bool shouldRepaint(_ElevationProfilePainter oldDelegate) {
    return oldDelegate.geometry.profile != geometry.profile ||
        oldDelegate.geometry.size != geometry.size ||
        oldDelegate.selectedIndex != selectedIndex;
  }
}
