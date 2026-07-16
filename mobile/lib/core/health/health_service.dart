import 'dart:io' show Platform;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:health/health.dart';

import 'health_workout.dart';

/// The health data types the integration reads. Listed centrally so the
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
/// caller uses to touch the platform's health store — Apple Health on iOS,
/// Google Health Connect on Android (docs/16-apple-health-integration-plan.md,
/// docs/26-android-health-connect-integration-plan.md). The `health` package
/// exposes an identical API for both; this class doesn't otherwise branch on
/// platform except where the two stores genuinely differ (see
/// [isHealthConnectInstalled] and [_strengthActivityTypes]).
///
/// No-ops everywhere else ([isAvailable] false, [Platform.macOS]/desktop/web):
/// read/permission calls return early so the app keeps building and running
/// normally with the integration simply absent.
class HealthService {
  HealthService([Health? health]) : _health = health ?? Health();

  final Health _health;
  bool _configured = false;

  /// Whether this platform has a health store we integrate with at all.
  /// Callers should short-circuit on `false` before showing any Health UI.
  /// On Android this does NOT mean Health Connect is actually installed —
  /// see [isHealthConnectInstalled] for that (async) check.
  bool get isAvailable => Platform.isIOS || Platform.isAndroid;

  /// Lazily runs the plugin's one-time `configure()` before the first real
  /// call. Safe to call repeatedly.
  Future<void> _ensureConfigured() async {
    if (_configured) return;
    await _health.configure();
    _configured = true;
  }

  /// Whether the Health Connect app is installed and ready on this device.
  /// Always `true` on iOS (there's nothing separate to install). Android only
  /// — every `health` plugin call below throws `UnsupportedError` internally
  /// if this is false, which [_guarded] catches, but callers that need to
  /// distinguish "not installed" from "installed, no data" (e.g. the settings
  /// toggle, to decide whether to prompt an install) should check this first.
  Future<bool> isHealthConnectInstalled() => _health.isHealthConnectAvailable();

  /// Sends the user to the Play Store to install Health Connect. No-op on iOS.
  Future<void> promptInstallHealthConnect() => _health.installHealthConnect();

  /// Runs [body], returning [fallback] instead of throwing. Covers two
  /// distinct failure modes callers must tolerate identically: no permission
  /// granted (both platforms — neither reveals denial for privacy/consistency)
  /// and, Android-only, Health Connect not being installed (every plugin call
  /// throws `UnsupportedError` in that case). Every public read method below
  /// is wrapped in this so "no data" always means the same thing to callers,
  /// regardless of platform or cause.
  Future<T> _guarded<T>(T fallback, Future<T> Function() body) async {
    try {
      return await body();
    } catch (_) {
      return fallback;
    }
  }

  /// Requests READ access to [types] (defaults to [healthDataTypes]). Returns
  /// false immediately when unavailable. Neither platform reveals whether
  /// READ was actually granted (HealthKit never does, for privacy; we treat
  /// Health Connect the same way for a consistent contract), so a `true` here
  /// only means the request completed, not that data will be readable — read
  /// calls must tolerate empty results.
  Future<bool> requestPermissions([List<HealthDataType>? types]) async {
    if (!isAvailable) return false;
    return _guarded(false, () async {
      await _ensureConfigured();
      return _health.requestAuthorization(types ?? healthDataTypes);
    });
  }

  /// Sum of today's `HealthDataType.STEPS` samples (local day, midnight to
  /// now). Returns null when unavailable, Health Connect isn't installed, or
  /// there's simply no data (no permission, no samples) — callers must hide
  /// the steps UI when null rather than showing a misleading zero.
  Future<int?> todaySteps() async {
    if (!isAvailable) return null;
    return _guarded(null, () async {
      await _ensureConfigured();
      final now = DateTime.now();
      final startOfDay = DateTime(now.year, now.month, now.day);
      return _health.getTotalStepsInInterval(startOfDay, now);
    });
  }

