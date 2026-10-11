import 'package:lifey/features/workouts/application/workout_sessions_paged_controller.dart';
import 'package:lifey/features/workouts/domain/workout_session.dart';

/// The Sessions tab's windowed provider (LIF-113) serving a fixed list - the tab tests' stand-in for the database window. With
/// [more] false there is no older page, so the tab shows exactly [sessions]; with it true, [loadMore] calls are counted.
class FakePagedSessions extends WorkoutSessionsPagedController {
  FakePagedSessions(this.sessions, {this.more = false});

  final List<WorkoutSession> sessions;
  final bool more;
  int loadMoreCalls = 0;

  @override
  Stream<List<WorkoutSession>> build() {
    hasMore = more;
    return Stream.value(sessions);
  }

  @override
  void loadMore() => loadMoreCalls++;
}
