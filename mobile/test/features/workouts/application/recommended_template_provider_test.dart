import 'package:flutter_test/flutter_test.dart';
import 'package:lifey/features/workouts/application/recommended_template_provider.dart';
import 'package:lifey/features/workouts/domain/workout_session.dart';

/// A finished session, newest sessions get the latest [startedAt] — callers
/// build lists newest-first, matching [WorkoutSessionController]'s order.
WorkoutSession _finished({required String clientId, String? templateClientId, required DateTime startedAt}) {
  return WorkoutSession(
    clientId: clientId,
    exercises: const [],
    sets: const [],
    templateClientId: templateClientId,
    startedAt: startedAt,
    finishedAt: startedAt.add(const Duration(minutes: 30)),
  );
}

WorkoutSession _inProgress({required String clientId, String? templateClientId, required DateTime startedAt}) {
  return WorkoutSession(
    clientId: clientId,
    exercises: const [],
    sets: const [],
    templateClientId: templateClientId,
    startedAt: startedAt,
  );
}

void main() {
  final base = DateTime(2026, 8, 1);
  DateTime daysAgo(int n) => base.subtract(Duration(days: n));

  test('too little history yields no recommendation', () {
    final sessions = [_finished(clientId: 'c1', templateClientId: 'tA', startedAt: daysAgo(0))];
    expect(predictNextTemplateClientId(sessions), isNull);
  });

  test('no repeating pattern yields no recommendation', () {
    final sessions = [
      _finished(clientId: 'c3', templateClientId: 'tC', startedAt: daysAgo(0)),
      _finished(clientId: 'c2', templateClientId: 'tB', startedAt: daysAgo(1)),
      _finished(clientId: 'c1', templateClientId: 'tA', startedAt: daysAgo(2)),
    ];
    expect(predictNextTemplateClientId(sessions), isNull);
  });

  test('detects a simple A/B alternation and predicts the next one', () {
    // Oldest -> newest: A, B, A, B, A, B — predicts A next.
    final sessions = [
      _finished(clientId: 'c6', templateClientId: 'tB', startedAt: daysAgo(0)),
      _finished(clientId: 'c5', templateClientId: 'tA', startedAt: daysAgo(1)),
      _finished(clientId: 'c4', templateClientId: 'tB', startedAt: daysAgo(2)),
      _finished(clientId: 'c3', templateClientId: 'tA', startedAt: daysAgo(3)),
      _finished(clientId: 'c2', templateClientId: 'tB', startedAt: daysAgo(4)),
      _finished(clientId: 'c1', templateClientId: 'tA', startedAt: daysAgo(5)),
    ];
    expect(predictNextTemplateClientId(sessions), 'tA');
  });

  test('an in-progress session at the front is excluded, not treated as part of the pattern', () {
    final sessions = [
      _inProgress(clientId: 'running', templateClientId: 'tC', startedAt: daysAgo(0)),
      _finished(clientId: 'c6', templateClientId: 'tB', startedAt: daysAgo(1)),
      _finished(clientId: 'c5', templateClientId: 'tA', startedAt: daysAgo(2)),
      _finished(clientId: 'c4', templateClientId: 'tB', startedAt: daysAgo(3)),
      _finished(clientId: 'c3', templateClientId: 'tA', startedAt: daysAgo(4)),
      _finished(clientId: 'c2', templateClientId: 'tB', startedAt: daysAgo(5)),
      _finished(clientId: 'c1', templateClientId: 'tA', startedAt: daysAgo(6)),
    ];
    expect(predictNextTemplateClientId(sessions), 'tA');
  });

  group('template-less sessions (freeform strength today, cardio once it exists)', () {
    test("don't skew a pattern that fits entirely within the recent window", () {
      final sessions = [
        _finished(clientId: 'cardio-2', templateClientId: null, startedAt: daysAgo(0)),
        _finished(clientId: 'c6', templateClientId: 'tB', startedAt: daysAgo(1)),
        _finished(clientId: 'cardio-1', templateClientId: null, startedAt: daysAgo(2)),
        _finished(clientId: 'c5', templateClientId: 'tA', startedAt: daysAgo(3)),
        _finished(clientId: 'c4', templateClientId: 'tB', startedAt: daysAgo(4)),
        _finished(clientId: 'c3', templateClientId: 'tA', startedAt: daysAgo(5)),
        _finished(clientId: 'c2', templateClientId: 'tB', startedAt: daysAgo(6)),
        _finished(clientId: 'c1', templateClientId: 'tA', startedAt: daysAgo(7)),
      ];
      expect(predictNextTemplateClientId(sessions), 'tA');
    });

    // The regression this step fixes: docs/cardio/56 risk S11 / docs/cardio/59
    // C0.5. Before the fix, `.take(10)` ran before the template-less filter,
    // so 8 template-less sessions sitting in front of a clean 6-session A/B
    // cycle consumed 8 of the 10 "recent" slots and left only 2 templated
    // sessions to look at — nowhere near enough to detect the cycle. Filtering
    // template-less sessions out *before* take(10) means they cost nothing:
    // the detector still sees the 6 templated sessions that actually carry
    // the pattern.
    test('are skipped entirely rather than each costing a slot in the recent-10 window', () {
      final sessions = [
        for (var i = 0; i < 8; i++)
          _finished(clientId: 'cardio-$i', templateClientId: null, startedAt: daysAgo(i)),
        _finished(clientId: 'c6', templateClientId: 'tB', startedAt: daysAgo(8)),
        _finished(clientId: 'c5', templateClientId: 'tA', startedAt: daysAgo(9)),
        _finished(clientId: 'c4', templateClientId: 'tB', startedAt: daysAgo(10)),
        _finished(clientId: 'c3', templateClientId: 'tA', startedAt: daysAgo(11)),
        _finished(clientId: 'c2', templateClientId: 'tB', startedAt: daysAgo(12)),
        _finished(clientId: 'c1', templateClientId: 'tA', startedAt: daysAgo(13)),
      ];
      expect(predictNextTemplateClientId(sessions), 'tA');
    });

    test('more than 10 templated sessions still only look at the most recent 10', () {
      // 11 templated sessions, newest->oldest: B,A,B,A,B,A,B,A,B,A,X — an
      // 11th (oldest) entry with a third template that would poison the
      // period-2 pattern if the detector's window reached back far enough to
      // include it. Confirms the take(10) cap still applies after the
      // template-less filter, not just before it.
      final sessions = [
        for (var i = 0; i < 10; i++)
          _finished(
            clientId: 'c$i',
            templateClientId: i.isEven ? 'tB' : 'tA',
            startedAt: daysAgo(i),
          ),
        _finished(clientId: 'c10', templateClientId: 'tX', startedAt: daysAgo(10)),
      ];
      // Oldest-in-window..newest: tA,tB,tA,tB,tA,tB,tA,tB,tA,tB — continues
      // with tA (the 11th/oldest tX session is outside the 10-session cap).
      expect(predictNextTemplateClientId(sessions), 'tA');
    });
  });
}
