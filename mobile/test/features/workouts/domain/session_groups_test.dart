import 'package:flutter_test/flutter_test.dart';
import 'package:lifey/features/workouts/domain/session_groups.dart';
import 'package:lifey/features/workouts/domain/workout_session.dart';

// Thursday 24 Sep 2026; this week is Mon 21 – Sun 27 Sep.
final _now = DateTime(2026, 9, 24, 19);

WorkoutSession _s(String id, DateTime start) => WorkoutSession(
      clientId: id,
      exercises: const [],
      sets: const [],
      startedAt: start,
      finishedAt: start.add(const Duration(minutes: 30)),
    );

List<String> _ids(SessionGroup g) => [for (final s in g.sessions) s.clientId];

void main() {
  test('Today, Earlier this week, Last week and older weeks, newest first', () {
    final groups = groupSessionsByWeek([
      _s('today', DateTime(2026, 9, 24, 8)),
      _s('wed', DateTime(2026, 9, 23, 17, 30)),
      _s('tue', DateTime(2026, 9, 22, 7, 45)),
      _s('lastSun', DateTime(2026, 9, 20, 7, 45)),
      _s('lastMon', DateTime(2026, 9, 14, 18)),
      _s('older', DateTime(2026, 9, 8, 18)),
      _s('older2', DateTime(2026, 9, 2, 18)),
    ], _now);

    expect(groups.map((g) => g.kind), [
      SessionGroupKind.today,
      SessionGroupKind.earlierThisWeek,
      SessionGroupKind.lastWeek,
      SessionGroupKind.olderWeek,
      SessionGroupKind.olderWeek,
    ]);
    expect(_ids(groups[0]), ['today']);
    expect(_ids(groups[1]), ['wed', 'tue']);
    expect(_ids(groups[2]), ['lastSun', 'lastMon']);
    expect(_ids(groups[3]), ['older']);
    expect(groups[3].weekStart, DateTime(2026, 9, 7));
    expect(groups[4].weekStart, DateTime(2026, 8, 31));
  });

  test('Sunday belongs to the previous week, Monday to this one', () {
    final groups = groupSessionsByWeek([
      _s('mon', DateTime(2026, 9, 21, 6)),
      _s('sun', DateTime(2026, 9, 20, 22)),
    ], _now);

    expect(groups.map((g) => g.kind), [SessionGroupKind.earlierThisWeek, SessionGroupKind.lastWeek]);
  });

  test('on a Monday today is still its own group and there is no "earlier this week"', () {
    final monday = DateTime(2026, 9, 21, 12);
    final groups = groupSessionsByWeek([
      _s('a', DateTime(2026, 9, 21, 8)),
      _s('b', DateTime(2026, 9, 20, 8)),
    ], monday);

    expect(groups.map((g) => g.kind), [SessionGroupKind.today, SessionGroupKind.lastWeek]);
  });

  test('empty groups are left out and an empty list stays empty', () {
    expect(groupSessionsByWeek(const [], _now), isEmpty);
    final only = groupSessionsByWeek([_s('old', DateTime(2026, 8, 3, 9))], _now);
    expect(only.single.kind, SessionGroupKind.olderWeek);
  });

  test('across a year boundary', () {
    final jan = DateTime(2027, 1, 5, 12); // Tuesday; this week starts Mon 4 Jan
    final groups = groupSessionsByWeek([
      _s('a', DateTime(2027, 1, 4, 9)),
      _s('b', DateTime(2026, 12, 30, 9)), // last week: Mon 28 Dec – Sun 3 Jan
    ], jan);

    expect(groups.map((g) => g.kind), [SessionGroupKind.earlierThisWeek, SessionGroupKind.lastWeek]);
  });
}
