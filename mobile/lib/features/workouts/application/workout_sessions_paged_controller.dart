import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/workout_session_repository.dart';
import '../domain/workout_session.dart';

/// Started sessions shown per page in the Sessions tab; [WorkoutSessionsPagedController.loadMore] grows the window by this much.
const sessionsPageSize = 40;

/// The Sessions tab's windowed view of the workout history (docs/14-pagination-plan.md Phase 1.3, LIF-113): the
/// [sessionsPageSize] newest started sessions, grown by [loadMore], plus every upcoming (trainer-scheduled) one. Purely a
/// local-cache window - the backend is never paged for it.
///
/// A *view*, not the history: the statistics, the streaks, the recommended workout and the rest read `workoutSummariesProvider`,
/// the record counts `strengthPrCountsProvider` (the database counts them, LIF-158), and the tab still deletes and refreshes through
/// `workoutSessionControllerProvider`, which holds no list. What this provider changes is what the tab itself reads and builds:
/// the sets of only the window's sessions.
///
/// Same bridge as `FoodController`: one broadcast [StreamController] returned from [build], with the repository subscription
/// swapped underneath it by [loadMore].
class WorkoutSessionsPagedController extends StreamNotifier<List<WorkoutSession>> {
  WorkoutSessionRepository get _repo => ref.read(workoutSessionRepositoryProvider);

  int _limit = sessionsPageSize;

  /// True while the last emitted window was full, i.e. older sessions may exist beyond it.
  bool hasMore = true;

  /// Set by [loadMore] and cleared when the larger window arrives, so a second call before then does not grow it twice.
  bool _growing = false;

  StreamController<List<WorkoutSession>>? _controller;
  StreamSubscription<List<WorkoutSession>>? _repoSubscription;

  @override
  Stream<List<WorkoutSession>> build() {
    final controller = StreamController<List<WorkoutSession>>.broadcast();
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
    // One more started session than the window: that extra row is how "is there more" is known without a count query.
    _repoSubscription = _repo.watchPaged(limit: _limit + 1).listen((rows) {
      final started = rows.where((s) => s.startedAt != null).length;
      hasMore = started > _limit;
      _growing = false;
      _controller?.add(hasMore ? _withoutOldestStarted(rows) : rows);
    });
  }

  /// [rows] is newest first, so the extra started session is the last one that has a start time.
  List<WorkoutSession> _withoutOldestStarted(List<WorkoutSession> rows) {
    final lastStarted = rows.lastIndexWhere((s) => s.startedAt != null);
    return [...rows.sublist(0, lastStarted), ...rows.sublist(lastStarted + 1)];
  }

  /// Grows the window by one page.
  void loadMore() {
    if (!hasMore || _growing) return;
    _growing = true;
    _limit += sessionsPageSize;
    _resubscribe();
  }
}

final workoutSessionsPagedProvider =
    StreamNotifierProvider<WorkoutSessionsPagedController, List<WorkoutSession>>(WorkoutSessionsPagedController.new);
