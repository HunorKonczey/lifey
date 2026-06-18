/// Domain model for a food item.
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
}
