/// A logged water intake event (`/water-entries`).
class WaterEntry {
  const WaterEntry({
    required this.id,
    required this.consumedAt,
    required this.volumeLiters,
    this.sourceId,
    this.sourceName,
  });

  final int id;
  final DateTime consumedAt;
  final double volumeLiters;
  final int? sourceId;
  final String? sourceName;

  factory WaterEntry.fromJson(Map<String, dynamic> json) {
    return WaterEntry(
      id: json['id'] as int,
      consumedAt: DateTime.parse(json['consumedAt'] as String),
      volumeLiters: (json['volumeLiters'] as num).toDouble(),
      sourceId: json['sourceId'] as int?,
      sourceName: json['sourceName'] as String?,
    );
  }
}
