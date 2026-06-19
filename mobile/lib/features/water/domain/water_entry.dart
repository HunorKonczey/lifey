/// A logged water intake event (`/water-entries`).
class WaterEntry {
  const WaterEntry({
    required this.clientId,
    required this.consumedAt,
    required this.volumeLiters,
    this.id,
    this.sourceClientId,
    this.sourceName,
  });

  final String clientId;
  final int? id;
  final DateTime consumedAt;
  final double volumeLiters;
  final String? sourceClientId;
  final String? sourceName;
}
