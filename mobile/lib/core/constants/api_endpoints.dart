/// Centralized REST API endpoint paths.
class ApiEndpoints {
  const ApiEndpoints._();

  static const foods = '/foods';
  static String foodByBarcode(String barcode) => '/foods/barcode/$barcode';
  static const recipes = '/recipes';
  static const meals = '/meals';
  static const workoutTemplates = '/workout-templates';
  static const workoutSessions = '/workout-sessions';
  static const weights = '/weights';
  static const statistics = '/statistics';
}
