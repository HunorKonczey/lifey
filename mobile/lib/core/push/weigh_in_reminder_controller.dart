import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/settings/application/settings_controller.dart';
import '../../features/settings/domain/user_settings.dart';
import '../../l10n/app_localizations.dart';
import '../notifications/notification_service.dart';
import 'weigh_in_reminder_preferences.dart';

/// Enables/disables the morning weigh-in reminder
/// (docs/30-push-notifications-plan.md, M4) — the mechanism half; the
/// notification settings screen (M5, not yet built) will call
/// [enable]/[disable] from a toggle + time picker. This class owns
/// persisting the choice and (un)scheduling the actual notification, so M5
/// doesn't need to know about either `NotificationService` or
/// `WeighInReminderPreferences` directly.
class WeighInReminderController {
  WeighInReminderController(this._ref, this._preferences);

  final Ref _ref;
  final WeighInReminderPreferences _preferences;

  /// Persists the choice and schedules the daily reminder. Returns whether
  /// scheduling actually succeeded — `false` on OS permission denial, which
  /// the caller (M5) should use to revert its toggle UI rather than show it
  /// as on when nothing was actually scheduled.
  Future<bool> enable({required int hour, required int minute}) async {
    await _preferences.setEnabled(true);
    await _preferences.setTime(hour: hour, minute: minute);

    final l10n = _localizations();
    final scheduled = await NotificationService.scheduleWeighInReminder(
      hour: hour,
      minute: minute,
      title: l10n.weighInReminderNotificationTitle,
      body: l10n.weighInReminderNotificationBody,
    );
    if (!scheduled) await _preferences.setEnabled(false);
    return scheduled;
  }

  Future<void> disable() async {
    await _preferences.setEnabled(false);
    await NotificationService.cancelWeighInReminder();
  }

  // Same "no BuildContext available here" resolution `StepGoalNotifier` uses
  // for its own notification copy.
  AppLocalizations _localizations() {
    final lang = _ref.read(settingsControllerProvider).value?.language ?? LanguagePreference.system;
    final locale = lang == LanguagePreference.hungarian ? const Locale('hu') : const Locale('en');
    return lookupAppLocalizations(locale);
  }
}

final weighInReminderControllerProvider = Provider<WeighInReminderController>((ref) {
  return WeighInReminderController(ref, ref.watch(weighInReminderPreferencesProvider));
});
