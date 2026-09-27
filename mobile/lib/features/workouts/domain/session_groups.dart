import '../../streaks/domain/weekly_recap.dart';
import 'workout_session.dart';

/// The headers the Sessions list groups its rows under: "Today", "Earlier this
/// week", "Last week", then one group per older calendar week
/// (docs/redesign/77-mobile-redesign-plan.md R3.3; canvas Lifey 3 › 3.1
/// "Csoportosítás napok szerint"). Weeks run Monday–Sunday, like the week
/// summary and the weekly recap.
enum SessionGroupKind { today, earlierThisWeek, lastWeek, olderWeek }

class SessionGroup {
  const SessionGroup({required this.kind, required this.weekStart, required this.sessions});

  final SessionGroupKind kind;

  /// Local-midnight Monday of the week the group's sessions started in.
  final DateTime weekStart;

  /// Newest first, as they came in.
  final List<WorkoutSession> sessions;
}

/// Groups [sessions] — already newest first, all started — for the list.
///
/// Today is its own group even on a Monday. Everything else in the current
/// week is "Earlier this week"; the previous week is "Last week"; each older
/// week is a group of its own, labelled by its [SessionGroup.weekStart].
/// Empty groups are not returned.
List<SessionGroup> groupSessionsByWeek(List<WorkoutSession> sessions, DateTime now) {
  final today = DateTime(now.year, now.month, now.day);
  final thisWeek = WeeklyRecap.weekStartFor(now);
  final lastWeek = DateTime(thisWeek.year, thisWeek.month, thisWeek.day - 7);

  final groups = <SessionGroup>[];
  for (final session in sessions) {
    final local = session.startedAt!.toLocal();
    final day = DateTime(local.year, local.month, local.day);
    final weekStart = WeeklyRecap.weekStartFor(local);
    final kind = day == today
        ? SessionGroupKind.today
        : weekStart == thisWeek
            ? SessionGroupKind.earlierThisWeek
            : weekStart == lastWeek
                ? SessionGroupKind.lastWeek
                : SessionGroupKind.olderWeek;

    // Newest first, so a session belongs to the last group or starts a new one.
    if (groups.isNotEmpty && groups.last.kind == kind && groups.last.weekStart == weekStart) {
      groups.last.sessions.add(session);
    } else {
      groups.add(SessionGroup(kind: kind, weekStart: weekStart, sessions: [session]));
    }
  }
  return groups;
}
