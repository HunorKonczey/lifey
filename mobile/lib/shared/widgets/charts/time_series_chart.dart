import 'package:flutter/material.dart';

/// A single (date, value) sample plotted by [TimeSeriesChart].
class TimeSeriesPoint {
  const TimeSeriesPoint({required this.date, required this.value});

  final DateTime date;
  final double value;
}

/// Generic line chart: dates along the X axis, a numeric value along the Y
/// axis, points connected by a single line. Feature-agnostic — callers
/// (weight, statistics, and later other daily metrics) supply the points and
/// label formatters, this widget only draws.
///
/// Only the first, last, and a thinned-out subset of in-between dates are
/// labelled, since a dense daily series would otherwise overlap. Tapping a
/// point shows a tooltip with its exact value + date; tapping the same point
/// again, or another one, closes or moves the tooltip respectively.
class TimeSeriesChart extends StatefulWidget {
  const TimeSeriesChart({
    super.key,
    required this.points,
    required this.dateLabelBuilder,
    this.valueLabelBuilder,
    this.deltaLabelBuilder,
    this.height = 220,
    this.showDeltaLabels = false,
    this.goalValue,
  });

  final List<TimeSeriesPoint> points;
  final String Function(DateTime date) dateLabelBuilder;

  /// Formats a single point's exact value for the tap-to-reveal tooltip
  /// (e.g. "72.4 kg"). Defaults to one decimal place when omitted.
  final String Function(double value)? valueLabelBuilder;

  /// Formats the change between two consecutive points (e.g. "+0.3"). Only
  /// used when [showDeltaLabels] is true.
  final String Function(double delta)? deltaLabelBuilder;
  final double height;
  final bool showDeltaLabels;

  /// When non-null, a dashed horizontal reference line is drawn at this Y
  /// value — used to show daily goals (e.g. step target).
  final double? goalValue;

  @override
  State<TimeSeriesChart> createState() => _TimeSeriesChartState();
}

class _TimeSeriesChartState extends State<TimeSeriesChart> {
  int? _selectedIndex;

  @override
  void didUpdateWidget(TimeSeriesChart oldWidget) {
    super.didUpdateWidget(oldWidget);
    // The selected index is meaningless against a different series (e.g.
    // after switching metric/range) — drop it rather than highlighting the
    // wrong point or pointing at one that no longer exists.
    if (oldWidget.points != widget.points) {
      _selectedIndex = null;
    }
  }

  void _handleTapDown(TapDownDetails details, Size size) {
    final geometry = _ChartGeometry(widget.points, size);
    final nearest = geometry.nearestIndex(details.localPosition);
    setState(() => _selectedIndex = _selectedIndex == nearest ? null : nearest);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final valueLabelBuilder = widget.valueLabelBuilder ?? (v) => v.toStringAsFixed(1);
    final selectedIndex = _selectedIndex;

    return SizedBox(
      height: widget.height,
      width: double.infinity,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final size = constraints.biggest;
          final geometry = _ChartGeometry(widget.points, size, goalValue: widget.goalValue);
          return Stack(
            clipBehavior: Clip.none,
            children: [
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTapDown:
                    widget.points.isEmpty ? null : (details) => _handleTapDown(details, size),
                child: CustomPaint(
                  size: size,
                  painter: _TimeSeriesChartPainter(
                    points: widget.points,
                    dateLabelBuilder: widget.dateLabelBuilder,
                    deltaLabelBuilder: widget.showDeltaLabels ? widget.deltaLabelBuilder : null,
                    selectedIndex: selectedIndex,
                    goalValue: widget.goalValue,
                    lineColor: theme.colorScheme.primary,
                    pointColor: theme.colorScheme.primary,
                    selectedPointColor: theme.colorScheme.secondary,
                    goalLineColor: theme.colorScheme.tertiary,
                    gridColor: theme.colorScheme.outlineVariant,
                    labelStyle: theme.textTheme.bodySmall!.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    positiveDeltaColor: theme.colorScheme.error,
                    negativeDeltaColor: theme.colorScheme.tertiary,
                  ),
                ),
              ),
              if (selectedIndex != null && selectedIndex < widget.points.length)
                _PointTooltip(
                  geometry: geometry,
                  index: selectedIndex,
                  valueText: valueLabelBuilder(widget.points[selectedIndex].value),
                  dateText: widget.dateLabelBuilder(widget.points[selectedIndex].date),
                ),
            ],
          );
        },
      ),
    );
  }
}

/// The tap-to-reveal tooltip, positioned above the selected point using the
/// same [_ChartGeometry] the painter draws from — a real widget (rather than
/// canvas-drawn text) so its content is inspectable in tests and by
/// accessibility tooling.
class _PointTooltip extends StatelessWidget {
  const _PointTooltip({
    required this.geometry,
    required this.index,
    required this.valueText,
    required this.dateText,
  });

  final _ChartGeometry geometry;
  final int index;
  final String valueText;
  final String dateText;

  static const _width = 120.0;
  static const _gap = 10.0;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final anchor = geometry.offsetFor(index);
    final left = (anchor.dx - _width / 2).clamp(geometry.plotLeft, geometry.plotRight - _width);

