import 'package:flutter_test/flutter_test.dart';
import 'package:lifey/features/measurements/domain/body_measurement.dart';
import 'package:lifey/features/measurements/domain/measurement_series.dart';

BodyMeasurement _m(String id, DateTime date, MeasurementSite site, double cm, {DateTime? recordedAt}) =>
    BodyMeasurement(clientId: id, date: date, site: site, valueCm: cm, recordedAt: recordedAt ?? date);

void main() {
  group('parseMeasurementCm', () {
    test('accepts dot and comma decimals and rounds to one decimal', () {
      expect(parseMeasurementCm('82.5'), 82.5);
      expect(parseMeasurementCm('82,5'), 82.5);
      expect(parseMeasurementCm(' 82 '), 82);
      expect(parseMeasurementCm('82.46'), 82.5);
    });

    test('rejects non-numbers and values outside 1..300 cm', () {
      expect(parseMeasurementCm(''), isNull);
      expect(parseMeasurementCm('abc'), isNull);
      expect(parseMeasurementCm('0'), isNull);
      expect(parseMeasurementCm('0.9'), isNull);
      expect(parseMeasurementCm('300.1'), isNull);
      expect(parseMeasurementCm('Infinity'), isNull);
    });

    test('keeps the boundaries', () {
      expect(parseMeasurementCm('1'), 1);
      expect(parseMeasurementCm('300'), 300);
    });
  });

  group('measurementSeries', () {
    test('filters to the site, one point per day (latest recorded wins), oldest first', () {
      // Ordered date desc, recordedAt desc — as BodyMeasurementRepository.watchAll.
      final all = [
        _m('c', DateTime(2026, 6, 20), MeasurementSite.waist, 81),
        _m('b2', DateTime(2026, 6, 18), MeasurementSite.waist, 82, recordedAt: DateTime(2026, 6, 18, 20)),
        _m('b1', DateTime(2026, 6, 18), MeasurementSite.waist, 99, recordedAt: DateTime(2026, 6, 18, 8)),
        _m('arm', DateTime(2026, 6, 19), MeasurementSite.arm, 35),
        _m('a', DateTime(2026, 6, 1), MeasurementSite.waist, 84),
      ];

      final series = measurementSeries(all, MeasurementSite.waist);

      expect(series.map((p) => p.value), [84, 82, 81]);
      expect(series.map((p) => p.date), [DateTime(2026, 6, 1), DateTime(2026, 6, 18), DateTime(2026, 6, 20)]);
    });

    test('is empty when the site has no entries', () {
      expect(measurementSeries([_m('a', DateTime(2026, 6, 1), MeasurementSite.arm, 35)], MeasurementSite.hips), isEmpty);
    });
  });

  test('MeasurementSite.fromWire round-trips and returns null for an unknown name', () {
    for (final site in MeasurementSite.values) {
      expect(MeasurementSite.fromWire(site.wire), site);
    }
    expect(MeasurementSite.fromWire('ELBOW'), isNull);
  });
}
