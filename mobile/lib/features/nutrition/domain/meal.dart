import '../../../l10n/app_localizations.dart';
import 'fiber_sugar.dart';

/// The four meal types supported by the backend.
enum MealType {
  breakfast('BREAKFAST'),
  lunch('LUNCH'),
  dinner('DINNER'),
  snack('SNACK');

  const MealType(this.apiValue);

  final String apiValue;

  String label(AppLocalizations l10n) => switch (this) {
        MealType.breakfast => l10n.mealTypeBreakfast,
        MealType.lunch => l10n.mealTypeLunch,
        MealType.dinner => l10n.mealTypeDinner,
        MealType.snack => l10n.mealTypeSnack,
      };

  static MealType fromApi(String value) =>
      values.firstWhere((e) => e.apiValue == value, orElse: () => MealType.snack);
}

/// A single food entry within a meal (response side). Macros are computed
/// locally (quantity × the food's per-100g values) rather than fetched from
/// the backend, so they're available offline too.
class MealEntry {
  const MealEntry({
    required this.foodClientId,
    required this.foodName,
    required this.quantityInGrams,
    required this.calories,
    required this.protein,
    required this.carbs,
    required this.fat,
    this.fiber,
    this.sugar,
  });

  final String foodClientId;
  final String foodName;
  final double quantityInGrams;
  final double calories;
  final double protein;
  final double carbs;
  final double fat;

  /// Fibre and sugars of this entry (LIF-148): the food's per-100 g figure scaled to the grams; null when the food has none
  /// (not known is not 0).
  final double? fiber;
  final double? sugar;
}

/// A logged meal (`/meals`).
class Meal {
  const Meal({
    required this.clientId,
    required this.dateTime,
    required this.mealType,
    required this.entries,
    this.id,
    this.name,
    this.trainerComment,
    this.trainerCommentAt,
  });

  final String clientId;
  final int? id;
  final DateTime dateTime;
  final MealType mealType;
  final String? name;
  final List<MealEntry> entries;

  /// The trainer's comment on this meal (LIF-144); null when uncommented. Read-only here — it arrives with a pull.
  final String? trainerComment;

  /// When [trainerComment] was last written; null when uncommented.
  final DateTime? trainerCommentAt;

  bool get hasTrainerComment => trainerComment != null && trainerComment!.trim().isNotEmpty;

  double get totalCalories => entries.fold(0, (sum, e) => sum + e.calories);

  double get totalProtein => entries.fold(0, (sum, e) => sum + e.protein);

  double get totalCarbs => entries.fold(0, (sum, e) => sum + e.carbs);

  double get totalFat => entries.fold(0, (sum, e) => sum + e.fat);

  FiberSugarTotals get fiberSugar => FiberSugarTotals.of(entries.map((e) => (fiber: e.fiber, sugar: e.sugar)));
}

/// The fibre and sugars of a day's meals together.
extension MealsFiberSugar on Iterable<Meal> {
  FiberSugarTotals get fiberSugar =>
      FiberSugarTotals.of(expand((m) => m.entries).map((e) => (fiber: e.fiber, sugar: e.sugar)));
}
