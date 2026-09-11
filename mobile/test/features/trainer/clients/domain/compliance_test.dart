import 'package:flutter_test/flutter_test.dart';
import 'package:lifey/features/trainer/clients/domain/compliance.dart';
import 'package:lifey/features/trainer/clients/domain/trainer_client.dart';

/// Case-for-case port of `web/src/features/trainer/compliance.test.ts`.
///
/// The point of keeping the two suites identical is the plan's §6 risk: two
/// clients, one backend, and a compliance rule that must not drift between
/// them. If you change a case here, change it there — and vice versa.
void main() {
  final now = DateTime.utc(2026, 7, 11, 12);
  const msPerDay = 24 * 60 * 60 * 1000;

  DateTime daysBefore(int days) =>
      DateTime.fromMillisecondsSinceEpoch(
        now.millisecondsSinceEpoch - days * msPerDay,
        isUtc: true,
      );

  TrainerClient client({
    int clientId = 1,
    DateTime? activeSince,
    DateTime? lastActivityAt,
    DateTime? lastWeightAt,
    int missedWorkoutCount = 0,
  }) {
    return TrainerClient(
      userId: clientId,
      email: 'client@example.com',
      activeSince: activeSince ?? DateTime.utc(2026, 6, 1),
      lastActivityAt: lastActivityAt,
      lastWeightAt: lastWeightAt,
      missedWorkoutCount: missedWorkoutCount,
    );
  }

  group('complianceFor', () {
    test('never logged anything -> falls back to activeSince, not instantly flagged', () {
      final flags = complianceFor(client(activeSince: now), now: now);

      expect(flags.daysSinceLastLog, 0);
      expect(flags.daysSinceWeight, 0);
      expect(flags.inactive, isFalse);
      expect(flags.weightStale, isFalse);
      expect(flags.needsAttention, isFalse);
    });

    test('never logged anything, joined long ago -> flagged via activeSince fallback', () {
      final flags = complianceFor(client(activeSince: daysBefore(30)), now: now);

      expect(flags.inactive, isTrue);
      expect(flags.weightStale, isTrue);
      expect(flags.needsAttention, isTrue);
    });

    test('just under the inactivity threshold -> not flagged', () {
      final flags = complianceFor(
        client(lastActivityAt: daysBefore(inactivityFlagDays - 1)),
        now: now,
      );

      expect(flags.daysSinceLastLog, inactivityFlagDays - 1);
      expect(flags.inactive, isFalse);
    });

    test('exactly at the inactivity threshold -> flagged', () {
      final flags = complianceFor(
        client(lastActivityAt: daysBefore(inactivityFlagDays)),
        now: now,
      );

      expect(flags.daysSinceLastLog, inactivityFlagDays);
      expect(flags.inactive, isTrue);
      expect(flags.needsAttention, isTrue);
    });

    test('just under the weight-stale threshold -> not flagged', () {
      final flags = complianceFor(
        client(
          lastActivityAt: now,
          lastWeightAt: daysBefore(weightStaleFlagDays - 1),
        ),
        now: now,
      );

      expect(flags.weightStale, isFalse);
    });

    test('exactly at the weight-stale threshold -> flagged', () {
      final flags = complianceFor(
        client(lastActivityAt: now, lastWeightAt: daysBefore(weightStaleFlagDays)),
        now: now,
      );

      expect(flags.weightStale, isTrue);
      expect(flags.needsAttention, isTrue);
    });

    test('one missed workout -> flagged', () {
      final flags = complianceFor(
        client(lastActivityAt: now, lastWeightAt: now, missedWorkoutCount: 1),
        now: now,
      );

      expect(flags.hasMissedWorkouts, isTrue);
      expect(flags.needsAttention, isTrue);
    });

    test('fully compliant client -> no flags', () {
      final flags = complianceFor(
        client(lastActivityAt: now, lastWeightAt: now),
        now: now,
      );

      expect(flags.inactive, isFalse);
      expect(flags.weightStale, isFalse);
      expect(flags.hasMissedWorkouts, isFalse);
      expect(flags.needsAttention, isFalse);
    });
  });

  group('sort comparators', () {
    test('byLeastActiveFirst orders worst inactivity first, then most missed workouts', () {
      final fresh = client(clientId: 1, lastActivityAt: now);
      final staleWithFewMisses = client(
        clientId: 2,
        lastActivityAt: daysBefore(10),
        missedWorkoutCount: 1,
      );
      final staleWithManyMisses = client(
        clientId: 3,
        lastActivityAt: daysBefore(10),
        missedWorkoutCount: 5,
      );

      final sorted = [fresh, staleWithFewMisses, staleWithManyMisses]
        ..sort((a, b) => byLeastActiveFirst(a, b, now: now));

      expect(sorted.map((c) => c.userId), [3, 2, 1]);
    });

    test('byMostMissedWorkouts orders highest missed count first', () {
      final a = client(clientId: 1, missedWorkoutCount: 2);
      final b = client(clientId: 2, missedWorkoutCount: 5);
      final c = client(clientId: 3);

      final sorted = [a, b, c]..sort(byMostMissedWorkouts);

      expect(sorted.map((x) => x.userId), [2, 1, 3]);
    });

    test('byWeightOverdue orders longest-overdue weight first', () {
      final recent = client(clientId: 1, lastWeightAt: now);
      final overdue = client(clientId: 2, lastWeightAt: daysBefore(20));

      final sorted = [recent, overdue]..sort((a, b) => byWeightOverdue(a, b, now: now));

      expect(sorted.map((x) => x.userId), [2, 1]);
    });
  });

  group('sortClients', () {
    final a = client(
      clientId: 1,
      lastActivityAt: now,
      lastWeightAt: now,
      missedWorkoutCount: 1,
    );
    final b = client(
      clientId: 2,
      lastActivityAt: daysBefore(10),
      lastWeightAt: daysBefore(20),
      missedWorkoutCount: 5,
    );
    final list = [a, b];

    test("'recent' returns the list unchanged (backend order)", () {
      expect(sortClients(list, ClientSortOption.recent, now: now), same(list));
    });

    test("'leastActive' matches byLeastActiveFirst", () {
      expect(
        sortClients(list, ClientSortOption.leastActive, now: now).map((c) => c.userId),
        [2, 1],
      );
    });

    test("'mostMissed' matches byMostMissedWorkouts", () {
      expect(
        sortClients(list, ClientSortOption.mostMissed, now: now).map((c) => c.userId),
        [2, 1],
      );
    });

    test("'weightOverdue' matches byWeightOverdue", () {
      expect(
        sortClients(list, ClientSortOption.weightOverdue, now: now).map((c) => c.userId),
        [2, 1],
      );
    });

    test('does not mutate the input array', () {
      final original = [...list];
      sortClients(list, ClientSortOption.leastActive, now: now);
      expect(list, original);
    });
  });
}
