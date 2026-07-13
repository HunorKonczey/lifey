import 'package:flutter_test/flutter_test.dart';
import 'package:lifey/features/settings/application/notification_settings_controller.dart';

NotificationSettingsState _state({
  bool workoutReminderEnabled = false,
  bool weighInReminderEnabled = false,
  bool stepGoalNotificationEnabled = false,
  bool trainerCommentPushEnabled = false,
  bool trainerGoalsPushEnabled = false,
}) {
  return NotificationSettingsState(
    workoutReminderEnabled: workoutReminderEnabled,
    weighInReminderEnabled: weighInReminderEnabled,
    weighInReminderHour: 8,
    weighInReminderMinute: 0,
    stepGoalNotificationEnabled: stepGoalNotificationEnabled,
    trainerCommentPushEnabled: trainerCommentPushEnabled,
    trainerGoalsPushEnabled: trainerGoalsPushEnabled,
  );
}

void main() {
  group('anyEnabled', () {
    test('is false when every type is off', () {
      expect(_state().anyEnabled, isFalse);
    });

    test('is true when only the workout reminder is on', () {
      expect(_state(workoutReminderEnabled: true).anyEnabled, isTrue);
    });

    test('is true when only the weigh-in reminder is on', () {
      expect(_state(weighInReminderEnabled: true).anyEnabled, isTrue);
    });

    test('is true when only the step-goal notification is on', () {
      expect(_state(stepGoalNotificationEnabled: true).anyEnabled, isTrue);
    });

    test('is true when only trainer comments are on', () {
      expect(_state(trainerCommentPushEnabled: true).anyEnabled, isTrue);
    });

    test('is true when only trainer nutrition goal changes are on', () {
      expect(_state(trainerGoalsPushEnabled: true).anyEnabled, isTrue);
    });

    test('is true when every type is on', () {
      expect(
        _state(
          workoutReminderEnabled: true,
          weighInReminderEnabled: true,
          stepGoalNotificationEnabled: true,
          trainerCommentPushEnabled: true,
          trainerGoalsPushEnabled: true,
        ).anyEnabled,
        isTrue,
      );
    });
  });

  group('copyWith', () {
    test('overrides only the given fields, keeping the rest', () {
      final original = _state(workoutReminderEnabled: true);

      final updated = original.copyWith(weighInReminderEnabled: true, weighInReminderHour: 19);

      expect(updated.workoutReminderEnabled, isTrue);
      expect(updated.weighInReminderEnabled, isTrue);
      expect(updated.weighInReminderHour, 19);
      expect(updated.weighInReminderMinute, 0);
      expect(updated.stepGoalNotificationEnabled, isFalse);
      expect(updated.trainerCommentPushEnabled, isFalse);
      expect(updated.trainerGoalsPushEnabled, isFalse);
    });

    test('with no arguments returns an equivalent state', () {
      final original = _state(workoutReminderEnabled: true, weighInReminderEnabled: true);

      final updated = original.copyWith();

      expect(updated.workoutReminderEnabled, original.workoutReminderEnabled);
      expect(updated.weighInReminderEnabled, original.weighInReminderEnabled);
      expect(updated.weighInReminderHour, original.weighInReminderHour);
      expect(updated.weighInReminderMinute, original.weighInReminderMinute);
      expect(updated.stepGoalNotificationEnabled, original.stepGoalNotificationEnabled);
      expect(updated.trainerCommentPushEnabled, original.trainerCommentPushEnabled);
      expect(updated.trainerGoalsPushEnabled, original.trainerGoalsPushEnabled);
    });
  });
}
