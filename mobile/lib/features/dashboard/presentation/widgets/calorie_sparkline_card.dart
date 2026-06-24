import 'dart:math';

import 'package:flutter/material.dart';

import '../../../../core/theme/app_tokens.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../shared/widgets/charts/time_series_chart.dart';

/// Compact "This week · calories" card shown on the dashboard.
///
/// Renders a spark-line (area fill + line + max-point dot) without any axis
/// labels or interactive elements. The average is shown as a badge in the
/// header row. Days with zero calories are included so the 7-day shape is
/// always complete.
class CalorieSparklineCard extends StatelessWidget {
  const CalorieSparklineCard({super.key, required this.points});

  final List<TimeSeriesPoint> points;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    final accent = context.metricColors.calories;

    final nonZero = points.where((p) => p.value > 0).toList();
    final avg = nonZero.isEmpty
        ? null
        : nonZero.fold(0.0, (s, p) => s + p.value) / nonZero.length;

    return Card(
      elevation: 0,
      color: theme.colorScheme.surfaceContainerHigh,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.card),
      ),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Text(
                  l10n.thisWeekCaloriesLabel,
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const Spacer(),
                if (avg != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: accent.withValues(alpha: 0.16),
                      borderRadius: BorderRadius.circular(99),
                    ),
                    child: Text(
                      l10n.avgCaloriesBadge(avg.round()),
                      style: TextStyle(
                        fontFamily: 'PlusJakartaSans',
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: accent,
                        height: 1.0,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 80,
              width: double.infinity,
              child: CustomPaint(
                painter: _SparklinePainter(
                  points: points,
                  lineColor: accent,
                  guideColor: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SparklinePainter extends CustomPainter {
  _SparklinePainter({
    required this.points,
    required this.lineColor,
    required this.guideColor,
  });

  final List<TimeSeriesPoint> points;
  final Color lineColor;
  final Color guideColor;

  static const _topPad = 8.0;
  static const _botPad = 4.0;
  static const _sidePad = 4.0;

  @override
  void paint(Canvas canvas, Size size) {
    if (points.isEmpty) return;

    final plotTop = _topPad;
    final plotBot = size.height - _botPad;
    final plotLeft = _sidePad;
    final plotRight = size.width - _sidePad;
    final plotH = plotBot - plotTop;
    final plotW = plotRight - plotLeft;

    final values = points.map((p) => p.value).toList();
    var lo = values.reduce(min);
    var hi = values.reduce(max);
    if (lo == hi) {
      lo -= 1;
      hi += 1;
    } else {
      final pad = (hi - lo) * 0.15;
      lo -= pad;
      hi += pad;
    }

    Offset offsetFor(int i) {
      final x = points.length == 1
          ? (plotLeft + plotRight) / 2
          : plotLeft + plotW * i / (points.length - 1);
      final y = plotBot - (values[i] - lo) / (hi - lo) * plotH;
      return Offset(x, y);
    }

    final offsets = [for (var i = 0; i < points.length; i++) offsetFor(i)];

    // Subtle horizontal guide lines at 1/3 and 2/3 of the plot area
    final guidePaint = Paint()
      ..color = guideColor
      ..strokeWidth = 1;
    canvas.drawLine(
      Offset(plotLeft, plotTop + plotH / 3),
      Offset(plotRight, plotTop + plotH / 3),
      guidePaint,
    );
    canvas.drawLine(
      Offset(plotLeft, plotTop + 2 * plotH / 3),
      Offset(plotRight, plotTop + 2 * plotH / 3),
      guidePaint,
    );

    // Area fill
    final areaPath = Path()..moveTo(offsets.first.dx, plotBot);
    for (final o in offsets) {
      areaPath.lineTo(o.dx, o.dy);
    }
    areaPath.lineTo(offsets.last.dx, plotBot);
    areaPath.close();
    canvas.drawPath(
      areaPath,
      Paint()
        ..color = lineColor.withValues(alpha: 0.12)
        ..style = PaintingStyle.fill,
    );

    // Line
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
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );

    // Highlighted dot on the max-value day
    final maxIdx = values.indexOf(values.reduce(max));
    canvas.drawCircle(
      offsets[maxIdx],
      5.0,
      Paint()..color = lineColor,
    );
  }

  @override
  bool shouldRepaint(_SparklinePainter old) =>
      old.points != points || old.lineColor != lineColor || old.guideColor != guideColor;
}
