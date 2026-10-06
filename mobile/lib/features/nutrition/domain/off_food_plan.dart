import 'food.dart';
import 'off_search.dart';

/// What to do when the user picks an OpenFoodFacts result (docs/84 Prompt 10): the food they will log is either one they
/// already have, or a new one to create — decided from their local foods, so it works offline.
sealed class OffFoodPlan {
  const OffFoodPlan();
}

/// The user already has this food: use it, create nothing.
class UseExistingFood extends OffFoodPlan {
  const UseExistingFood(this.food);
  final Food food;
}

/// Create a new food with this name (and the product's barcode and macros).
class CreateOffFood extends OffFoodPlan {
  const CreateOffFood(this.name);
  final String name;
}

String _key(String name) => name.trim().toLowerCase();

/// "Csirkemell (Pikok)", or "Csirkemell (OpenFoodFacts)" without a brand: tells a product from an own food of the same name.
String offDisambiguatedName(OffSearchItem item) {
  final brand = item.brand?.trim();
  return '${item.name.trim()} (${brand == null || brand.isEmpty ? 'OpenFoodFacts' : brand})';
}

/// The backend refuses two visible foods with the same name (case-insensitively), and a barcode can belong to one food of
/// a user, so — before anything is written — in this order:
///
/// 1. a food of the user with this barcode: use it (the product is already theirs, saved earlier or on another device);
/// 2. the product name is free: create it under that name;
/// 3. the name is taken by a different food: create it as "Name (Brand)";
/// 4. even that is taken: use that food (the same product saved before, without its barcode).
///
/// [localFoods] are the user's visible foods. A conflict only the server can see — a *deleted* food still holding the
/// barcode — cannot be known here; it surfaces when the create syncs, exactly as it does for a scanned barcode today.
OffFoodPlan planOffFood(OffSearchItem item, Iterable<Food> localFoods) {
  final foods = localFoods.where((f) => !f.hidden).toList();

  for (final food in foods) {
    if (food.barcode != null && food.barcode == item.barcode) return UseExistingFood(food);
  }

  final names = {for (final food in foods) _key(food.name): food};
  if (!names.containsKey(_key(item.name))) return CreateOffFood(item.name.trim());

  final renamed = offDisambiguatedName(item);
  final sameProductBefore = names[_key(renamed)];
  if (sameProductBefore != null) return UseExistingFood(sameProductBefore);
  return CreateOffFood(renamed);
}
