import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/health/health_preferences.dart';
import '../../../core/push/weigh_in_reminder_controller.dart';
import '../../../core/push/weigh_in_reminder_preferences.dart';
import 'settings_controller.dart';

/// Composed view state for the notification settings screen
/// (docs/30-push-notifications-plan.md, M5) — the three notification types
/// live in different backing stores (server `UserSettings`, two device-local
/// prefs), but the screen shouldn't need to know that.
class NotificationSettingsState {
  const NotificationSettingsState({
    required this.workoutReminderEnabled,
    required this.weighInReminderEnabled,
    required this.weighInReminderHour,
    required this.weighInReminderMinute,
    required this.stepGoalNotificationEnabled,
    required this.trainerCommentPushEnabled,
    required this.trainerGoalsPushEnabled,
  });

  final bool workoutReminderEnabled;
  final bool weighInReminderEnabled;
  final int weighInReminderHour;
  final int weighInReminderMinute;
  final bool stepGoalNotificationEnabled;
  final bool trainerCommentPushEnabled;
  final bool trainerGoalsPushEnabled;

  /// The master switch reflects this — "on" the moment any one type is,
  /// no separate stored flag (see `WeighInReminderController` / the plan's
  /// M5 section for the "what you see is what's stored" rationale).
  bool get anyEnabled =>
      workoutReminderEnabled ||
      weighInReminderEnabled ||
      stepGoalNotificationEnabled ||
      trainerCommentPushEnabled ||
      trainerGoalsPushEnabled;

  NotificationSettingsState copyWith({
    bool? workoutReminderEnabled,
    bool? weighInReminderEnabled,
    int? weighInReminderHour,
    int? weighInReminderMinute,
    bool? stepGoalNotificationEnabled,
    bool? trainerCommentPushEnabled,
    bool? trainerGoalsPushEnabled,
  }) {
    return NotificationSettingsState(
      workoutReminderEnabled: workoutReminderEnabled ?? this.workoutReminderEnabled,
      weighInReminderEnabled: weighInReminderEnabled ?? this.weighInReminderEnabled,
      weighInReminderHour: weighInReminderHour ?? this.weighInReminderHour,
      weighInReminderMinute: weighInReminderMinute ?? this.weighInReminderMinute,
      stepGoalNotificationEnabled: stepGoalNotificationEnabled ?? this.stepGoalNotificationEnabled,
      trainerCommentPushEnabled: trainerCommentPushEnabled ?? this.trainerCommentPushEnabled,
      trainerGoalsPushEnabled: trainerGoalsPushEnabled ?? this.trainerGoalsPushEnabled,
    );
  }
}

class NotificationSettingsController extends AsyncNotifier<NotificationSettingsState> {
  WeighInReminderPreferences get _weighInPrefs => ref.read(weighInReminderPreferencesProvider);
  HealthPreferences get _healthPrefs => ref.read(healthPreferencesProvider);

  @override
  Future<NotificationSettingsState> build() async {
    // Rebuilds whenever the synced settings change (e.g. another device
    // flipped the workout-reminder toggle) — the two local prefs are only
    // re-read when this controller itself changes them (see the explicit
    // `state = ...` assignments below), since they aren't stream-backed.
    final settings = await ref.watch(settingsControllerProvider.future);
    final weighInEnabled = await _weighInPrefs.isEnabled();
    final weighInTime = await _weighInPrefs.time();
    final stepGoalEnabled = await _healthPrefs.isStepGoalNotificationEnabled();

    return NotificationSettingsState(
      workoutReminderEnabled: settings.workoutReminderEnabled,
      weighInReminderEnabled: weighInEnabled,
      weighInReminderHour: weighInTime.hour,
      weighInReminderMinute: weighInTime.minute,
      stepGoalNotificationEnabled: stepGoalEnabled,
      trainerCommentPushEnabled: settings.trainerCommentPushEnabled,
      trainerGoalsPushEnabled: settings.trainerGoalsPushEnabled,
    );
  }

