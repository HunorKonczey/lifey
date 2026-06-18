import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Repository for meal logging data.
abstract interface class MealRepository {
  // CRUD operations for meals go here.
}

final mealRepositoryProvider = Provider<MealRepository>((ref) {
  throw UnimplementedError();
});
