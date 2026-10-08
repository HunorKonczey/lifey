import 'package:flutter_test/flutter_test.dart';
import 'package:lifey/features/onboarding/domain/user_details.dart' show PrimaryGoal;
import 'package:lifey/features/trainer/clients/domain/trainer_client.dart';

Map<String, dynamic> _json({Map<String, dynamic> extra = const {}, List<Map<String, dynamic>>? trend}) => {
      'clientId': 7,
      'clientEmail': 'anna@example.com',
      'clientFirstName': 'Anna',
      'clientLastName': 'Kovacs',
      'activeSince': '2026-06-01T00:00:00Z',
      'weightTrend': trend ?? const [],
      'assignedPlanCount': 1,
      'workoutsPerWeek': 6,
      'lastActivityAt': '2026-09-25T08:00:00Z',
      'lastWeightAt': '2026-09-24',
      'missedWorkoutCount': 0,
      ...extra,
    };

void main() {
  group('the two card figures added in R6.2', () {
    test('are read when the backend sends them', () {
      final client = TrainerClient.fromJson(_json(extra: {'avgCalories7d': 1631, 'prCount7d': 2}));

      expect(client.avgCalories7d, 1631);
      expect(client.prCount7d, 2);
    });

    test('a payload without them (an older backend) parses, and both stay null', () {
      final client = TrainerClient.fromJson(_json());

      expect(client.avgCalories7d, isNull);
      expect(client.prCount7d, isNull);
    });

    test('explicit nulls mean "no figure", and a real 0 records stays 0', () {
      final none = TrainerClient.fromJson(_json(extra: {'avgCalories7d': null, 'prCount7d': 0}));

      expect(none.avgCalories7d, isNull);
      expect(none.prCount7d, 0);
    });

    test('a number sent as a decimal is still read as a whole figure', () {
      final client = TrainerClient.fromJson(_json(extra: {'avgCalories7d': 1631.0}));

      expect(client.avgCalories7d, 1631);
    });
  });

  group('weightChangeKg', () {
    List<Map<String, dynamic>> trend(List<double> weights) => [
          for (final (i, w) in weights.indexed) {'date': '2026-09-${10 + i}', 'weightKg': w},
        ];

    test('is the last weigh-in minus the first of the sparkline window', () {
      final client = TrainerClient.fromJson(_json(trend: trend([65.9, 65.5, 64.5])));

      expect(client.weightChangeKg, closeTo(-1.4, 1e-9));
    });

    test('a gain is positive', () {
      final client = TrainerClient.fromJson(_json(trend: trend([64.0, 64.3])));

      expect(client.weightChangeKg, closeTo(0.3, 1e-9));
    });

    test('one reading, or none, is not a trend', () {
      expect(TrainerClient.fromJson(_json(trend: trend([64.0]))).weightChangeKg, isNull);
      expect(TrainerClient.fromJson(_json()).weightChangeKg, isNull);
    });
  });

  group('the goals and the plan of the week (LIF-101, LIF-102)', () {
    test('reads the step goal, the planned and completed sessions and the stated goal', () {
      final client = TrainerClient.fromJson(_json(extra: {
        'dailyStepGoal': 9000,
        'plannedSessions7d': 4,
        'completedSessions7d': 3,
        'primaryGoal': 'GAIN_MUSCLE',
      }));

      expect(client.dailyStepGoal, 9000);
      expect(client.plannedSessions7d, 4);
      expect(client.completedSessions7d, 3);
      expect(client.primaryGoal, PrimaryGoal.gainMuscle);
    });

    test('an older backend, or a client who set nothing, leaves the goals null and the counts at zero', () {
      final client = TrainerClient.fromJson(_json());

      expect(client.dailyStepGoal, isNull);
      expect(client.primaryGoal, isNull);
      expect(client.plannedSessions7d, 0);
      expect(client.completedSessions7d, 0);
    });
  });
}
