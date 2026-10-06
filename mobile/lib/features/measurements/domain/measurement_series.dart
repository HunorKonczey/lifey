import '../../../shared/widgets/charts/time_series_chart.dart';
import 'body_measurement.dart';
import '../../../core/format/parse_decimal.dart';

/// Smallest and largest value the add sheet accepts, in centimetres. The
/// backend allows (0, 300]; the floor here is 1 cm so a stray "0.5" typo is
/// caught on the device.
const double minMeasurementCm = 1;
const double maxMeasurementCm = 300;

/// Parses what the user typed — "82.5", "82,5", "82" — into centimetres,
/// rounded to one decimal, or null when it is not a value the sheet accepts.
double? parseMeasurementCm(String text) {
  final raw = parseDecimal(text);
  if (raw == null || !raw.isFinite) return null;
  final cm = (raw * 10).round() / 10;
  if (cm < minMeasurementCm || cm > maxMeasurementCm) return null;
  return cm;
}

/// One point per calendar day for [site], oldest first. When a day has more
/// than one entry the most recently recorded wins (docs/80 §6) — [all] is
/// ordered date desc, recordedAt desc (see `BodyMeasurementRepository.watchAll`),
/// so the first entry seen per day is that one.
List<TimeSeriesPoint> measurementSeries(List<BodyMeasurement> all, MeasurementSite site) {
  final latestPerDay = <DateTime, BodyMeasurement>{};
  for (final entry in all) {
    if (entry.site != site) continue;
    final local = entry.date.toLocal();
    latestPerDay.putIfAbsent(DateTime(local.year, local.month, local.day), () => entry);
  }
  final days = latestPerDay.keys.toList()..sort();
  return [for (final day in days) TimeSeriesPoint(date: day, value: latestPerDay[day]!.valueCm)];
}
