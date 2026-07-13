import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/error_message.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/widgets/app_snackbar.dart';
import '../../../shared/widgets/error_view.dart';
import '../application/notification_settings_controller.dart';

/// Per-type notification toggles + a master switch
/// (docs/30-push-notifications-plan.md, M5). Reached from a "Notifications"
/// row on the main settings screen.
class NotificationSettingsScreen extends ConsumerStatefulWidget {
  const NotificationSettingsScreen({super.key});

  @override
  ConsumerState<NotificationSettingsScreen> createState() => _NotificationSettingsScreenState();
}

class _NotificationSettingsScreenState extends ConsumerState<NotificationSettingsScreen> {
  // Shown after an enable attempt where the OS actually denied permission —
  // not persisted, just reflects the most recent attempt in this screen visit.
  bool _permissionDenied = false;

  NotificationSettingsController get _controller =>
      ref.read(notificationSettingsControllerProvider.notifier);

  Future<void> _setWorkoutReminder(bool value) async {
    try {
      await _controller.setWorkoutReminderEnabled(value);
    } catch (e) {
      if (mounted) AppSnackbar.showError(context, title: friendlyError(e));
    }
  }

  Future<void> _setWeighInReminder(bool value, {int? hour, int? minute}) async {
    final scheduled = await _controller.setWeighInReminderEnabled(value, hour: hour, minute: minute);
    if (mounted) setState(() => _permissionDenied = value && !scheduled);
  }

  Future<void> _setStepGoal(bool value) => _controller.setStepGoalNotificationEnabled(value);

  Future<void> _setTrainerCommentPush(bool value) async {
    try {
      await _controller.setTrainerCommentPushEnabled(value);
    } catch (e) {
      if (mounted) AppSnackbar.showError(context, title: friendlyError(e));
    }
  }

  Future<void> _setTrainerGoalsPush(bool value) async {
    try {
      await _controller.setTrainerGoalsPushEnabled(value);
    } catch (e) {
      if (mounted) AppSnackbar.showError(context, title: friendlyError(e));
    }
  }

  Future<void> _setAll(bool value) async {
    final scheduled = await _controller.setAllEnabled(value);
    if (mounted) setState(() => _permissionDenied = value && !scheduled);
  }

  Future<void> _pickTime(NotificationSettingsState state) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: state.weighInReminderHour, minute: state.weighInReminderMinute),
    );
    if (picked == null || !mounted) return;
    await _setWeighInReminder(true, hour: picked.hour, minute: picked.minute);
  }

  String _formatTime(int hour, int minute) {
    return '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final async = ref.watch(notificationSettingsControllerProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.notificationSettingsTitle)),
      body: async.when(
        data: (state) => _buildList(context, l10n, state),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => ErrorView(
          error: error,
          onRetry: () => ref.invalidate(notificationSettingsControllerProvider),
        ),
      ),
    );
  }

  Widget _buildList(BuildContext context, AppLocalizations l10n, NotificationSettingsState state) {
    final scheme = Theme.of(context).colorScheme;
    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 8),
      children: [
        SwitchListTile(
          title: Text(
            l10n.allNotificationsLabel,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          value: state.anyEnabled,
          onChanged: _setAll,
        ),
        const Divider(height: 1),
        SwitchListTile(
          title: Text(l10n.workoutReminderToggleLabel),
          subtitle: Text(l10n.workoutReminderToggleSubtitle),
          value: state.workoutReminderEnabled,
          onChanged: _setWorkoutReminder,
        ),
        SwitchListTile(
          title: Text(l10n.weighInReminderToggleLabel),
          subtitle: Text(l10n.weighInReminderToggleSubtitle),
          value: state.weighInReminderEnabled,
          onChanged: (v) => _setWeighInReminder(v),
        ),
        if (state.weighInReminderEnabled)
          ListTile(
            contentPadding: const EdgeInsets.only(left: 32, right: 16),
            title: Text(l10n.reminderTimeLabel),
            trailing: Text(_formatTime(state.weighInReminderHour, state.weighInReminderMinute)),
            onTap: () => _pickTime(state),
          ),
        SwitchListTile(
          title: Text(l10n.stepGoalNotificationToggleLabel),
          subtitle: Text(l10n.stepGoalNotificationToggleSubtitle),
          value: state.stepGoalNotificationEnabled,
          onChanged: _setStepGoal,
        ),
        SwitchListTile(
          title: Text(l10n.trainerCommentPushToggleLabel),
          subtitle: Text(l10n.trainerCommentPushToggleSubtitle),
          value: state.trainerCommentPushEnabled,
          onChanged: _setTrainerCommentPush,
        ),
        SwitchListTile(
          title: Text(l10n.trainerGoalsPushToggleLabel),
          subtitle: Text(l10n.trainerGoalsPushToggleSubtitle),
          value: state.trainerGoalsPushEnabled,
          onChanged: _setTrainerGoalsPush,
        ),
        if (_permissionDenied)
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              l10n.notificationPermissionDeniedHint,
              style: TextStyle(color: scheme.error),
            ),
          ),
      ],
    );
  }
}