  /// Sum of `HealthDataType.STEPS` for the calendar day containing [day]
  /// (local midnight to the following midnight). Returns null when
  /// unavailable, Health Connect isn't installed, or there's no data.
  Future<int?> stepsForDay(DateTime day) async {
    if (!isAvailable) return null;
    return _guarded(null, () async {
      await _ensureConfigured();
      final start = DateTime(day.year, day.month, day.day);
      final end = start.add(const Duration(days: 1));
      return _health.getTotalStepsInInterval(start, end);
    });
  }

  /// Step totals for each of the last [lastDays] calendar days, keyed by
  /// local midnight. Days with null/0 are omitted.
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

  /// The workout activity types we treat as "strength training" — the only
  /// ones the Phase 1 import offers to pair with. HealthKit distinguishes
  /// [TRADITIONAL_STRENGTH_TRAINING]/[FUNCTIONAL_STRENGTH_TRAINING]; Health
  /// Connect has just one [STRENGTH_TRAINING] type that both collapse into
  /// when read back on Android (confirmed against the `health` package's own
  /// workout-type mapping table) — all three are listed so the filter matches
  /// on both platforms.
  static const _strengthActivityTypes = {
    HealthWorkoutActivityType.TRADITIONAL_STRENGTH_TRAINING,
    HealthWorkoutActivityType.FUNCTIONAL_STRENGTH_TRAINING,
    HealthWorkoutActivityType.STRENGTH_TRAINING,
  };

  /// Foreground read of strength workouts that **finished within [within]** of
  /// now, most-recently-finished first. This is the Phase 1 import source: the
  /// user taps "Import from Health" right after finishing their tracked
  /// workout, so it has already synced and a plain foreground query finds it
  /// — no observer/background delivery needed.
  ///
  /// Returns `[]` when unavailable, Health Connect isn't installed, or there's
  /// nothing/permission was denied (neither platform reveals READ-grant
  /// state, so empty is expected and must be tolerated).
  Future<List<HealthWorkout>> recentStrengthWorkouts({
    Duration within = const Duration(days: 1),
  }) async {
    if (!isAvailable) return const [];
    return _guarded(const [], () async {
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
      final workouts = <HealthWorkout>[];
      for (final point in points) {
        final value = point.value;
        if (value is! WorkoutHealthValue) continue;
        if (!_strengthActivityTypes.contains(value.workoutActivityType)) continue;
        if (point.dateTo.isBefore(cutoff)) continue; // ended too long ago
        workouts.add(HealthWorkout(
          uuid: point.uuid,
          startDate: point.dateFrom,
          endDate: point.dateTo,
          activeCalories: value.totalEnergyBurned?.toDouble(),
          averageHeartRate: await _averageHeartRate(point.dateFrom, point.dateTo),
        ));
      }
      workouts.sort((a, b) => b.endDate.compareTo(a.endDate));
      return workouts;
    });
  }

  /// Writes the just-finished Android watch exercise to Health Connect and
  /// returns the written record's uuid to use as `healthWorkoutId` — the
  /// Android counterpart to iOS, where the watch already writes to HealthKit
  /// directly and hands back a real `HKWorkout` uuid
  /// (docs/40-watch-app-plan.md §5.2 "Döntés: a telefon ír HC-be";
  /// [WorkoutResumePrompt] only calls this when a watch summary arrives with
  /// no `healthWorkoutId` already, i.e. the Android path).
  ///
  /// Returns null on iOS (no-op — iOS never needs this), when unavailable, or
  /// on any failure. `writeWorkoutData` itself doesn't return the created
  /// record's id, so this looks it up afterwards via [recentStrengthWorkouts],
  /// matching by closest [startDate] to [start].
  Future<String?> writeStrengthWorkoutAndGetId({
    required DateTime start,
    required DateTime end,
    double? activeCalories,
    String? title,
  }) async {
    if (!Platform.isAndroid) return null;
    return _guarded(null, () async {
      await _ensureConfigured();
      final written = await _health.writeWorkoutData(
        activityType: HealthWorkoutActivityType.STRENGTH_TRAINING,
        start: start,
        end: end,
        totalEnergyBurned: activeCalories?.round(),
        title: title,
      );
      if (!written) return null;

      final candidates = await recentStrengthWorkouts(within: const Duration(minutes: 5));
      if (candidates.isEmpty) return null;
      candidates.sort(
        (a, b) => (a.startDate.difference(start)).abs().compareTo((b.startDate.difference(start)).abs()),
      );
      return candidates.first.uuid;
    });
  }

