import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Repository for body weight entries.
abstract interface class WeightRepository {
  // CRUD operations for weight entries go here.
}

final weightRepositoryProvider = Provider<WeightRepository>((ref) {
  throw UnimplementedError();
});
