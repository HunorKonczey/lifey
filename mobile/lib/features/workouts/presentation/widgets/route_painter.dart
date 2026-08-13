import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../domain/route_encoder.dart';

/// Draws a session's GPS route from its stored `route_polyline`
/// (docs/cardio/54-cardio-gps-route-plan.md §6.1, C4a.6) — the large form,
/// for `CardioSummaryScreen`. See `RouteThumbnail` below for the small,
/// session-card form; both share the same paint delegate and geometry cache.
///
/// Style mirrors `shared/widgets/charts/time_series_chart.dart`: theme
/// colors are read once here, in `build()`, and passed into the
/// `CustomPainter` as plain [Color]s — "pontosan úgy néz ki, mint a
/// TimeSeriesChart — egy vizuális nyelv" (§6.1). **No pace gradient** — the
/// doc itself calls that "opcionális"; this step ships the plain single-color
/// line, a deliberate, documented scope cut (see the C4a.6 kész write-up).
class RoutePainter extends StatelessWidget {
  const RoutePainter({super.key, required this.polyline, this.height = 220});

  final String polyline;
  final double height;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SizedBox(
      height: height,
      width: double.infinity,
      child: RepaintBoundary(
        child: CustomPaint(
          size: Size.infinite,
          painter: _RouteDelegate(
            geometry: _RouteGeometryCache.get(polyline),
            backgroundColor: scheme.surfaceContainer,
            routeColor: scheme.primary,
            endColor: scheme.secondary,
            strokeWidth: 3.5,
            margin: 20,
            showMarkers: true,
          ),
        ),
      ),
    );
  }
}

/// The session-list card's route badge — fixed small size, no start/end
/// markers (too small to read at that scale), same memoized geometry as
/// [RoutePainter] so scrolling the session list never re-decodes/
/// re-projects the same polyline twice (§6.1's "Teljesítmény" requirement).
class RouteThumbnail extends StatelessWidget {
  const RouteThumbnail({super.key, required this.polyline, this.size = 40});

  final String polyline;
  final double size;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return RepaintBoundary(
      child: CustomPaint(
        size: Size.square(size),
        painter: _RouteDelegate(
          geometry: _RouteGeometryCache.get(polyline),
          backgroundColor: scheme.surfaceContainerHigh,
          routeColor: scheme.primary,
          endColor: null,
          strokeWidth: 2,
          margin: 5,
          showMarkers: false,
        ),
      ),
    );
  }
}

/// Decoded + Web-Mercator-projected route geometry
/// (`x = lon`, `y = ln(tan(π/4 + lat/2))`) — matches EPSG:3857, the
/// projection a future C4b `flutter_map` overlay would also use (§6.1).
/// Kept in raw projected units (not yet fit to any particular canvas size);
/// [_Fit] does the per-paint bounding-box/aspect-ratio work, since the same
/// geometry can be painted at two different sizes (summary vs. thumbnail).
class _RouteGeometry {
  _RouteGeometry(String polyline) : segments = _project(decodeRouteSegments(polyline));

  final List<List<Offset>> segments;

  static List<List<Offset>> _project(List<List<(double, double, double)>> decoded) {
    return [
      for (final segment in decoded)
        [for (final (lat, lng, _) in segment) _mercator(lat, lng)],
    ];
  }

  static Offset _mercator(double lat, double lng) {
    final latRad = lat * math.pi / 180;
    return Offset(lng, math.log(math.tan(math.pi / 4 + latRad / 2)));
  }
}

/// Memoizes [_RouteGeometry] by the polyline string it was decoded from
/// (§6.1: "a dekódolt pontok memoizálva") — a plain [Map] is already a
/// `LinkedHashMap` in Dart, so eviction below is insertion-order (FIFO),
/// close enough to LRU for a session list that scrolls mostly forward.
class _RouteGeometryCache {
  static final Map<String, _RouteGeometry> _cache = {};
  static const _maxEntries = 50;

  static _RouteGeometry get(String polyline) {
    final cached = _cache[polyline];
    if (cached != null) return cached;
    if (_cache.length >= _maxEntries) {
      _cache.remove(_cache.keys.first);
    }
    return _cache[polyline] = _RouteGeometry(polyline);
  }
}