  /// Optimistic flip with rollback on failure. Unlike the web/API model this
  /// was originally specified against, the mobile app is offline-first: this
  /// writes to the local cache + outbox (see `SettingsRepository`), which
  /// doesn't itself talk to the network, so "failure" here means a local
  /// write error, not a server round-trip — sync to the backend happens
  /// later, in the background, regardless.
  Future<void> setWorkoutReminderEnabled(bool enabled) async {
    final current = state.value;
    if (current == null) return;
    state = AsyncValue.data(current.copyWith(workoutReminderEnabled: enabled));
    try {
      final settings = await ref.read(settingsControllerProvider.future);
      await ref
          .read(settingsControllerProvider.notifier)
          .save(settings.copyWith(workoutReminderEnabled: enabled));
    } catch (_) {
      state = AsyncValue.data(current);
      rethrow;
    }
  }

  /// Returns whether it actually got scheduled (`false` on OS permission
  /// denial) — the screen should show the permission-denied hint in that case.
  Future<bool> setWeighInReminderEnabled(
    bool enabled, {
    int? hour,
    int? minute,
  }) async {
    final current = state.value;
    if (current == null) return false;

    if (!enabled) {
      await ref.read(weighInReminderControllerProvider).disable();
      state = AsyncValue.data(current.copyWith(weighInReminderEnabled: false));
      return true;
    }

    final effectiveHour = hour ?? current.weighInReminderHour;
    final effectiveMinute = minute ?? current.weighInReminderMinute;
    final scheduled = await ref
        .read(weighInReminderControllerProvider)
        .enable(hour: effectiveHour, minute: effectiveMinute);
    state = AsyncValue.data(current.copyWith(
      weighInReminderEnabled: scheduled,
      weighInReminderHour: effectiveHour,
      weighInReminderMinute: effectiveMinute,
    ));
    return scheduled;
  }

  Future<void> setStepGoalNotificationEnabled(bool enabled) async {
    final current = state.value;
    if (current == null) return;
    await _healthPrefs.setStepGoalNotificationEnabled(enabled);
    state = AsyncValue.data(current.copyWith(stepGoalNotificationEnabled: enabled));
  }

  /// Same optimistic-flip-with-rollback shape as [setWorkoutReminderEnabled]
  /// — see docs/31-session-feedback-loop-plan.md, M3.
  Future<void> setTrainerCommentPushEnabled(bool enabled) async {
    final current = state.value;
    if (current == null) return;
    state = AsyncValue.data(current.copyWith(trainerCommentPushEnabled: enabled));
    try {
      final settings = await ref.read(settingsControllerProvider.future);
      await ref
          .read(settingsControllerProvider.notifier)
          .save(settings.copyWith(trainerCommentPushEnabled: enabled));
    } catch (_) {
      state = AsyncValue.data(current);
      rethrow;
    }
  }

  /// Same optimistic-flip-with-rollback shape as [setWorkoutReminderEnabled]
  /// — see docs/32-trainer-nutrition-goals-plan.md, M1.
  Future<void> setTrainerGoalsPushEnabled(bool enabled) async {
    final current = state.value;
    if (current == null) return;
    state = AsyncValue.data(current.copyWith(trainerGoalsPushEnabled: enabled));
    try {
      final settings = await ref.read(settingsControllerProvider.future);
      await ref
          .read(settingsControllerProvider.notifier)
          .save(settings.copyWith(trainerGoalsPushEnabled: enabled));
    } catch (_) {
      state = AsyncValue.data(current);
      rethrow;
    }
  }

  /// Master switch: bulk action, not a separate stored gate — flips every
  /// type to [enabled]. Returns whether the weigh-in reminder actually got
  /// scheduled when turning everything on (irrelevant, and always `true`,
  /// when turning everything off).
  Future<bool> setAllEnabled(bool enabled) async {
    await setWorkoutReminderEnabled(enabled);
    final weighInScheduled = await setWeighInReminderEnabled(enabled);
    await setStepGoalNotificationEnabled(enabled);
    await setTrainerCommentPushEnabled(enabled);
    await setTrainerGoalsPushEnabled(enabled);
    return weighInScheduled;
  }
}

final notificationSettingsControllerProvider =
    AsyncNotifierProvider<NotificationSettingsController, NotificationSettingsState>(
  NotificationSettingsController.new,
);
