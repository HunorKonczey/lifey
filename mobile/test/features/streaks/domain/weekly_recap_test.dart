import 'package:flutter_test/flutter_test.dart';
import 'package:lifey/features/nutrition/domain/daily_macros.dart';
import 'package:lifey/features/settings/domain/user_settings.dart';
import 'package:lifey/features/steps/domain/daily_step_count.dart';
import 'package:lifey/features/streaks/domain/streak.dart';
import 'package:lifey/features/streaks/domain/weekly_recap.dart';
import 'package:lifey/features/weight/domain/weight_entry.dart';
import 'package:lifey/features/workouts/domain/workout_session.dart';

// A fixed Monday, well clear of any DST transition, so the suite never goes
// stale and every boundary is unambiguous.
final _monday = DateTime(2026, 6, 1);
DateTime _weekDay(int offset) => DateTime(_monday.year, _monday.month, _monday.day + offset);

DailyMacros _macros(DateTime day, double calories) =>
    DailyMacros(day: day, calories: calories, protein: 0, carbs: 0, fat: 0);

WorkoutSession _session({
  required DateTime startedAt,
  DateTime? finishedAt,
  bool upcoming = false,
}) {
  return WorkoutSession(
    clientId: 'session-${startedAt.microsecondsSinceEpoch}',
    startedAt: upcoming ? null : startedAt,
    finishedAt: finishedAt,
    scheduledFor: upcoming ? startedAt : null,
    exercises: const [],
    sets: const [],
  );
}

WeightEntry _weight(DateTime date, double weight, {DateTime? recordedAt}) {
  return WeightEntry(
    clientId: 'weight-${date.microsecondsSinceEpoch}-$weight',
    date: date,
    weight: weight,
    recordedAt: recordedAt ?? date,
  );
}

WeeklyRecap _compute({
  List<DailyMacros> dailyMacros = const [],
  List<WorkoutSession> sessions = const [],
  List<WeightEntry> weights = const [],
  Map<DateTime, double> dailyWaterLiters = const {},
  List<DailyStepCount> dailySteps = const [],
  UserSettings settings = const UserSettings.defaults(),
  List<Streak> streaks = const [],
}) {
  return WeeklyRecap.compute(
    weekStart: _monday,
    dailyMacros: dailyMacros,
    sessions: sessions,
    weights: weights,
    dailyWaterLiters: dailyWaterLiters,
    dailySteps: dailySteps,
    settings: settings,
    streaks: streaks,
  );
}

