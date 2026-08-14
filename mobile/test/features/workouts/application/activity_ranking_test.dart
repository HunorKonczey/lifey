import 'package:flutter_test/flutter_test.dart';
import 'package:lifey/features/workouts/application/activity_ranking.dart';
import 'package:lifey/features/workouts/domain/workout_session.dart';

/// C2.6: `activity_ranking.dart` — recency-weighted quick-start ranking.
/// docs/cardio/59-cardio-implementation-plan.md C2.6, spec in
/// docs/cardio/53-cardio-mobile-plan.md §3.4 (D-C.8). Kész-ha: "Felezés,
/// döntetlen-feloldás, hidegindítás, vegyes lista mind tesztelve."
///
/// `QuickStartEntry` has value equality (see the class doc), so lists of it
/// compare element-by-element with plain `expect(actual, [entry, entry])`.

WorkoutSession _strength({required String clientId, String? templateClientId, required DateTime finishedAt}) {
  return WorkoutSession(
    clientId: clientId,
    exercises: const [],
    sets: const [],
    templateClientId: templateClientId,
    startedAt: finishedAt.subtract(const Duration(minutes: 45)),
    finishedAt: finishedAt,
  );
}

WorkoutSession _cardio({required String clientId, required String activityType, required DateTime finishedAt}) {
  return WorkoutSession(
    clientId: clientId,
    exercises: const [],
    sets: const [],
    sessionKind: 'CARDIO',
    activityType: activityType,
    startedAt: finishedAt.subtract(const Duration(minutes: 30)),
    finishedAt: finishedAt,
  );
}

WorkoutSession _inProgressCardio({required String clientId, required String activityType, required DateTime startedAt}) {
  return WorkoutSession(
    clientId: clientId,
    exercises: const [],
    sets: const [],
    sessionKind: 'CARDIO',
    activityType: activityType,
    startedAt: startedAt,
  );
}

