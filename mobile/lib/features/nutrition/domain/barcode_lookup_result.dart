/// Where a barcode lookup's data came from — mirrors the backend's
/// `GET /foods/barcode/{barcode}` `source` field.
enum BarcodeSource { local, openFoodFacts }

/// Result of a `GET /foods/barcode/{barcode}` call. Not a local-db entity —
/// this is a transient, online-only lookup, never persisted as-is.
class BarcodeLookupResult {
  const BarcodeLookupResult({
    required this.name,
    required this.caloriesPer100g,
    required this.proteinPer100g,
    required this.barcode,
    required this.source,
    this.carbsPer100g,
    this.fatPer100g,
    this.fiberPer100g,
    this.sugarPer100g,
  });

  final String name;
  final double caloriesPer100g;
  final double proteinPer100g;
  final double? carbsPer100g;
  final double? fatPer100g;
  final double? fiberPer100g;
  final double? sugarPer100g;
  final String barcode;
  final BarcodeSource source;

  factory BarcodeLookupResult.fromJson(Map<String, dynamic> json) {
    return BarcodeLookupResult(
      name: json['name'] as String,
      caloriesPer100g: (json['caloriesPer100g'] as num).toDouble(),
      proteinPer100g: (json['proteinPer100g'] as num).toDouble(),
      carbsPer100g: (json['carbsPer100g'] as num?)?.toDouble(),
      fatPer100g: (json['fatPer100g'] as num?)?.toDouble(),
      fiberPer100g: (json['fiberPer100g'] as num?)?.toDouble(),
      sugarPer100g: (json['sugarPer100g'] as num?)?.toDouble(),
      barcode: json['barcode'] as String,
      source: json['source'] == 'LOCAL' ? BarcodeSource.local : BarcodeSource.openFoodFacts,
    );
  }
}
