import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifey/features/workouts/domain/route_encoder.dart';
import 'package:lifey/features/workouts/domain/track_filter.dart';
import 'package:lifey/features/workouts/presentation/widgets/route_painter.dart';

/// docs/cardio/54-cardio-gps-route-plan.md §6.1, C4a.6 — pure rendering
/// smoke tests on synthetic polylines (no GPS/device needed, matching every
/// other C4a step's Windows-testable pure-Dart/Flutter constraint).

TrackFilterTrailPoint _p(double lat, double lng, DateTime at) {
  return TrackFilterTrailPoint(latitude: lat, longitude: lng, recordedAt: at);
}

Future<void> _pump(WidgetTester tester, Widget child) async {
  await tester.pumpWidget(MaterialApp(home: Scaffold(body: child)));
}

void main() {
  final t0 = DateTime.utc(2026, 8, 13, 7, 0, 0);

  testWidgets('RoutePainter with a single-segment polyline renders without error', (tester) async {
    final trail = [for (var i = 0; i <= 10; i++) _p(47.5 + i * 0.0001, 19.05, t0.add(Duration(seconds: i)))];
    final polyline = encodeRoute(trail).polyline;

    await _pump(tester, RoutePainter(polyline: polyline));

    expect(tester.takeException(), isNull);
    expect(find.byType(RoutePainter), findsOneWidget);
  });

  testWidgets('RoutePainter with a multi-segment (gapped) polyline renders without error',
      (tester) async {
    final trail = [
      _p(47.5, 19.05, t0),
      _p(47.5001, 19.05, t0.add(const Duration(seconds: 10))),
      _p(47.6, 19.05, t0.add(const Duration(seconds: 200))), // >60s gap
      _p(47.6001, 19.05, t0.add(const Duration(seconds: 210))),
    ];
    final polyline = encodeRoute(trail).polyline;

    await _pump(tester, RoutePainter(polyline: polyline));

    expect(tester.takeException(), isNull);
  });

  testWidgets('RoutePainter with an empty polyline renders without error (nothing to draw)',
      (tester) async {
    await _pump(tester, const RoutePainter(polyline: ''));
    expect(tester.takeException(), isNull);
  });

  testWidgets('RoutePainter with a single-point trail renders without error', (tester) async {
    final polyline = encodeRoute([_p(47.5, 19.05, t0)]).polyline;
    await _pump(tester, RoutePainter(polyline: polyline));
    expect(tester.takeException(), isNull);
  });

  testWidgets('RouteThumbnail renders at its given size without error', (tester) async {
    final trail = [for (var i = 0; i <= 10; i++) _p(47.5 + i * 0.0001, 19.05, t0.add(Duration(seconds: i)))];
    final polyline = encodeRoute(trail).polyline;

    await _pump(tester, RouteThumbnail(polyline: polyline, size: 44));

    expect(tester.takeException(), isNull);
    expect(tester.getSize(find.byType(RouteThumbnail)), const Size(44, 44));
  });

  testWidgets('two RoutePainter/RouteThumbnail widgets sharing the same polyline read from the '
      'same memoized geometry without error', (tester) async {
    final trail = [for (var i = 0; i <= 10; i++) _p(47.5 + i * 0.0001, 19.05, t0.add(Duration(seconds: i)))];
    final polyline = encodeRoute(trail).polyline;

    await _pump(
      tester,
      Column(
        children: [
          RoutePainter(polyline: polyline),
          RouteThumbnail(polyline: polyline),
        ],
      ),
    );

    expect(tester.takeException(), isNull);
    expect(find.byType(RoutePainter), findsOneWidget);
    expect(find.byType(RouteThumbnail), findsOneWidget);
  });
}
