import '../../../nutrition/domain/meal.dart' show MealType;
import '../../clients/domain/trainer_client.dart' show parseTrainerTimestamp;

/// The read-only models behind the client detail screen (docs/chat/41 T2).
///
/// All of them are API shapes, not app entities: they are fetched, shown, and
/// dropped. Nothing here has a drift table, a clientId or an outbox entry —
/// the trainer view keeps no copy of another person's data (§2.2).

/// `StatisticsResponse` for one period (daily / weekly / monthly).
///
/// The cardio breakdown fields (`strengthWorkoutCount`, `movingMinutes`, …)
/// are deliberately not parsed: no T2 tab shows them, and the web statistics
/// tab doesn't either. Add them when a screen actually needs them.
class ClientStatistics {
  const ClientStatistics({
    this.totalCalories,
    this.totalProtein,
    this.totalCarbs,
    this.totalFat,
    this.workoutCount,
    this.latestWeight,
  });

  final double? totalCalories;
  final double? totalProtein;
  final double? totalCarbs;
  final double? totalFat;
  final int? workoutCount;
  final double? latestWeight;

  factory ClientStatistics.fromJson(Map<String, dynamic> json) {
    return ClientStatistics(
      totalCalories: (json['totalCalories'] as num?)?.toDouble(),
      totalProtein: (json['totalProtein'] as num?)?.toDouble(),
      totalCarbs: (json['totalCarbs'] as num?)?.toDouble(),
      totalFat: (json['totalFat'] as num?)?.toDouble(),
      workoutCount: (json['workoutCount'] as num?)?.toInt(),
      latestWeight: (json['latestWeight'] as num?)?.toDouble(),
    );
  }
}

/// Which window `GET /trainer/clients/{id}/statistics/{period}` covers.
enum ClientStatisticsPeriod {
  daily('daily', 1),
  weekly('weekly', 7),
  monthly('monthly', 30);

  const ClientStatisticsPeriod(this.apiValue, this.days);

  final String apiValue;

  /// How many days the totals span — the overview turns the weekly total into
  /// a daily average with it, so the divisor can never drift from the period.
  final int days;
}

/// One day of the client's step history (`DailyStepCountResponse`).
class ClientStepDay {
  const ClientStepDay({required this.date, required this.steps});

  final DateTime date;
  final int steps;

  factory ClientStepDay.fromJson(Map<String, dynamic> json) {
    return ClientStepDay(
      date: parseTrainerTimestamp(json['date'] as String),
      steps: (json['steps'] as num?)?.toInt() ?? 0,
    );
  }
}

/// One of the client's weigh-ins (`WeightResponse`).
class ClientWeightEntry {
  const ClientWeightEntry({required this.date, required this.weight});

  final DateTime date;
  final double weight;

  factory ClientWeightEntry.fromJson(Map<String, dynamic> json) {
    return ClientWeightEntry(
      date: parseTrainerTimestamp(json['date'] as String),
      weight: (json['weight'] as num?)?.toDouble() ?? 0,
    );
  }
}

/// One logged meal with its entries (`MealResponse`).
///
/// [MealType] is the client-side enum, reused as-is: it already carries the
/// API value and the localised label, and a second copy would be one more
/// thing to keep in step.
class ClientMeal {
  const ClientMeal({
    required this.id,
    required this.dateTime,
    required this.mealType,
    required this.name,
    this.entries = const [],
  });

  final int id;
  final DateTime dateTime;
  final MealType mealType;
  final String name;
  final List<ClientMealEntry> entries;

  double get calories => entries.fold(0, (sum, e) => sum + e.calories);
  double get protein => entries.fold(0, (sum, e) => sum + e.protein);
  double get carbs => entries.fold(0, (sum, e) => sum + e.carbs);
  double get fat => entries.fold(0, (sum, e) => sum + e.fat);

  factory ClientMeal.fromJson(Map<String, dynamic> json) {
    return ClientMeal(
      id: (json['id'] as num).toInt(),
      dateTime: parseTrainerTimestamp(json['dateTime'] as String),
      mealType: MealType.fromApi(json['mealType'] as String),
      name: json['name'] as String? ?? '',
      entries: ((json['entries'] as List<dynamic>?) ?? const [])
          .map((entry) => ClientMealEntry.fromJson(entry as Map<String, dynamic>))
          .toList(),
    );
  }
}

/// One food inside a meal (`MealEntryResponse`).
class ClientMealEntry {
  const ClientMealEntry({
    required this.foodName,
    required this.quantityInGrams,
    required this.calories,
    required this.protein,
    required this.carbs,
    required this.fat,
  });

  final String foodName;
  final double quantityInGrams;
  final double calories;
  final double protein;
  final double carbs;
  final double fat;

  factory ClientMealEntry.fromJson(Map<String, dynamic> json) {
    double num_(String key) => (json[key] as num?)?.toDouble() ?? 0;
    return ClientMealEntry(
      foodName: json['foodName'] as String? ?? '',
      quantityInGrams: num_('quantityInGrams'),
      calories: num_('calories'),
      protein: num_('protein'),
      carbs: num_('carbs'),
      fat: num_('fat'),
    );
  }
}

/// The client's daily macro targets (`ClientNutritionGoalsResponse`).
///
/// Every field is nullable, and null means "no goal set" rather than zero —
/// the difference matters, because a zero goal would render as 100% over on
/// the first bite.
class ClientNutritionGoals {
  const ClientNutritionGoals({
    this.dailyCalorieGoal,
    this.dailyProteinGoal,
    this.dailyCarbsGoal,
    this.dailyFatGoal,
  });

  final double? dailyCalorieGoal;
  final double? dailyProteinGoal;
  final double? dailyCarbsGoal;
  final double? dailyFatGoal;

  bool get isEmpty =>
      dailyCalorieGoal == null &&
      dailyProteinGoal == null &&
      dailyCarbsGoal == null &&
      dailyFatGoal == null;

  factory ClientNutritionGoals.fromJson(Map<String, dynamic> json) {
    return ClientNutritionGoals(
      dailyCalorieGoal: (json['dailyCalorieGoal'] as num?)?.toDouble(),
      dailyProteinGoal: (json['dailyProteinGoal'] as num?)?.toDouble(),
      dailyCarbsGoal: (json['dailyCarbsGoal'] as num?)?.toDouble(),
      dailyFatGoal: (json['dailyFatGoal'] as num?)?.toDouble(),
    );
  }
}
