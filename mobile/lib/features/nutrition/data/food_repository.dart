import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Repository for food data (remote API + local cache).
abstract interface class FoodRepository {
  // CRUD operations for foods go here.
}

final foodRepositoryProvider = Provider<FoodRepository>((ref) {
  throw UnimplementedError();
});
