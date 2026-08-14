/// One raw GPS fix belonging to a cardio session's track log
/// (docs/cardio/54-cardio-gps-route-plan.md §4.1, C4a.3) — the domain-layer
/// counterpart of the Drift `CardioTrackPointRow`, decoupled from the
/// storage layer the same way `CardioMetrics` is decoupled from
/// `CardioDetailsRow`.
class CardioTrackPoint {
  const CardioTrackPoint({
    required this.seq,
    required this.latitude,
    required this.longitude,
    required this.recordedAt,
    this.altitude,
    this.accuracy,
    this.speed,
  });

  final int seq;
  final double latitude;
  final double longitude;
  final DateTime recordedAt;
  final double? altitude;
  final double? accuracy;
  final double? speed;
}
