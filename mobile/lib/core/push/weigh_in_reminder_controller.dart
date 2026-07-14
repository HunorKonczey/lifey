import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/settings/application/settings_controller.dart';
import '../../features/settings/domain/user_settings.dart';
import '../../features/weight/data/weight_repository.dart';
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

    final scheduled = await _scheduleForToday();
    if (!scheduled) await _preferences.setEnabled(false);
    return scheduled;
  }

  Future<void> disable() async {
    await _preferences.setEnabled(false);
    await NotificationService.cancelWeighInReminder();
  }

  /// Re-evaluates today's occurrence, skipping it if weight's already been
  /// logged today. Neither the OS-scheduled notification nor its daily
  /// recurrence can know that on their own, so this must be called
  /// explicitly — on app start/resume (see [WeighInReminderRefresher]) and
  /// right after a weight entry is saved (see `WeightController.addEntry`).
  /// A no-op if the reminder isn't enabled.
  Future<void> refreshForToday() async {
    if (!await _preferences.isEnabled()) return;
    await _scheduleForToday();
  }

  Future<bool> _scheduleForToday() async {
    final time = await _preferences.time();
    final loggedToday = await _ref.read(weightRepositoryProvider).hasEntryForToday();
    final l10n = _localizations();
    return NotificationService.scheduleWeighInReminder(
      hour: time.hour,
      minute: time.minute,
      title: l10n.weighInReminderNotificationTitle,
      body: l10n.weighInReminderNotificationBody,
      skipToday: loggedToday,
    );
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

/// Calls [WeighInReminderController.refreshForToday] on app start and every
/// resume from the background, same pattern as `StepGoalNotifier` — so a
/// weigh-in logged while the app was closed still gets today's reminder
/// skipped once the app is opened again.
class WeighInReminderRefresher with WidgetsBindingObserver {
  WeighInReminderRefresher(this._ref);

  final Ref _ref;

  void init() {
    WidgetsBinding.instance.addObserver(this);
    unawaited(_ref.read(weighInReminderControllerProvider).refreshForToday());
  }

  void dispose() => WidgetsBinding.instance.removeObserver(this);

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(_ref.read(weighInReminderControllerProvider).refreshForToday());
    }
  }
}

final weighInReminderRefresherProvider = Provider<WeighInReminderRefresher>((ref) {
  final refresher = WeighInReminderRefresher(ref);
  refresher.init();
  ref.onDispose(refresher.dispose);
  return refresher;
});
