import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/exercise_repository.dart';
import '../domain/exercise.dart';

/// Exercises shown per page in the Exercises tab; [ExercisePagedController.loadMore] grows the window by this much.
const exercisePageSize = 40;

/// The Exercises tab's windowed view of the exercise list (docs/14-pagination-plan.md Phase 1.3, LIF-113): the first
/// [exercisePageSize] exercises, grown by [loadMore], optionally of one muscle group. Purely a local-cache window - the backend is
/// never paged for it.
///
/// A *view*, not the list: the template and session pickers, the dashboard and the watch sync still read the whole list from
/// `exerciseControllerProvider`, which they need complete, and the tab still deletes and refreshes through that controller. Keeping
/// the two apart is what lets this one be bounded.
///
/// Same bridge as `FoodController`: one broadcast [StreamController] returned from [build], with the repository subscription
/// swapped underneath it by [loadMore], so growing the window does not rebuild the notifier and reset it.
class ExercisePagedController extends StreamNotifier<List<Exercise>> {
  ExercisePagedController(this.category);

  /// The muscle group the tab is filtered to, or null for all of them.
  final String? category;

  ExerciseRepository get _repo => ref.read(exerciseRepositoryProvider);

  int _limit = exercisePageSize;

  /// True while the last emitted window was full, i.e. more exercises may exist beyond it.
  bool hasMore = true;

  /// Set by [loadMore] and cleared when the larger window arrives, so a second call before then does not grow it twice.
  bool _growing = false;

  StreamController<List<Exercise>>? _controller;
  StreamSubscription<List<Exercise>>? _repoSubscription;

  @override
  Stream<List<Exercise>> build() {
    final controller = StreamController<List<Exercise>>.broadcast();
    _controller = controller;
    ref.onDispose(() {
      _repoSubscription?.cancel();
      controller.close();
    });
    _resubscribe();
    return controller.stream;
  }

  void _resubscribe() {
    _repoSubscription?.cancel();
    // One more than the window: that extra row is how "is there more" is known without a count query.
    _repoSubscription = _repo.watchPaged(limit: _limit + 1, category: category).listen((rows) {
      hasMore = rows.length > _limit;
      _growing = false;
      _controller?.add(hasMore ? rows.take(_limit).toList() : rows);
    });
  }

  /// Grows the window by one page.
  void loadMore() {
    if (!hasMore || _growing) return;
    _growing = true;
    _limit += exercisePageSize;
    _resubscribe();
  }
}

/// The paged exercise list of one muscle group, or of all of them for `null`.
final exercisePagedControllerProvider =
    StreamNotifierProvider.family<ExercisePagedController, List<Exercise>, String?>(ExercisePagedController.new);
