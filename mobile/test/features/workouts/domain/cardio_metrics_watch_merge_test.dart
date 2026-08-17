import 'package:flutter_test/flutter_test.dart';
import 'package:lifey/features/workouts/domain/workout_session.dart';

/// The seam a watch-measured metric crosses to reach an already-persisted
/// phone session: `ExerciseService.cardioSummaryJson()` (Wear OS) and its
/// watchOS counterpart write a JSON block, `CardioMetrics.fromJson` decodes
/// it, and `mergedWithWatchMeasurement` folds it into what the phone already
/// has — docs/cardio/55 §4.3 ("csak akkor írják felül, ha a telefonnak nincs
/// saját mérése") and docs/cardio/51 R8 ("a kézi érték mindig nyer").
///
/// Cadence (docs/cardio/60 C6.5) is the newest field to travel this path, and
/// the JSON keys below are exactly the ones the Wear OS service emits.

void main() {
  group('CardioMetrics.fromJson — the watch summary wire shape', () {
    test('decodes the cadence keys the watch sends', () {
      final metrics = CardioMetrics.fromJson(const {
        'distanceMeters': 8200.0,
        'distanceSource': 'DEVICE',
        'elevationGainMeters': 42.0,
        'avgCadence': 172.0,
        'maxCadence': 186.0,
      });

      expect(metrics.avgCadence, 172.0);
      expect(metrics.maxCadence, 186.0);
    });

    test('a summary with no cadence keys leaves them null, not zero', () {
      // What a walk, a hike, or a device without the sensor sends: the keys
      // are absent entirely (the Kotlin side uses putOpt).
      final metrics = CardioMetrics.fromJson(const {
        'distanceMeters': 3000.0,
        'distanceSource': 'DEVICE',
      });

      expect(metrics.avgCadence, isNull);
      expect(metrics.maxCadence, isNull);
    });
  });

  group('mergedWithWatchMeasurement', () {
    const fromWatch = CardioMetrics(
      distanceMeters: 8200,
      avgCadence: 172,
      maxCadence: 186,
    );

    test('the watch fills a cadence the phone never measured', () {
      const onPhone = CardioMetrics(distanceMeters: 8000, distanceSource: 'MEASURED');

      final merged = onPhone.mergedWithWatchMeasurement(fromWatch);

      expect(merged.avgCadence, 172);
      expect(merged.maxCadence, 186);
    });

    test('a cadence already on the session survives the merge', () {
      const onPhone = CardioMetrics(avgCadence: 168, maxCadence: 180);

      final merged = onPhone.mergedWithWatchMeasurement(fromWatch);

      expect(merged.avgCadence, 168);
      expect(merged.maxCadence, 180);
    });

    test('the phone-measured distance keeps its own source tag', () {
      // The watch filling cadence must not retag a distance the phone
      // measured itself — R8's rule, checked here because cadence and
      // distance ride in the same payload.
      const onPhone = CardioMetrics(distanceMeters: 8000, distanceSource: 'MEASURED');

      final merged = onPhone.mergedWithWatchMeasurement(fromWatch);

      expect(merged.distanceMeters, 8000);
      expect(merged.distanceSource, 'MEASURED');
      expect(merged.avgCadence, 172);
    });

    test('a distance the watch alone measured is tagged DEVICE', () {
      const onPhone = CardioMetrics();

      final merged = onPhone.mergedWithWatchMeasurement(fromWatch);

      expect(merged.distanceMeters, 8200);
      expect(merged.distanceSource, 'DEVICE');
    });
  });
}
