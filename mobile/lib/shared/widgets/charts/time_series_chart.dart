import 'package:flutter/material.dart';

/// A single (date, value) sample plotted by [TimeSeriesChart].
class TimeSeriesPoint {
  const TimeSeriesPoint({required this.date, required this.value});

  final DateTime date;
  final double value;
}

/// Generic line chart: dates along the X axis, a numeric value along the Y
/// axis, points connected by a single line. Feature-agnostic — callers
/// (weight, and later other daily metrics) supply the points and label
/// formatters, this widget only draws.
///
/// Only the first, last, and a thinned-out subset of in-between dates are
/// labelled, since a dense daily series would otherwise overlap.
class TimeSeriesChart extends StatelessWidget {
  const TimeSeriesChart({
    super.key,
    required this.points,
    required this.dateLabelBuilder,
    this.deltaLabelBuilder,
    this.height = 220,
    this.showDeltaLabels = false,
  });

  final List<TimeSeriesPoint> points;
  final String Function(DateTime date) dateLabelBuilder;

  /// Formats the change between two consecutive points (e.g. "+0.3"). Only
  /// used when [showDeltaLabels] is true.
  final String Function(double delta)? deltaLabelBuilder;
  final double height;
  final bool showDeltaLabels;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SizedBox(
      height: height,
      width: double.infinity,
      child: CustomPaint(
        painter: _TimeSeriesChartPainter(
          points: points,
          dateLabelBuilder: dateLabelBuilder,
          deltaLabelBuilder: showDeltaLabels ? deltaLabelBuilder : null,
          lineColor: theme.colorScheme.primary,
          pointColor: theme.colorScheme.primary,
          gridColor: theme.colorScheme.outlineVariant,
          labelStyle: theme.textTheme.bodySmall!.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
          positiveDeltaColor: theme.colorScheme.error,
          negativeDeltaColor: theme.colorScheme.tertiary,
        ),
      ),
    );
  }
}

class _TimeSeriesChartPainter extends CustomPainter {
  _TimeSeriesChartPainter({
    required this.points,
    required this.dateLabelBuilder,
    required this.deltaLabelBuilder,
    required this.lineColor,
    required this.pointColor,
    required this.gridColor,
    required this.labelStyle,
    required this.positiveDeltaColor,
    required this.negativeDeltaColor,
  });

  final List<TimeSeriesPoint> points;
  final String Function(DateTime date) dateLabelBuilder;
  final String Function(double delta)? deltaLabelBuilder;
  final Color lineColor;
  final Color pointColor;
  final Color gridColor;
  final TextStyle labelStyle;
  final Color positiveDeltaColor;
  final Color negativeDeltaColor;

  static const _topPadding = 24.0;
  static const _bottomPadding = 24.0;
  static const _sidePadding = 8.0;
  static const _maxDateLabels = 6;

  @override
  void paint(Canvas canvas, Size size) {
    if (points.isEmpty) return;

    final plotTop = _topPadding;
    final plotBottom = size.height - _bottomPadding;
    final plotLeft = _sidePadding;
    final plotRight = size.width - _sidePadding;

    final values = points.map((p) => p.value).toList();
    var minY = values.reduce((a, b) => a < b ? a : b);
    var maxY = values.reduce((a, b) => a > b ? a : b);
    if (minY == maxY) {
      minY -= 1;
      maxY += 1;
    } else {
      final pad = (maxY - minY) * 0.1;
      minY -= pad;
      maxY += pad;
    }

    double xFor(int index) {
      if (points.length == 1) return (plotLeft + plotRight) / 2;
      return plotLeft + (plotRight - plotLeft) * index / (points.length - 1);
    }

    double yFor(double value) {
      return plotBottom - (value - minY) / (maxY - minY) * (plotBottom - plotTop);
    }

    // Baseline grid line.
    canvas.drawLine(
      Offset(plotLeft, plotBottom),
      Offset(plotRight, plotBottom),
      Paint()
        ..color = gridColor
        ..strokeWidth = 1,
    );

    final offsets = [
      for (var i = 0; i < points.length; i++) Offset(xFor(i), yFor(points[i].value)),
    ];

    if (offsets.length > 1) {
      final path = Path()..moveTo(offsets.first.dx, offsets.first.dy);
      for (final offset in offsets.skip(1)) {
        path.lineTo(offset.dx, offset.dy);
      }
      canvas.drawPath(
        path,
        Paint()
          ..color = lineColor
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.5
          ..strokeCap = StrokeCap.round,
      );
    }

    for (final offset in offsets) {
      canvas.drawCircle(offset, 3.5, Paint()..color = pointColor);
    }

    if (deltaLabelBuilder != null) {
      for (var i = 1; i < points.length; i++) {
        final delta = points[i].value - points[i - 1].value;
        if (delta == 0) continue;
        final mid = Offset(
          (offsets[i - 1].dx + offsets[i].dx) / 2,
          (offsets[i - 1].dy + offsets[i].dy) / 2,
        );
        _drawText(
          canvas,
          deltaLabelBuilder!(delta),
          mid.translate(0, -14),
          labelStyle.copyWith(
            color: delta > 0 ? positiveDeltaColor : negativeDeltaColor,
            fontWeight: FontWeight.w600,
          ),
        );
      }
    }

    final labelIndexes = _labelIndexes(points.length);
    for (final i in labelIndexes) {
      _drawText(
        canvas,
        dateLabelBuilder(points[i].date),
        Offset(xFor(i), plotBottom + 6),
        labelStyle,
        align: i == 0
            ? _HAlign.start
            : i == points.length - 1
                ? _HAlign.end
                : _HAlign.center,
      );
    }
  }

  /// Picks at most [_maxDateLabels] indexes, always including the first and
  /// last point, evenly spaced in between.
  List<int> _labelIndexes(int count) {
    if (count <= _maxDateLabels) return List.generate(count, (i) => i);
    final step = (count - 1) / (_maxDateLabels - 1);
    return [for (var i = 0; i < _maxDateLabels; i++) (i * step).round()];
  }

  void _drawText(
    Canvas canvas,
    String text,
    Offset anchor,
    TextStyle style, {
    _HAlign align = _HAlign.center,
  }) {
    final painter = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: TextDirection.ltr,
    )..layout();
    final dx = switch (align) {
      _HAlign.start => anchor.dx,
      _HAlign.center => anchor.dx - painter.width / 2,
      _HAlign.end => anchor.dx - painter.width,
    };
    painter.paint(canvas, Offset(dx, anchor.dy));
  }

  @override
  bool shouldRepaint(_TimeSeriesChartPainter oldDelegate) {
    return oldDelegate.points != points ||
        oldDelegate.lineColor != lineColor ||
        (oldDelegate.deltaLabelBuilder == null) != (deltaLabelBuilder == null);
  }
}

enum _HAlign { start, center, end }