  /// The single most recent `HealthDataType.HEART_RATE` sample (bpm) whose
  /// timestamp falls within [within] of now, or null when unavailable, Health
  /// Connect isn't installed, no permission, or no recent sample.
  ///
  /// This backs the live "current heart rate" readout shown while a session is
  /// running. Neither platform pushes live samples to a third-party app: a
  /// paired watch syncs heart-rate samples into the store in batches with a
  /// short delay, so callers poll this on an interval to get a "near-live"
  /// value rather than a true real-time stream. [within] bounds how stale a
  /// sample we're willing to surface — beyond it we'd rather show nothing than
  /// a heart rate from before the workout started.
  Future<({double bpm, DateTime timestamp})?> latestHeartRate({
    Duration within = const Duration(minutes: 5),
  }) async {
    if (!isAvailable) return null;
    return _guarded(null, () async {
      await _ensureConfigured();
      final now = DateTime.now();
      final points = await _health.getHealthDataFromTypes(
        types: const [HealthDataType.HEART_RATE],
        startTime: now.subtract(within),
        endTime: now,
      );
      if (points.isEmpty) return null;
      points.sort((a, b) => b.dateTo.compareTo(a.dateTo));
      final latest = points.first;
      final value = latest.value;
      if (value is! NumericHealthValue) return null;
      return (bpm: value.numericValue.toDouble(), timestamp: latest.dateTo);
    });
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
  /// when unavailable, Health Connect isn't installed, no permission, or no
  /// samples. Only the latest sample matters for Phase 3's import — older
  /// weights are never of interest.
  Future<({double kg, DateTime timestamp})?> latestBodyMass() async {
    if (!isAvailable) return null;
    return _guarded(null, () async {
      await _ensureConfigured();
      final now = DateTime.now();
      // A year back is generous — comfortably covers "haven't weighed in for a
      // while" without scanning someone's entire history.
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
    });
  }

  /// Body-mass (kg) samples over the last [lastDays] calendar days, collapsed to
  /// one representative per local calendar day: the latest sample of that day.
  /// Keyed by local midnight. Backs the weight screen's manual 30-day import.
  ///
  /// Unlike [stepsByDay], this issues a single query for the whole window and
  /// buckets client-side — weight samples are sparse, so one range read is
  /// cheaper than [lastDays] separate queries. Returns `{}` when unavailable,
  /// Health Connect isn't installed, no permission, or no samples.
  Future<Map<DateTime, ({double kg, DateTime timestamp})>> bodyMassByDay({
    required int lastDays,
  }) async {
    if (!isAvailable) return const {};
    return _guarded(const {}, () async {
      await _ensureConfigured();
      final now = DateTime.now();
      final start = DateTime(now.year, now.month, now.day).subtract(Duration(days: lastDays - 1));
      final points = await _health.getHealthDataFromTypes(
        types: const [HealthDataType.WEIGHT],
        startTime: start,
        endTime: now,
      );

      final byDay = <DateTime, ({double kg, DateTime timestamp})>{};
      for (final point in points) {
        final value = point.value;
        if (value is! NumericHealthValue) continue;
        final ts = point.dateTo;
        final day = DateTime(ts.year, ts.month, ts.day);
        final existing = byDay[day];
        // Keep the latest sample within each calendar day.
        if (existing == null || ts.isAfter(existing.timestamp)) {
          byDay[day] = (kg: value.numericValue.toDouble(), timestamp: ts);
        }
      }
      return byDay;
    });
  }
}

final healthServiceProvider = Provider<HealthService>((ref) => HealthService());
