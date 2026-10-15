import '../../recipes/domain/recipe.dart';

/// When a recipe was last logged and how often, over the recent meal history (docs/88): a meal counts as one use of every
/// recipe that at least one of its entries is tagged with, however many ingredients it brought.
class RecipeUsage {
  const RecipeUsage({required this.lastUsedAt, required this.useCount});

  final DateTime lastUsedAt;
  final int useCount;
}

/// How many most-recently-logged recipes lead the picker.
const recentRecipesCount = 6;

/// Orders [recipes] for the Add-recipe picker: the [recentRecipesCount] most recently logged first, then the favourites,
/// then everything else - each group A to Z (accent-insensitive, by [byName]) - so a recipe that is eaten often is one tap
/// away and a new one is still easy to find.
List<Recipe> rankRecipesByUsage(
  List<Recipe> recipes,
  Map<String, RecipeUsage> usage, {
  required int Function(Recipe a, Recipe b) byName,
}) {
  final recents = recipes.where((r) => usage.containsKey(r.clientId)).toList()
    ..sort((a, b) {
      final byUse = usage[b.clientId]!.lastUsedAt.compareTo(usage[a.clientId]!.lastUsedAt);
      return byUse != 0 ? byUse : byName(a, b);
    });
  final lead = recents.take(recentRecipesCount).toList();
  final promoted = lead.map((r) => r.clientId).toSet();

  final favourites = recipes.where((r) => r.favorite && !promoted.contains(r.clientId)).toList()..sort(byName);
  promoted.addAll(favourites.map((r) => r.clientId));

  final rest = recipes.where((r) => !promoted.contains(r.clientId)).toList()..sort(byName);
  return [...lead, ...favourites, ...rest];
}
