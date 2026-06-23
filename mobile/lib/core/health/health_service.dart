import 'dart:io' show Platform;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:health/health.dart';

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

  // Typed read helpers (latest body mass, workouts) are added by Phase 3 —
  // Phase 1's workout reads live in HealthWorkoutObserver (native side).
}

final healthServiceProvider = Provider<HealthService>((ref) => HealthService());