void main() {
  group('WeeklyRecap.weekStartFor', () {
    test('a Wednesday maps back to that week\'s Monday', () {
      expect(WeeklyRecap.weekStartFor(DateTime(2026, 6, 3)), _monday);
    });

    test('a Sunday maps back to the same week\'s Monday, not the next one', () {
      expect(WeeklyRecap.weekStartFor(DateTime(2026, 6, 7)), _monday);
    });

    test('a Monday maps to itself', () {
      expect(WeeklyRecap.weekStartFor(_monday), _monday);
    });
  });

  group('WeeklyRecap.lastCompletedWeekStart', () {
    test('is one full week before the week containing "now"', () {
      final now = DateTime(2026, 6, 10); // Wednesday of the week after _monday
      expect(WeeklyRecap.lastCompletedWeekStart(now), _monday);
    });
  });

  group('WeeklyRecap.compute — workouts', () {
    test('counts every non-upcoming session started in the week, finished or not', () {
      final recap = _compute(sessions: [
        _session(startedAt: _weekDay(0), finishedAt: _weekDay(0).add(const Duration(minutes: 30))),
        _session(startedAt: _weekDay(3)), // still in progress
        _session(startedAt: _weekDay(3), upcoming: true), // excluded: upcoming
        _session(startedAt: _weekDay(-1)), // excluded: previous week
      ]);

      expect(recap.workoutsDone, 2);
    });

    test('sums minutes only for finished sessions', () {
      final recap = _compute(sessions: [
        _session(
          startedAt: _weekDay(0).add(const Duration(hours: 8)),
          finishedAt: _weekDay(0).add(const Duration(hours: 9)),
        ),
        _session(startedAt: _weekDay(1).add(const Duration(hours: 8))), // in progress, 0 minutes
        _session(
          startedAt: _weekDay(2).add(const Duration(hours: 8)),
          finishedAt: _weekDay(2).add(const Duration(hours: 8, minutes: 45)),
        ),
      ]);

      expect(recap.workoutMinutes, 105); // 60 + 45
    });
  });

  group('WeeklyRecap.compute — nutrition', () {
    test('averages calories over logged days only, not divided by 7', () {
      final recap = _compute(dailyMacros: [
        _macros(_weekDay(0), 1800),
        _macros(_weekDay(2), 2200),
        _macros(_weekDay(9), 9999), // next week — excluded
      ]);

      expect(recap.loggedDayCount, 2);
      expect(recap.avgCalories, 2000); // (1800 + 2200) / 2, not / 7
    });

    test('avgCalories is null when nothing was logged this week', () {
      final recap = _compute(dailyMacros: [_macros(_weekDay(-1), 1800)]);

      expect(recap.loggedDayCount, 0);
      expect(recap.avgCalories, isNull);
    });

    test('caloriesDaysMet counts only logged days within budget, out of a set goal', () {
      final recap = _compute(
        settings: const UserSettings.defaults().copyWith(dailyCalorieGoal: 2000),
        dailyMacros: [
          _macros(_weekDay(0), 1800), // met
          _macros(_weekDay(1), 2500), // over
          _macros(_weekDay(2), 2000), // met (== counts)
        ],
      );

      expect(recap.calorieGoalSet, isTrue);
      expect(recap.caloriesDaysMet, 2);
    });

    test('caloriesDaysMet is zero and calorieGoalSet is false with no goal', () {
      final recap = _compute(dailyMacros: [_macros(_weekDay(0), 1800)]);

      expect(recap.calorieGoalSet, isFalse);
      expect(recap.caloriesDaysMet, 0);
    });
  });

  group('WeeklyRecap.compute — steps and water', () {
    test('stepsDaysMet counts in-week days reaching the goal', () {
      final recap = _compute(
        settings: const UserSettings.defaults().copyWith(dailyStepGoal: 8000),
        dailySteps: [
          DailyStepCount(clientId: 's0', date: _weekDay(0), steps: 9000), // met
          DailyStepCount(clientId: 's1', date: _weekDay(1), steps: 5000), // not met
          DailyStepCount(clientId: 's-prev', date: _weekDay(-2), steps: 20000), // excluded
        ],
      );

      expect(recap.stepGoalSet, isTrue);
      expect(recap.stepsDaysMet, 1);
    });

    test('waterDaysMet counts in-week days reaching the goal', () {
      final recap = _compute(
        settings: const UserSettings.defaults().copyWith(dailyWaterGoalLiters: 2.0),
        dailyWaterLiters: {
          _weekDay(0): 2.5, // met
          _weekDay(1): 1.0, // not met
          _weekDay(8): 5.0, // excluded — next week
        },
      );

      expect(recap.waterGoalSet, isTrue);
      expect(recap.waterDaysMet, 1);
    });
  });

  group('WeeklyRecap.compute — weight', () {
    test('weightStart is the latest entry on or before the week start', () {
      final recap = _compute(weights: [
        _weight(_monday.subtract(const Duration(days: 10)), 82.0),
        _weight(_monday.subtract(const Duration(days: 2)), 81.2),
        _weight(_weekDay(3), 80.5), // inside the week — irrelevant to weightStart
      ]);

      expect(recap.weightStart, 81.2);
    });

    test('weightEnd is the latest entry within the week, not the newest overall', () {
      final recap = _compute(weights: [
        _weight(_weekDay(0), 81.0),
        _weight(_weekDay(4), 80.2),
        _weight(_weekDay(20), 78.0), // far future — not "this week"
      ]);

      expect(recap.weightEnd, 80.2);
    });

    test('weightEnd is null when no entry falls inside the week', () {
      final recap = _compute(weights: [_weight(_monday.subtract(const Duration(days: 1)), 81.0)]);

      expect(recap.weightStart, 81.0);
      expect(recap.weightEnd, isNull);
      expect(recap.weightDelta, isNull);
    });

    test('weightDelta is end minus start, positive means gained', () {
      final recap = _compute(weights: [
        _weight(_monday.subtract(const Duration(days: 1)), 80.0),
        _weight(_weekDay(5), 81.0),
      ]);

      expect(recap.weightDelta, closeTo(1.0, 1e-9));
    });

    test('same-day tie-break uses the most recently recorded entry', () {
      final recap = _compute(weights: [
        _weight(_weekDay(2), 80.0, recordedAt: _weekDay(2).add(const Duration(hours: 7))),
        _weight(_weekDay(2), 80.4, recordedAt: _weekDay(2).add(const Duration(hours: 20))),
      ]);

      expect(recap.weightEnd, 80.4);
    });
  });

  group('WeeklyRecap.compute — streaks passthrough', () {
    test('carries the given streak snapshot through unchanged', () {
      final streaks = [
        const Streak(metric: StreakMetric.calories, current: 4, best: 10, todayMet: true),
      ];
      final recap = _compute(streaks: streaks);

      expect(recap.streaks, same(streaks));
    });
  });

  group('WeeklyRecap.compute — per-day arrays', () {
    test('dailyCalories places each logged day at its Monday-first index', () {
      final recap = _compute(dailyMacros: [
        _macros(_weekDay(0), 1800), // Monday
        _macros(_weekDay(6), 2200), // Sunday
      ]);

      expect(recap.dailyCalories, [1800.0, null, null, null, null, null, 2200.0]);
    });

    test('workoutDays marks the days a non-upcoming session started on', () {
      final recap = _compute(sessions: [
        _session(startedAt: _weekDay(1)),
        _session(startedAt: _weekDay(1)), // same day again — still just one true
        _session(startedAt: _weekDay(5)),
        _session(startedAt: _weekDay(2), upcoming: true), // excluded
      ]);

      expect(recap.workoutDays, [false, true, false, false, false, true, false]);
    });
  });

  group('WeeklyRecap.compute — empty week', () {
    test('an entirely empty week produces zeros and nulls, not errors', () {
      final recap = _compute();

      expect(recap.workoutsDone, 0);
      expect(recap.workoutMinutes, 0);
      expect(recap.avgCalories, isNull);
      expect(recap.loggedDayCount, 0);
      expect(recap.weightStart, isNull);
      expect(recap.weightEnd, isNull);
      expect(recap.weightDelta, isNull);
      expect(recap.dailyCalories, List<double?>.filled(7, null));
      expect(recap.workoutDays, List<bool>.filled(7, false));
      expect(recap.hasAnyData, isFalse);
    });
  });

  group('WeeklyRecap.hasAnyData', () {
    test('true when a workout happened this week', () {
      final recap = _compute(sessions: [_session(startedAt: _weekDay(0))]);
      expect(recap.hasAnyData, isTrue);
    });

    test('true when a meal was logged this week', () {
      final recap = _compute(dailyMacros: [_macros(_weekDay(0), 1500)]);
      expect(recap.hasAnyData, isTrue);
    });

    test('true when a weight entry falls inside this week', () {
      final recap = _compute(weights: [_weight(_weekDay(0), 80)]);
      expect(recap.hasAnyData, isTrue);
    });

    test('false when the only weight entry predates the week (baseline only)', () {
      final recap = _compute(weights: [_weight(_monday.subtract(const Duration(days: 30)), 80)]);
      expect(recap.hasAnyData, isFalse);
    });
  });
}