void main() {
  final now = DateTime(2026, 8, 12, 9, 0);
  DateTime daysAgo(num n) => now.subtract(Duration(minutes: (n * 24 * 60).round()));

  group('cold start', () {
    test('no history at all yields the M02 default order — running, walking, strength, bike', () {
      final result = rankQuickStartEntries(const [], now: now, max: 4);

      expect(result, [
        const QuickStartEntry.cardio('RUNNING'),
        const QuickStartEntry.cardio('WALKING'),
        const QuickStartEntry.strength(),
        const QuickStartEntry.cardio('INDOOR_BIKE'),
      ]);
    });

    test('a single real session ranks first, the rest padded from the default order', () {
      final sessions = [_cardio(clientId: 'c1', activityType: 'BASKETBALL', finishedAt: now)];

      final result = rankQuickStartEntries(sessions, now: now, max: 3);

      expect(result, [
        const QuickStartEntry.cardio('BASKETBALL'),
        const QuickStartEntry.cardio('RUNNING'),
        const QuickStartEntry.cardio('WALKING'),
      ]);
    });

    test('padding never duplicates an entry that already ranked from real usage', () {
      final sessions = [_strength(clientId: 'c1', finishedAt: now)]; // freeform strength

      final result = rankQuickStartEntries(sessions, now: now, max: 3);

      expect(result, [
        const QuickStartEntry.strength(),
        const QuickStartEntry.cardio('RUNNING'), // not strength() again
        const QuickStartEntry.cardio('WALKING'),
      ]);
    });
  });

  group('half-life (21 days)', () {
    test('a more recent session outranks an older one of a different key at equal frequency', () {
      final sessions = [
        _cardio(clientId: 'c1', activityType: 'WALKING', finishedAt: daysAgo(10)),
        _cardio(clientId: 'c2', activityType: 'RUNNING', finishedAt: daysAgo(1)),
      ];

      final result = rankQuickStartEntries(sessions, now: now, max: 2);

      expect(result, [const QuickStartEntry.cardio('RUNNING'), const QuickStartEntry.cardio('WALKING')]);
    });

    test('two sessions 42 days old sum to exactly the weight of one session 21 days old — '
        'tied score, resolved by which key was used more recently', () {
      final sessions = [
        // Key A: two sessions at 42 days -> 0.5^(42/21) * 2 = 0.25 * 2 = 0.5.
        _cardio(clientId: 'c1', activityType: 'WALKING', finishedAt: daysAgo(42)),
        _cardio(clientId: 'c2', activityType: 'WALKING', finishedAt: daysAgo(42)),
        // Key B: one session at 21 days -> 0.5^(21/21) = 0.5. Same score as A,
        // but B's last use (21 days ago) is more recent than A's (42 days ago).
        _cardio(clientId: 'c3', activityType: 'RUNNING', finishedAt: daysAgo(21)),
      ];

      final result = rankQuickStartEntries(sessions, now: now, max: 2);

      expect(result, [const QuickStartEntry.cardio('RUNNING'), const QuickStartEntry.cardio('WALKING')]);
    });

    test('frequency beats a single recent use when the accumulated score is higher', () {
      final sessions = [
        // Key A: three sessions at 5/12/19 days -> 0.85 + 0.67 + 0.53 ≈ 2.05.
        _cardio(clientId: 'c1', activityType: 'WALKING', finishedAt: daysAgo(5)),
        _cardio(clientId: 'c2', activityType: 'WALKING', finishedAt: daysAgo(12)),
        _cardio(clientId: 'c3', activityType: 'WALKING', finishedAt: daysAgo(19)),
        // Key B: one session today -> 0.5^0 = 1.0.
        _cardio(clientId: 'c4', activityType: 'RUNNING', finishedAt: now),
      ];

      final result = rankQuickStartEntries(sessions, now: now, max: 2);

      expect(result, [const QuickStartEntry.cardio('WALKING'), const QuickStartEntry.cardio('RUNNING')]);
    });
  });

  group('tie-break chain', () {
    test('identical score and identical last-use falls back to the kActivityTypes display order', () {
      final sessions = [
        _cardio(clientId: 'c1', activityType: 'INDOOR_BIKE', finishedAt: daysAgo(3)),
        _cardio(clientId: 'c2', activityType: 'WALKING', finishedAt: daysAgo(3)),
      ];

      final result = rankQuickStartEntries(sessions, now: now, max: 2);

      // WALKING precedes INDOOR_BIKE in kActivityTypes.
      expect(result, [const QuickStartEntry.cardio('WALKING'), const QuickStartEntry.cardio('INDOOR_BIKE')]);
    });

    test('freeform strength beats a tied cardio entry — strength always wins a real tie', () {
      final sessions = [
        _cardio(clientId: 'c1', activityType: 'RUNNING', finishedAt: daysAgo(3)),
        _strength(clientId: 'c2', finishedAt: daysAgo(3)),
      ];

      final result = rankQuickStartEntries(sessions, now: now, max: 2);

      expect(result, [const QuickStartEntry.strength(), const QuickStartEntry.cardio('RUNNING')]);
    });

    test('two distinct real templates tied on score and last-use still resolve deterministically', () {
      final sessions = [
        _strength(clientId: 'c1', templateClientId: 'tZebra', finishedAt: daysAgo(3)),
        _strength(clientId: 'c2', templateClientId: 'tAlpha', finishedAt: daysAgo(3)),
      ];

      final result = rankQuickStartEntries(sessions, now: now, max: 2);

      // Both are strength entries, so the cardio tie-break index ties too
      // (-1 for each) — the final identity tiebreak (alphabetical by id)
      // decides.
      expect(result, [const QuickStartEntry.strength('tAlpha'), const QuickStartEntry.strength('tZebra')]);
    });
  });

  group('grouping', () {
    test('template-less strength sessions collapse into one freeform bucket, summed', () {
      final sessions = [
        _strength(clientId: 'c1', finishedAt: daysAgo(1)),
        _strength(clientId: 'c2', finishedAt: daysAgo(2)),
        _strength(clientId: 'c3', finishedAt: daysAgo(3)),
        _cardio(clientId: 'c4', activityType: 'HIKING', finishedAt: daysAgo(100)),
      ];

      final result = rankQuickStartEntries(sessions, now: now, max: 8);

      // Three sessions' worth of score keeps freeform strength well above a
      // single, ancient HIKING session — and it appears exactly once.
      expect(result.first, const QuickStartEntry.strength());
      expect(result.where((e) => e == const QuickStartEntry.strength()), hasLength(1));
    });

    test('distinct templates rank as separate entries, not merged with the freeform bucket', () {
      final sessions = [
        _strength(clientId: 'c1', templateClientId: 'tPushA', finishedAt: daysAgo(1)),
        _strength(clientId: 'c1', templateClientId: 'tPushA', finishedAt: daysAgo(8)),
        _strength(clientId: 'c2', templateClientId: 'tPullB', finishedAt: daysAgo(50)),
        _strength(clientId: 'c3', finishedAt: daysAgo(50)), // freeform
      ];

      final result = rankQuickStartEntries(sessions, now: now, max: 4);

      expect(result, [
        const QuickStartEntry.strength('tPushA'),
        // tPullB and freeform strength tie on score/recency here — both are
        // strength entries, so the cardio tie-break index ties too, and the
        // identity tiebreak (empty id sorts before "tPullB") decides.
        const QuickStartEntry.strength(),
        const QuickStartEntry.strength('tPullB'),
        const QuickStartEntry.cardio('RUNNING'), // padded — 1st in the M02 default order
      ]);
    });
  });

  group('completion', () {
    test('an in-progress session (no finishedAt) contributes no score and never appears', () {
      final sessions = [_inProgressCardio(clientId: 'c1', activityType: 'BASKETBALL', startedAt: now)];

      // max is small enough that BASKETBALL would only appear here via real
      // usage — it's 6th in the default padding order (after RUNNING,
      // WALKING, strength, INDOOR_BIKE, HIKING).
      final result = rankQuickStartEntries(sessions, now: now, max: 2);

      expect(result, [const QuickStartEntry.cardio('RUNNING'), const QuickStartEntry.cardio('WALKING')]);
    });
  });

  group('mixed list and max', () {
    test('a realistic mixed history ranks strength and cardio together by combined score', () {
      final sessions = [
        _strength(clientId: 's1', templateClientId: 'tPushA', finishedAt: daysAgo(1)),
        _cardio(clientId: 'c1', activityType: 'RUNNING', finishedAt: daysAgo(2)),
        _cardio(clientId: 'c2', activityType: 'RUNNING', finishedAt: daysAgo(9)),
        _cardio(clientId: 'c3', activityType: 'INDOOR_BIKE', finishedAt: daysAgo(30)),
      ];

      final result = rankQuickStartEntries(sessions, now: now, max: 3);

      expect(result, [
        const QuickStartEntry.cardio('RUNNING'), // two sessions, most recent overall
        const QuickStartEntry.strength('tPushA'), // one session, more recent than INDOOR_BIKE
        const QuickStartEntry.cardio('INDOOR_BIKE'),
      ]);
    });

    test('max truncates even when more distinct real entries exist', () {
      final sessions = [
        for (final type in const ['RUNNING', 'WALKING', 'HIKING', 'INDOOR_BIKE', 'BASKETBALL'])
          _cardio(clientId: type, activityType: type, finishedAt: now),
      ];

      final result = rankQuickStartEntries(sessions, now: now, max: 2);

      expect(result, hasLength(2));
    });

    test('max=0 returns an empty list', () {
      final result = rankQuickStartEntries([_cardio(clientId: 'c1', activityType: 'RUNNING', finishedAt: now)],
          now: now, max: 0);

      expect(result, isEmpty);
    });
  });

  group('quickStartDeepLinkUri / quickStartEntryFromDeepLinkUri (C2.11a)', () {
    test('a cardio entry round-trips through its deep link', () {
      const entry = QuickStartEntry.cardio('RUNNING');

      final uri = quickStartDeepLinkUri(entry);

      expect(uri.toString(), 'lifey://workout/start?activity=RUNNING');
      expect(quickStartEntryFromDeepLinkUri(uri), entry);
    });

    test('a specific-template strength entry round-trips, template included', () {
      const entry = QuickStartEntry.strength('template-123');

      final uri = quickStartDeepLinkUri(entry);

      expect(uri.toString(), 'lifey://workout/start?activity=STRENGTH&template=template-123');
      expect(quickStartEntryFromDeepLinkUri(uri), entry);
    });

    test('a freeform strength entry (no template) round-trips without a template param', () {
      const entry = QuickStartEntry.strength();

      final uri = quickStartDeepLinkUri(entry);

      expect(uri.queryParameters.containsKey('template'), isFalse);
      expect(quickStartEntryFromDeepLinkUri(uri), entry);
    });

    test('the bare lifey://workout link (no /start path) is not a quick-start URI', () {
      expect(quickStartEntryFromDeepLinkUri(Uri.parse('lifey://workout')), isNull);
    });

    test('an unrecognized activity code is rejected rather than crashing downstream', () {
      expect(
        quickStartEntryFromDeepLinkUri(Uri.parse('lifey://workout/start?activity=TELEPORTING')),
        isNull,
      );
    });

    test('a URI missing the activity param entirely is rejected', () {
      expect(quickStartEntryFromDeepLinkUri(Uri.parse('lifey://workout/start')), isNull);
    });

    test('the wrong scheme or host is rejected', () {
      expect(
        quickStartEntryFromDeepLinkUri(Uri.parse('https://workout/start?activity=RUNNING')),
        isNull,
      );
      expect(
        quickStartEntryFromDeepLinkUri(Uri.parse('lifey://today/start?activity=RUNNING')),
        isNull,
      );
    });
  });
}
