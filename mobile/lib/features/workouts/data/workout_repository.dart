import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Repository for workout templates and sessions.
abstract interface class WorkoutRepository {
  // CRUD operations for templates and sessions go here.
}

final workoutRepositoryProvider = Provider<WorkoutRepository>((ref) {
  throw UnimplementedError();
});
