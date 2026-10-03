/// Where on the body a measurement was taken (docs/80 §2.3). [wire] is the
/// backend enum name used in the REST payload and the local table.
enum MeasurementSite {
  waist('WAIST'),
  chest('CHEST'),
  hips('HIPS'),
  arm('ARM'),
  thigh('THIGH');

  const MeasurementSite(this.wire);

  final String wire;

  /// Null for a name this build does not know (a site added by a newer
  /// backend) — callers skip such rows rather than crash.
  static MeasurementSite? fromWire(String value) {
    for (final site in values) {
      if (site.wire == value) return site;
    }
    return null;
  }
}

/// A logged body measurement (`/measurements`), in centimetres.
class BodyMeasurement {
  const BodyMeasurement({
    required this.clientId,
    required this.date,
    required this.site,
    required this.valueCm,
    required this.recordedAt,
    this.id,
  });

  /// Local identifier, stable from creation — use for keys and deletes.
  final String clientId;

  /// The backend's id, null until the create has synced.
  final int? id;
  final DateTime date;
  final MeasurementSite site;
  final double valueCm;

  /// Local-only first-seen timestamp; breaks ties between same-day entries.
  final DateTime recordedAt;
}
