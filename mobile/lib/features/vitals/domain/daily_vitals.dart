/// How a heart rate variability value was measured (docs/integrations/89
/// D-G8). iOS stores SDNN, Health Connect stores RMSSD. The two are not
/// comparable, so a trend never mixes them. [wire] is the backend enum name.
enum HrvMethod {
  sdnn('SDNN'),
  rmssd('RMSSD');

  const HrvMethod(this.wire);

  final String wire;

  /// Null for a name this build does not know.
  static HrvMethod? fromWire(String? value) {
    for (final method in values) {
      if (method.wire == value) return method;
    }
    return null;
  }
}

/// One day of vitals from the health store (`/vitals`): resting heart rate
/// and heart rate variability. Either may be missing, never both.
class DailyVitals {
  const DailyVitals({
    required this.clientId,
    required this.date,
    this.id,
    this.restingHr,
    this.hrvMs,
    this.hrvMethod,
  });

  final String clientId;

  /// Server id; null until the create syncs.
  final int? id;

  /// The calendar day (local midnight).
  final DateTime date;

  /// Resting heart rate in bpm.
  final int? restingHr;

  /// Heart rate variability in milliseconds, measured by [hrvMethod].
  final double? hrvMs;
  final HrvMethod? hrvMethod;
}
