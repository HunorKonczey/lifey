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
  static const trainerInvitesPending = '/trainer-invites/pending';
  static String trainerInviteRespond(int id) => '/trainer-invites/$id/respond';
  static const myTrainers = '/my-trainers';
  static String myTrainer(int trainerId) => '/my-trainers/$trainerId';
}
