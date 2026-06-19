import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/exercise_repository.dart';
import '../domain/exercise.dart';

/// The exercise master list, used by the template and session pickers.
final exerciseListProvider = FutureProvider<List<Exercise>>((ref) {
  return ref.watch(exerciseRepositoryProvider).fetchAll();
});
