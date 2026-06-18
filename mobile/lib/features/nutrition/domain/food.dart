/// Domain model for a food and its per-100g macros (`/foods`).
class Food {
  const Food({
    required this.id,
    required this.name,
    required this.caloriesPer100g,
    required this.proteinPer100g,
    this.carbsPer100g,
    this.fatPer100g,
  });

  final int id;
  final String name;
  final double caloriesPer100g;
  final double proteinPer100g;
  final double? carbsPer100g;
  final double? fatPer100g;

  factory Food.fromJson(Map<String, dynamic> json) {
    return Food(
      id: json['id'] as int,
      name: json['name'] as String,
      caloriesPer100g: (json['caloriesPer100g'] as num).toDouble(),
      proteinPer100g: (json['proteinPer100g'] as num).toDouble(),
      carbsPer100g: (json['carbsPer100g'] as num?)?.toDouble(),
      fatPer100g: (json['fatPer100g'] as num?)?.toDouble(),
    );
  }
}