    return Positioned(
      left: left,
      bottom: geometry.size.height - anchor.dy + _gap,
      width: _width,
      child: IgnorePointer(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          decoration: BoxDecoration(
            color: theme.colorScheme.inverseSurface,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                valueText,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onInverseSurface,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                dateText,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onInverseSurface.withValues(alpha: 0.8),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Shared layout math for the chart's plot area: where the X axis sits,
/// where each point lands. The painter, the tap handler, and the tooltip
/// all build one of these for the same [Size], so a tap and its tooltip are
/// always positioned against exactly the geometry that was drawn.
class _ChartGeometry {
  _ChartGeometry(this.points, this.size, {this.goalValue})
      : plotTop = _topPadding,
        plotBottom = size.height - _bottomPadding,
        plotLeft = _sidePadding,
        plotRight = size.width - _sidePadding {
    if (points.isEmpty) {
      minY = goalValue ?? 0;
      maxY = goalValue != null ? goalValue! + 1 : 0;
      return;
    }
    final dataValues = [
      ...points.map((p) => p.value),
      if (goalValue != null) goalValue!,
    ];
    var lo = dataValues.reduce((a, b) => a < b ? a : b);
    var hi = dataValues.reduce((a, b) => a > b ? a : b);
    if (lo == hi) {
      lo -= 1;
      hi += 1;
    } else {
      final pad = (hi - lo) * 0.1;
      lo -= pad;
      hi += pad;
    }
    minY = lo;
    maxY = hi;
  }

  final double? goalValue;

  static const _topPadding = 24.0;
  static const _bottomPadding = 24.0;
  static const _sidePadding = 8.0;

  final List<TimeSeriesPoint> points;
  final Size size;
  final double plotTop;
  final double plotBottom;
  final double plotLeft;
  final double plotRight;
  late final double minY;
  late final double maxY;

  double xFor(int index) {
    if (points.length == 1) return (plotLeft + plotRight) / 2;
    return plotLeft + (plotRight - plotLeft) * index / (points.length - 1);
  }

  double yFor(double value) {
    return plotBottom - (value - minY) / (maxY - minY) * (plotBottom - plotTop);
  }

  Offset offsetFor(int index) => Offset(xFor(index), yFor(points[index].value));

  /// Index of the point whose plotted position is closest to [position].
  int nearestIndex(Offset position) {
    var bestIndex = 0;
    var bestDistance = double.infinity;
    for (var i = 0; i < points.length; i++) {
      final distance = (offsetFor(i) - position).distanceSquared;
      if (distance < bestDistance) {
        bestDistance = distance;
        bestIndex = i;
      }
    }
    return bestIndex;
  }
}

class _TimeSeriesChartPainter extends CustomPainter {
  _TimeSeriesChartPainter({
    required this.points,
    required this.dateLabelBuilder,
    required this.deltaLabelBuilder,
    required this.selectedIndex,
    required this.goalValue,
    required this.lineColor,
    required this.pointColor,
    required this.selectedPointColor,
    required this.goalLineColor,
    required this.gridColor,
    required this.labelStyle,
    required this.positiveDeltaColor,
    required this.negativeDeltaColor,
  });

  final List<TimeSeriesPoint> points;
  final String Function(DateTime date) dateLabelBuilder;
  final String Function(double delta)? deltaLabelBuilder;
  final int? selectedIndex;
  final double? goalValue;
  final Color lineColor;
  final Color pointColor;
  final Color selectedPointColor;
  final Color goalLineColor;
  final Color gridColor;
  final TextStyle labelStyle;
  final Color positiveDeltaColor;
  final Color negativeDeltaColor;

  static const _maxDateLabels = 6;

  @override
  void paint(Canvas canvas, Size size) {
    if (points.isEmpty) return;

    final geometry = _ChartGeometry(points, size, goalValue: goalValue);

    // Dashed goal line drawn behind the data line so data reads on top.
    if (goalValue != null) {
      final goalY = geometry.yFor(goalValue!);
      final dashPaint = Paint()
        ..color = goalLineColor.withValues(alpha: 0.7)
        ..strokeWidth = 1.5
        ..style = PaintingStyle.stroke;
      const dashLen = 6.0;
      const gapLen = 4.0;
      var x = geometry.plotLeft;
      while (x < geometry.plotRight) {
        final end = (x + dashLen).clamp(0.0, geometry.plotRight);
        canvas.drawLine(Offset(x, goalY), Offset(end, goalY), dashPaint);
        x += dashLen + gapLen;
      }
    }

    // Baseline grid line.
    canvas.drawLine(
      Offset(geometry.plotLeft, geometry.plotBottom),
      Offset(geometry.plotRight, geometry.plotBottom),
      Paint()
        ..color = gridColor
        ..strokeWidth = 1,
    );

    final offsets = [for (var i = 0; i < points.length; i++) geometry.offsetFor(i)];

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

    for (var i = 0; i < offsets.length; i++) {
      final isSelected = i == selectedIndex;
      canvas.drawCircle(
        offsets[i],
        isSelected ? 5.5 : 3.5,
        Paint()..color = isSelected ? selectedPointColor : pointColor,
      );
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
        Offset(geometry.xFor(i), geometry.plotBottom + 6),
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
        oldDelegate.selectedIndex != selectedIndex ||
        oldDelegate.goalValue != goalValue ||
        (oldDelegate.deltaLabelBuilder == null) != (deltaLabelBuilder == null);
  }
}

enum _HAlign { start, center, end }
