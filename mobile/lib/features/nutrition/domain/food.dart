/// Domain model for a food and its per-100g macros (`/foods`).
class Food {
  const Food({
    required this.clientId,
    required this.name,
    required this.caloriesPer100g,
    required this.proteinPer100g,
    this.id,
    this.carbsPer100g,
    this.fatPer100g,
    this.fiberPer100g,
    this.sugarPer100g,
    this.barcode,
    this.hidden = false,
  });

  final String clientId;
  final int? id;
  final String name;
  final double caloriesPer100g;
  final double proteinPer100g;
  final double? carbsPer100g;
  final double? fatPer100g;

  /// Dietary fibre and sugars per 100 g (LIF-145); null = not known, which is not zero.
  final double? fiberPer100g;
  final double? sugarPer100g;
  final String? barcode;
  final bool hidden;
}
