import 'dart:io' show Platform;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:health/health.dart';

import 'apple_workout.dart';

/// The HealthKit data types the integration reads. Listed centrally so the
/// permission request (Phase 0) and the per-phase read helpers stay in sync.
///
/// - [HealthDataType.WORKOUT] + [HealthDataType.ACTIVE_ENERGY_BURNED] +
///   [HealthDataType.HEART_RATE] — Phase 1 (strength-workout pairing).
/// - [HealthDataType.STEPS] — Phase 2 (dashboard step count).
/// - [HealthDataType.WEIGHT] — Phase 3 (weight sync).
const healthDataTypes = <HealthDataType>[
  HealthDataType.WORKOUT,
  HealthDataType.ACTIVE_ENERGY_BURNED,
  HealthDataType.HEART_RATE,
  HealthDataType.STEPS,
  HealthDataType.WEIGHT,
];

/// Thin wrapper around the `health` plugin, the single entry point every
/// caller uses to touch Apple Health.
///
/// Apple Health/HealthKit is **iOS only** — there is no Android equivalent we
/// integrate with here (Android would be a separate Health Connect track, see
/// docs/16-apple-health-integration-plan.md). So everything no-ops on non-iOS:
/// [isAvailable] is false and the read/permission calls return early. That
/// keeps the app building and running normally on Android with the integration
/// simply absent, rather than sprinkling `Platform.isIOS` checks at every call
/// site.
class HealthService {
  HealthService([Health? health]) : _health = health ?? Health();

  final Health _health;
  bool _configured = false;

  /// Whether Apple Health is reachable on this device — i.e. we're on iOS.
  /// Callers should short-circuit on `false` before showing any Health UI.
  bool get isAvailable => Platform.isIOS;

  /// Lazily runs the plugin's one-time `configure()` before the first real
  /// call. Safe to call repeatedly.
  Future<void> _ensureConfigured() async {
    if (_configured) return;
    await _health.configure();
    _configured = true;
  }

  /// Requests READ access to [types] (defaults to [healthDataTypes]). Returns
  /// false immediately on non-iOS. Note HealthKit never reveals whether READ
  /// was actually granted (privacy), so a `true` here only means the request
  /// completed, not that data will be readable — read calls must tolerate
  /// empty results.
  Future<bool> requestPermissions([List<HealthDataType>? types]) async {
    if (!isAvailable) return false;
    await _ensureConfigured();
    return _health.requestAuthorization(types ?? healthDataTypes);
  }

