import 'package:health/health.dart';

import '../../features/vitals/domain/daily_vitals.dart';
import 'health_cardio_workout.dart' show isLifeyHealthSource;

/// The HRV method a store data type measures (docs/integrations/89 D-G8), or
/// null for a type that is not HRV. HealthKit stores SDNN, Health Connect
/// stores RMSSD; the method comes from the type, never from the platform, so
/// a value can only ever carry the method it was measured with.
HrvMethod? hrvMethodFor(HealthDataType type) => switch (type) {
      HealthDataType.HEART_RATE_VARIABILITY_SDNN => HrvMethod.sdnn,
      HealthDataType.HEART_RATE_VARIABILITY_RMSSD => HrvMethod.rmssd,
      _ => null,
    };

/// One vitals reading from the store: a resting heart rate when [hrvMethod]
/// is null, otherwise an HRV value measured by [hrvMethod].
class VitalsSample {
  const VitalsSample({required this.at, required this.value, this.hrvMethod});

  final DateTime at;

  /// Beats per minute for a resting heart rate, milliseconds for HRV.
  final double value;
  final HrvMethod? hrvMethod;

  bool get isRestingHr => hrvMethod == null;
}

/// Converts a store data point to a [VitalsSample], or null when it is not a
/// vitals type, has no numeric value, or Lifey wrote it (D-G4; Lifey writes
/// no vitals today).
VitalsSample? vitalsSampleFromPoint(HealthDataPoint point) {
  if (isLifeyHealthSource(point.sourceId) || isLifeyHealthSource(point.sourceName)) return null;
  final value = point.value;
  if (value is! NumericHealthValue) return null;
  final method = hrvMethodFor(point.type);
  if (method == null && point.type != HealthDataType.RESTING_HEART_RATE) return null;
  return VitalsSample(at: point.dateFrom, value: value.numericValue.toDouble(), hrvMethod: method);
}

/// One day's importable vitals: what [DailyVitalsRepository.upsertForDay]
/// receives. [hrvMs] and [hrvMethod] are both set or both null.
class HealthDailyVitals {
  const HealthDailyVitals({
    required this.date,
    required this.lastSampleAt,
    this.restingHr,
    this.hrvMs,
    this.hrvMethod,
  });

  /// The local calendar day (midnight).
  final DateTime date;

  /// The newest sample that went into this day: the import cursor.
  final DateTime lastSampleAt;
  final int? restingHr;
  final double? hrvMs;
  final HrvMethod? hrvMethod;
}

/// The range the backend accepts (V100 check constraints). A value outside
/// it would be refused on every sync attempt, so it is dropped here.
bool _plausibleRestingHr(double bpm) => bpm >= 20 && bpm <= 250;
bool _plausibleHrv(double ms) => ms > 0 && ms <= 1000;

/// Groups store samples into one [HealthDailyVitals] per local day, oldest
/// day first (docs/integrations/89 G3.3, D-G8):
///
/// - **Resting HR:** the day's newest value, rounded. Sources recompute their
///   daily value as the day goes on, so the latest one is the day's answer.
/// - **HRV:** the average of the day's values of **one** method, rounded to
///   0.1 ms. SDNN and RMSSD are never averaged together. One device only ever
///   reads one of them, but if a day still has both, the method with more
///   readings wins (ties: the one read last) and the other is left out.
/// - A day with neither value is left out.
List<HealthDailyVitals> dailyVitalsFrom(Iterable<VitalsSample> samples) {
  final byDay = <DateTime, List<VitalsSample>>{};
  for (final sample in samples) {
    final local = sample.at.toLocal();
    byDay.putIfAbsent(DateTime(local.year, local.month, local.day), () => []).add(sample);
  }

  final days = <HealthDailyVitals>[];
  for (final MapEntry(key: day, value: daySamples) in byDay.entries) {
    daySamples.sort((a, b) => a.at.compareTo(b.at));

    final restingHr = daySamples.where((s) => s.isRestingHr && _plausibleRestingHr(s.value)).lastOrNull;

    final hrvByMethod = <HrvMethod, List<VitalsSample>>{};
    for (final sample in daySamples) {
      final method = sample.hrvMethod;
      if (method != null && _plausibleHrv(sample.value)) hrvByMethod.putIfAbsent(method, () => []).add(sample);
    }
    final hrv = hrvByMethod.entries.fold<MapEntry<HrvMethod, List<VitalsSample>>?>(null, (best, entry) {
      if (best == null) return entry;
      final more = entry.value.length.compareTo(best.value.length);
      if (more != 0) return more > 0 ? entry : best;
      return entry.value.last.at.isAfter(best.value.last.at) ? entry : best;
    });

    if (restingHr == null && hrv == null) continue;
    final used = [if (restingHr != null) restingHr, ...?hrv?.value];
    days.add(HealthDailyVitals(
      date: day,
      lastSampleAt: used.map((s) => s.at).reduce((a, b) => a.isAfter(b) ? a : b),
      restingHr: restingHr?.value.round(),
      hrvMs: hrv == null ? null : _roundTenth(hrv.value.map((s) => s.value).reduce((a, b) => a + b) / hrv.value.length),
      hrvMethod: hrv?.key,
    ));
  }
  days.sort((a, b) => a.date.compareTo(b.date));
  return days;
}

double _roundTenth(double value) => (value * 10).round() / 10;
