import 'dart:convert';

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
    this.servings = const [],
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

  /// Named serving sizes (LIF-146), in the owner's order: "1 glass" = 150 g.
  final List<FoodServing> servings;
  final String? barcode;
  final bool hidden;
}

/// A named serving size of a food (`{name, grams}`), stored on the food as a JSON array.
class FoodServing {
  const FoodServing({required this.name, required this.grams});

  final String name;
  final double grams;

  Map<String, dynamic> toJson() => {'name': name, 'grams': grams};

  /// Reads what the server sent or the local column holds; anything that is not a list of well-formed servings is
  /// dropped (a bad row must not take the whole food down).
  static List<FoodServing> listFromJson(Object? raw) {
    if (raw is! List) return const [];
    final result = <FoodServing>[];
    for (final item in raw) {
      if (item is! Map) continue;
      final name = item['name'];
      final grams = item['grams'];
      if (name is String && name.trim().isNotEmpty && grams is num && grams > 0) {
        result.add(FoodServing(name: name, grams: grams.toDouble()));
      }
    }
    return result;
  }

  /// The column value for [servings]: null when there are none.
  static String? encode(List<FoodServing> servings) =>
      servings.isEmpty ? null : jsonEncode([for (final s in servings) s.toJson()]);

  /// The inverse of [encode].
  static List<FoodServing> decode(String? column) {
    if (column == null || column.isEmpty) return const [];
    try {
      return listFromJson(jsonDecode(column));
    } catch (_) {
      return const [];
    }
  }

  @override
  bool operator ==(Object other) => other is FoodServing && other.name == name && other.grams == grams;

  @override
  int get hashCode => Object.hash(name, grams);
}
