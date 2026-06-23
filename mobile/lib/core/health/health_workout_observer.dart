import 'dart:async';
import 'dart:convert';
import 'dart:io' show Platform;

import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'health_preferences.dart';

/// A strength workout HealthKit reported as finished. HealthKit has no live
/// "started" signal for workouts logged by another app — `HKObserverQuery`
/// only fires once the completed `HKWorkout` sample is written (see
/// docs/16-apple-health-integration-plan.md §1) — so this always describes an
/// already-finished workout.
class HealthWorkoutEvent {
  const HealthWorkoutEvent({
    required this.uuid,
    required this.startDate,
    required this.endDate,
    this.activeCalories,
    this.averageHeartRate,
  });

  factory HealthWorkoutEvent.fromChannel(Map<dynamic, dynamic> data) {
    return HealthWorkoutEvent(
      uuid: data['uuid'] as String,
      startDate: DateTime.parse(data['startDate'] as String),
      endDate: DateTime.parse(data['endDate'] as String),
      activeCalories: (data['activeCalories'] as num?)?.toDouble(),
      averageHeartRate: (data['averageHeartRate'] as num?)?.toDouble(),
    );
  }

  factory HealthWorkoutEvent.fromJson(Map<String, dynamic> json) {
    return HealthWorkoutEvent(
      uuid: json['uuid'] as String,
      startDate: DateTime.parse(json['startDate'] as String),
      endDate: DateTime.parse(json['endDate'] as String),
      activeCalories: (json['activeCalories'] as num?)?.toDouble(),
      averageHeartRate: (json['averageHeartRate'] as num?)?.toDouble(),
    );
  }

  final String uuid;
  final DateTime startDate;
  final DateTime endDate;
  final double? activeCalories;
  final double? averageHeartRate;

  Map<String, dynamic> toJson() => {
        'uuid': uuid,
        'startDate': startDate.toIso8601String(),
        'endDate': endDate.toIso8601String(),
        'activeCalories': activeCalories,
        'averageHeartRate': averageHeartRate,
      };
}

/// Listens for native HealthKit strength-workout-completion events (iOS only
/// — see the native counterpart `ios/Runner/HealthWorkoutObserver.swift`) and
/// posts a local notification for each new one.
///
/// Detection here is strictly read-only — it never touches app data. Pairing
/// only happens if/when the user taps the notification; [onWorkoutNotificationTapped]
/// is the hook the pairing flow (Prompt 1.4) attaches to.
class HealthWorkoutObserverService {
  HealthWorkoutObserverService(this._notifications, this._preferences, this._seenStorage) {
    unawaited(_start());
  }

  static const _eventChannel = EventChannel('com.lifey.health/workout_events');
  static const _seenUuidsKey = 'health.seenWorkoutUuids';
  static const _maxRemembered = 200;

  final FlutterLocalNotificationsPlugin _notifications;
  final HealthPreferences _preferences;
  final FlutterSecureStorage _seenStorage;

  StreamSubscription<dynamic>? _subscription;
  bool _initialized = false;

  /// Set by the pairing flow to receive the tapped workout's payload.
  void Function(HealthWorkoutEvent event)? onWorkoutNotificationTapped;

  Future<void> _start() async {
    if (!Platform.isIOS || _subscription != null) return;
    await _ensureInitialized();
    _subscription = _eventChannel.receiveBroadcastStream().listen(_handleEvent);
  }

  Future<void> _ensureInitialized() async {
    if (_initialized) return;
    const iosSettings = DarwinInitializationSettings();
    await _notifications.initialize(
      const InitializationSettings(iOS: iosSettings),
      onDidReceiveNotificationResponse: _onNotificationTap,
    );
    _initialized = true;
  }

  void _onNotificationTap(NotificationResponse response) {
    final payload = response.payload;
    if (payload == null) return;
    final event = HealthWorkoutEvent.fromJson(jsonDecode(payload) as Map<String, dynamic>);
    onWorkoutNotificationTapped?.call(event);
  }

  Future<void> _handleEvent(dynamic raw) async {
    if (raw is! Map) return;
    final event = HealthWorkoutEvent.fromChannel(raw);
    if (!(await _preferences.isEnabled())) return;
    if (await _isSeen(event.uuid)) return;
    await _markSeen(event.uuid);
    await _postNotification(event);
  }

  Future<void> _postNotification(HealthWorkoutEvent event) async {
    const details = NotificationDetails(
      iOS: DarwinNotificationDetails(presentAlert: true, presentSound: true),
    );
    await _notifications.show(
      event.uuid.hashCode,
      'Strength workout detected',
      'A strength workout finished in Apple Fitness. Tap to import it.',
      details,
      payload: jsonEncode(event.toJson()),
    );
  }

  Future<bool> _isSeen(String uuid) async {
    return (await _seenUuids()).contains(uuid);
  }

  Future<void> _markSeen(String uuid) async {
    final uuids = await _seenUuids();
    uuids.add(uuid);
    final trimmed =
        uuids.length > _maxRemembered ? uuids.sublist(uuids.length - _maxRemembered) : uuids;
    await _seenStorage.write(key: _seenUuidsKey, value: jsonEncode(trimmed));
  }

  Future<List<String>> _seenUuids() async {
    final raw = await _seenStorage.read(key: _seenUuidsKey);
    if (raw == null) return [];
    return (jsonDecode(raw) as List<dynamic>).cast<String>();
  }

  void dispose() {
    _subscription?.cancel();
    _subscription = null;
  }
}

final flutterLocalNotificationsPluginProvider =
    Provider<FlutterLocalNotificationsPlugin>((ref) => FlutterLocalNotificationsPlugin());

/// Plain (non-autoDispose) provider: instantiated once via [LifeyApp] and
/// kept alive for the app's lifetime, same as `connectivitySyncControllerProvider`.
final healthWorkoutObserverServiceProvider = Provider<HealthWorkoutObserverService>((ref) {
  final service = HealthWorkoutObserverService(
    ref.watch(flutterLocalNotificationsPluginProvider),
    ref.watch(healthPreferencesProvider),
    const FlutterSecureStorage(),
  );
  ref.onDispose(service.dispose);
  return service;
});
