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

  group('heart-rate zones move as one block (C9.1 guard)', () {
    const watchZones = CardioMetrics(
      hrZone1Seconds: 300,
      hrZone2Seconds: 900,
      hrZone3Seconds: 1200,
      hrZone4Seconds: 900,
      hrZone5Seconds: 300,
    );

    test('a session with no zones at all takes the whole watch set', () {
      const onPhone = CardioMetrics(distanceMeters: 8000);

      final merged = onPhone.mergedWithWatchMeasurement(watchZones);

      expect(merged.hrZone1Seconds, 300);
      expect(merged.hrZone3Seconds, 1200);
      expect(merged.hrZone5Seconds, 300);
    });

    test('one zone already on the session keeps the whole phone set — no mixing', () {
      // The §9 failure this guard exists for: merging field by field would
      // pair a phone-measured Z1 with watch-measured Z2-Z5 from a *different*
      // measurement of the same session, and the five would then total more
      // time than the session lasted.
      const onPhone = CardioMetrics(hrZone1Seconds: 1800);

      final merged = onPhone.mergedWithWatchMeasurement(watchZones);

      expect(merged.hrZone1Seconds, 1800);
      expect(merged.hrZone2Seconds, isNull);
      expect(merged.hrZone3Seconds, isNull);
      expect(merged.hrZone4Seconds, isNull);
      expect(merged.hrZone5Seconds, isNull);
    });

    test('the block rule does not touch the other watch-measured fields', () {
      const onPhone = CardioMetrics(hrZone1Seconds: 1800);
      const fromWatch = CardioMetrics(
        distanceMeters: 8200,
        avgCadence: 172,
        hrZone2Seconds: 900,
      );

      final merged = onPhone.mergedWithWatchMeasurement(fromWatch);

      expect(merged.hrZone2Seconds, isNull, reason: 'zones stay with the phone');
      expect(merged.distanceMeters, 8200);
      expect(merged.avgCadence, 172);
    });
  });
}