/// Fits a set of projected points into [size] preserving aspect ratio
/// ("contain", not stretch — unlike `TimeSeriesChart`'s independent X/Y
/// axes, a map-like route would look wrong distorted), centered, with an
/// inner [margin].
class _Fit {
  _Fit(List<Offset> points, Size size, {required double margin}) {
    var minX = points.first.dx, maxX = points.first.dx;
    var minY = points.first.dy, maxY = points.first.dy;
    for (final p in points) {
      if (p.dx < minX) minX = p.dx;
      if (p.dx > maxX) maxX = p.dx;
      if (p.dy < minY) minY = p.dy;
      if (p.dy > maxY) maxY = p.dy;
    }
    final dataWidth = maxX - minX;
    final dataHeight = maxY - minY;
    final availableWidth = math.max(1.0, size.width - margin * 2);
    final availableHeight = math.max(1.0, size.height - margin * 2);

    final double scale;
    if (dataWidth == 0 && dataHeight == 0) {
      scale = 1.0;
    } else if (dataWidth == 0) {
      scale = availableHeight / dataHeight;
    } else if (dataHeight == 0) {
      scale = availableWidth / dataWidth;
    } else {
      scale = math.min(availableWidth / dataWidth, availableHeight / dataHeight);
    }

    _minX = minX;
    _maxY = maxY; // Mercator y increases northward; canvas y increases downward — flip below.
    _scale = scale;
    _offsetX = (size.width - dataWidth * scale) / 2;
    _offsetY = (size.height - dataHeight * scale) / 2;
  }

  late final double _minX;
  late final double _maxY;
  late final double _scale;
  late final double _offsetX;
  late final double _offsetY;

  Offset project(Offset dataPoint) => Offset(
        _offsetX + (dataPoint.dx - _minX) * _scale,
        _offsetY + (_maxY - dataPoint.dy) * _scale,
      );
}

class _RouteDelegate extends CustomPainter {
  _RouteDelegate({
    required this.geometry,
    required this.backgroundColor,
    required this.routeColor,
    required this.endColor,
    required this.strokeWidth,
    required this.margin,
    required this.showMarkers,
  });

  final _RouteGeometry geometry;
  final Color backgroundColor;
  final Color routeColor;
  final Color? endColor;
  final double strokeWidth;
  final double margin;
  final bool showMarkers;

  static const _dashLength = 5.0;
  static const _dashGap = 4.0;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRRect(
      RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(12)),
      Paint()..color = backgroundColor,
    );

    final segments = geometry.segments;
    final allPoints = [for (final s in segments) ...s];
    if (allPoints.isEmpty) return;
    final fit = _Fit(allPoints, size, margin: margin);

    // Dashed bridges between consecutive segments — each gap is a signal
    // loss (§4.3), so the connection is drawn, deliberately, as uncertain
    // rather than a plain solid line.
    if (segments.length > 1) {
      final dashPaint = Paint()
        ..color = routeColor.withValues(alpha: 0.55)
        ..strokeWidth = strokeWidth * 0.6
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round;
      for (var i = 1; i < segments.length; i++) {
        final prevSegment = segments[i - 1];
        final currSegment = segments[i];
        if (prevSegment.isEmpty || currSegment.isEmpty) continue;
        _drawDashedLine(canvas, fit.project(prevSegment.last), fit.project(currSegment.first), dashPaint);
      }
    }

    final routePaint = Paint()
      ..color = routeColor
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    for (final segment in segments) {
      if (segment.length < 2) continue;
      final start = fit.project(segment.first);
      final path = Path()..moveTo(start.dx, start.dy);
      for (final point in segment.skip(1)) {
        final p = fit.project(point);
        path.lineTo(p.dx, p.dy);
      }
      canvas.drawPath(path, routePaint);
    }

    if (showMarkers) {
      final start = fit.project(segments.first.first);
      final end = fit.project(segments.last.last);
      canvas.drawCircle(start, 5, Paint()..color = backgroundColor);
      canvas.drawCircle(
        start,
        5,
        Paint()
          ..color = routeColor
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2,
      );
      canvas.drawCircle(end, 5, Paint()..color = endColor ?? routeColor);
    }
  }

  void _drawDashedLine(Canvas canvas, Offset start, Offset end, Paint paint) {
    final total = (end - start).distance;
    if (total == 0) return;
    final direction = (end - start) / total;
    var traveled = 0.0;
    while (traveled < total) {
      final segStart = start + direction * traveled;
      final segEnd = start + direction * math.min(traveled + _dashLength, total);
      canvas.drawLine(segStart, segEnd, paint);
      traveled += _dashLength + _dashGap;
    }
  }

  @override
  bool shouldRepaint(_RouteDelegate oldDelegate) {
    return oldDelegate.geometry != geometry ||
        oldDelegate.backgroundColor != backgroundColor ||
        oldDelegate.routeColor != routeColor ||
        oldDelegate.endColor != endColor;
  }
}
