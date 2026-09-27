import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/error_message.dart';
import '../../../l10n/app_localizations.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../shared/widgets/app_snackbar.dart';
import '../../../shared/widgets/ds/lifey_header.dart';
import '../../../shared/widgets/ds/list_group.dart';
import '../../../shared/widgets/error_view.dart';
import '../application/notification_settings_controller.dart';
import 'widgets/settings_kit.dart';

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
      appBar: LifeySubpageHeader(title: l10n.notificationSettingsTitle),
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
    final t = Theme.of(context).textTheme;

    Widget toggle(IconData icon, String title, String subtitle, bool value, ValueChanged<bool> onChanged) => SettingsRow(
          icon: icon,
          title: title,
          subtitle: subtitle,
          trailing: SettingsSwitch(value: value, onChanged: onChanged),
        );

    return ListView(
      padding: const EdgeInsets.fromLTRB(AppSpacing.screen, AppSpacing.s8, AppSpacing.screen, AppSpacing.s32),
      children: [
        // The master switch reflects "any one is on" — no separate stored flag.
        ListGroup(children: [
          SettingsRow(
            icon: Icons.notifications_active_outlined,
            title: l10n.allNotificationsLabel,
            trailing: SettingsSwitch(value: state.anyEnabled, onChanged: _setAll),
          ),
        ]),
        const SizedBox(height: AppSpacing.s24),
        ListGroup(children: [
          toggle(Icons.fitness_center_rounded, l10n.workoutReminderToggleLabel, l10n.workoutReminderToggleSubtitle,
              state.workoutReminderEnabled, _setWorkoutReminder),
          toggle(Icons.monitor_weight_outlined, l10n.weighInReminderToggleLabel, l10n.weighInReminderToggleSubtitle,
              state.weighInReminderEnabled, (v) => _setWeighInReminder(v)),
          if (state.weighInReminderEnabled)
            SettingsRow(
              icon: Icons.schedule_rounded,
              title: l10n.reminderTimeLabel,
              onTap: () => _pickTime(state),
              trailing: SettingsValue(_formatTime(state.weighInReminderHour, state.weighInReminderMinute)),
            ),
          toggle(Icons.directions_walk_rounded, l10n.stepGoalNotificationToggleLabel, l10n.stepGoalNotificationToggleSubtitle,
              state.stepGoalNotificationEnabled, _setStepGoal),
        ]),
        const SizedBox(height: AppSpacing.s24),
        ListGroup(children: [
          toggle(Icons.rate_review_outlined, l10n.trainerCommentPushToggleLabel, l10n.trainerCommentPushToggleSubtitle,
              state.trainerCommentPushEnabled, _setTrainerCommentPush),
          toggle(Icons.flag_outlined, l10n.trainerGoalsPushToggleLabel, l10n.trainerGoalsPushToggleSubtitle,
              state.trainerGoalsPushEnabled, _setTrainerGoalsPush),
          toggle(Icons.assignment_outlined, l10n.programAssignedPushToggleLabel, l10n.programAssignedPushToggleSubtitle,
              state.programAssignedPushEnabled, _setProgramAssignedPush),
          toggle(Icons.chat_bubble_outline_rounded, l10n.chatPushToggleLabel, l10n.chatPushToggleSubtitle,
              state.chatPushEnabled, _setChatPush),
          toggle(Icons.bedtime_outlined, l10n.chatQuietHoursLabel, l10n.chatQuietHoursSubtitle, state.quietHoursEnabled,
              (value) => _setQuietHoursEnabled(value, state)),
          if (state.quietHoursEnabled)
            SettingsRow(
              icon: Icons.nights_stay_outlined,
              title: l10n.chatQuietHoursFrom,
              onTap: () => _pickQuietHour(state, start: true),
              trailing: SettingsValue(_formatApiTime(state.chatQuietHoursStart)),
            ),
          if (state.quietHoursEnabled)
            SettingsRow(
              icon: Icons.wb_sunny_outlined,
              title: l10n.chatQuietHoursTo,
              onTap: () => _pickQuietHour(state, start: false),
              trailing: SettingsValue(_formatApiTime(state.chatQuietHoursEnd)),
            ),
        ]),
        if (_permissionDenied)
          Padding(
            padding: const EdgeInsets.only(top: AppSpacing.s16, left: AppSpacing.s4, right: AppSpacing.s4),
            child: Text(
              l10n.notificationPermissionDeniedHint,
              style: t.bodyMedium!.copyWith(color: context.metricColors.heart),
            ),
          ),
      ],
    );
  }
}
