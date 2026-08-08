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

  Future<void> _setProgramAssignedPush(bool value) async {
    try {
      await _controller.setProgramAssignedPushEnabled(value);
    } catch (e) {
      if (mounted) AppSnackbar.showError(context, title: friendlyError(e));
    }
  }

  Future<void> _setChatPush(bool value) async {
    try {
      await _controller.setChatPushEnabled(value);
    } catch (e) {
      if (mounted) AppSnackbar.showError(context, title: friendlyError(e));
    }
  }

  Future<void> _setAll(bool value) async {
    final scheduled = await _controller.setAllEnabled(value);
    if (mounted) setState(() => _permissionDenied = value && !scheduled);
  }

  /// The backend serializes a `LocalTime` as "HH:mm:ss"; the picker speaks
  /// TimeOfDay. Null-safe both ways, since "no window" is a valid state.
  static TimeOfDay? _parseTime(String? value) {
    if (value == null) return null;
    final parts = value.split(':');
    if (parts.length < 2) return null;
    final hour = int.tryParse(parts[0]);
    final minute = int.tryParse(parts[1]);
    if (hour == null || minute == null) return null;
    return TimeOfDay(hour: hour, minute: minute);
  }

  static String _toApiTime(TimeOfDay time) =>
      '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}:00';

  Future<void> _setQuietHoursEnabled(bool enabled, NotificationSettingsState state) async {
    try {
      // A sensible default window rather than an empty one: switching this on
      // and then being asked to pick two times before anything happens would
      // be a worse first step than "22:00–07:00, adjust if you like".
      await _controller.setChatQuietHours(
        enabled ? (state.chatQuietHoursStart ?? '22:00:00') : null,
        enabled ? (state.chatQuietHoursEnd ?? '07:00:00') : null,
      );
    } catch (e) {
      if (mounted) AppSnackbar.showError(context, title: friendlyError(e));
    }
  }

  Future<void> _pickQuietHour(NotificationSettingsState state, {required bool start}) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _parseTime(start ? state.chatQuietHoursStart : state.chatQuietHoursEnd) ??
          const TimeOfDay(hour: 22, minute: 0),
    );
    if (picked == null || !mounted) return;
    try {
      await _controller.setChatQuietHours(
        start ? _toApiTime(picked) : state.chatQuietHoursStart,
        start ? state.chatQuietHoursEnd : _toApiTime(picked),
      );
    } catch (e) {
      if (mounted) AppSnackbar.showError(context, title: friendlyError(e));
    }
  }

  Future<void> _pickTime(NotificationSettingsState state) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: state.weighInReminderHour, minute: state.weighInReminderMinute),
    );
    if (picked == null || !mounted) return;
    await _setWeighInReminder(true, hour: picked.hour, minute: picked.minute);
  }

  /// "HH:mm:ss" trimmed to what a button label should show.
  static String _formatApiTime(String? value) {
    final time = _parseTime(value);
    return time == null ? '--:--' : '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
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
        SwitchListTile(
          title: Text(l10n.programAssignedPushToggleLabel),
          subtitle: Text(l10n.programAssignedPushToggleSubtitle),
          value: state.programAssignedPushEnabled,
          onChanged: _setProgramAssignedPush,
        ),
        SwitchListTile(
          title: Text(l10n.chatPushToggleLabel),
          subtitle: Text(l10n.chatPushToggleSubtitle),
          value: state.chatPushEnabled,
          onChanged: _setChatPush,
        ),
        SwitchListTile(
          title: Text(l10n.chatQuietHoursLabel),
          subtitle: Text(l10n.chatQuietHoursSubtitle),
          value: state.quietHoursEnabled,
          onChanged: (value) => _setQuietHoursEnabled(value, state),
        ),
        if (state.quietHoursEnabled)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _pickQuietHour(state, start: true),
                    icon: const Icon(Icons.bedtime_outlined, size: 18),
                    label: Text(
                      '${l10n.chatQuietHoursFrom} ${_formatApiTime(state.chatQuietHoursStart)}',
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _pickQuietHour(state, start: false),
                    icon: const Icon(Icons.wb_sunny_outlined, size: 18),
                    label: Text(
                      '${l10n.chatQuietHoursTo} ${_formatApiTime(state.chatQuietHoursEnd)}',
                    ),
                  ),
                ),
              ],
            ),
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