  /// Sum of today's `HealthDataType.STEPS` samples (local day, midnight to
  /// now). Returns null on Android, when HealthKit is unavailable, or when
  /// there's simply no data (no permission, no samples) — callers must hide
  /// the steps UI when null rather than showing a misleading zero.
  Future<int?> todaySteps() async {
    if (!isAvailable) return null;
    await _ensureConfigured();
    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day);
    return _health.getTotalStepsInInterval(startOfDay, now);
  }

  /// Sum of `HealthDataType.STEPS` for the calendar day containing [day]
  /// (local midnight to the following midnight). Returns null on Android,
  /// when HealthKit is unavailable, or when there's no data.
  Future<int?> stepsForDay(DateTime day) async {
    if (!isAvailable) return null;
    await _ensureConfigured();
    final start = DateTime(day.year, day.month, day.day);
    final end = start.add(const Duration(days: 1));
    return _health.getTotalStepsInInterval(start, end);
  }

  /// Step totals for each of the last [lastDays] calendar days, keyed by
  /// local midnight. Days with null/0 from HealthKit are omitted.
  Future<Map<DateTime, int>> stepsByDay({required int lastDays}) async {
    if (!isAvailable) return const {};
    final result = <DateTime, int>{};
    final today = DateTime.now();
    for (var i = 0; i < lastDays; i++) {
      final day = today.subtract(Duration(days: i));
      final steps = await stepsForDay(day);
      if (steps != null && steps > 0) {
        result[DateTime(day.year, day.month, day.day)] = steps;
      }
    }
    return result;
  }

  /// The HealthKit workout activity types we treat as "strength training" —
  /// the only ones the Phase 1 import offers to pair with.
  static const _strengthActivityTypes = {
    HealthWorkoutActivityType.TRADITIONAL_STRENGTH_TRAINING,
    HealthWorkoutActivityType.FUNCTIONAL_STRENGTH_TRAINING,
  };

  /// Foreground read of strength workouts that **finished within [within]** of
  /// now, most-recently-finished first. This is the Phase 1 import source: the
  /// user taps "Import from Apple Health" right after finishing their Apple
  /// Fitness workout, so the completed HKWorkout has already synced and a plain
  /// foreground query finds it — no observer/background delivery needed.
  ///
  /// Returns `[]` on non-iOS, or when HealthKit has nothing/permission was
  /// denied (HealthKit never reveals READ-grant state, so empty is expected and
  /// must be tolerated).
  Future<List<AppleWorkout>> recentStrengthWorkouts({
    Duration within = const Duration(days: 1),
  }) async {
    if (!isAvailable) return const [];
    await _ensureConfigured();
    final now = DateTime.now();
    // Open the query window well before the cutoff so a long workout that
    // *started* earlier but *ended* within `within` is still returned — we
    // filter on end time below.
    final queryStart = now.subtract(within + const Duration(hours: 12));
    final points = await _health.getHealthDataFromTypes(
      types: const [HealthDataType.WORKOUT],
      startTime: queryStart,
      endTime: now,
    );

    final cutoff = now.subtract(within);
    final workouts = <AppleWorkout>[];
    for (final point in points) {
      final value = point.value;
      if (value is! WorkoutHealthValue) continue;
      if (!_strengthActivityTypes.contains(value.workoutActivityType)) continue;
      if (point.dateTo.isBefore(cutoff)) continue; // ended too long ago
      workouts.add(AppleWorkout(
        uuid: point.uuid,
        startDate: point.dateFrom,
        endDate: point.dateTo,
        activeCalories: value.totalEnergyBurned?.toDouble(),
        averageHeartRate: await _averageHeartRate(point.dateFrom, point.dateTo),
      ));
    }
    workouts.sort((a, b) => b.endDate.compareTo(a.endDate));
    return workouts;
  }

  /// Mean of the heart-rate samples in `[from, to]`, or null if there are none.
  Future<double?> _averageHeartRate(DateTime from, DateTime to) async {
    final points = await _health.getHealthDataFromTypes(
      types: const [HealthDataType.HEART_RATE],
      startTime: from,
      endTime: to,
    );
    final values = <double>[
      for (final point in points)
        if (point.value case final NumericHealthValue v) v.numericValue.toDouble(),
    ];
    if (values.isEmpty) return null;
    return values.reduce((a, b) => a + b) / values.length;
  }

  /// The most recent `HealthDataType.WEIGHT` (body mass, kg) sample, or null
  /// on Android / no permission / no samples. Only the latest sample matters
  /// for Phase 3's import — older Health weights are never of interest.
  Future<({double kg, DateTime timestamp})?> latestBodyMass() async {
    if (!isAvailable) return null;
    await _ensureConfigured();
    final now = DateTime.now();
    // A year back is generous — comfortably covers "haven't weighed in for a
    // while" without scanning someone's entire HealthKit history.
    final points = await _health.getHealthDataFromTypes(
      types: const [HealthDataType.WEIGHT],
      startTime: now.subtract(const Duration(days: 365)),
      endTime: now,
    );
    if (points.isEmpty) return null;
    points.sort((a, b) => b.dateTo.compareTo(a.dateTo));
    final latest = points.first;
    final value = latest.value;
    if (value is! NumericHealthValue) return null;
    return (kg: value.numericValue.toDouble(), timestamp: latest.dateTo);
  }
}

final healthServiceProvider = Provider<HealthService>((ref) => HealthService());
