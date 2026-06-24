import 'dart:async';
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/settings/application/settings_controller.dart';
import '../../features/settings/domain/user_settings.dart';
import '../../l10n/app_localizations.dart';
import '../notifications/notification_service.dart';
import 'health_preferences.dart';
import 'health_service.dart';

/// Fires a local notification when the user hits their daily step goal.
///
/// Runs on app startup and every time the app resumes from the background
/// (iOS only). At most one notification is sent per calendar day — the date
/// is persisted in [HealthPreferences] to survive app restarts.
///
/// This is a foreground / resume check, not a background observer. True
/// background delivery (HKObserverQuery + background entitlement) is out of
/// scope and was explicitly removed in Prompt 1.6.
class StepGoalNotifier with WidgetsBindingObserver {
  StepGoalNotifier(this._ref);

  final Ref _ref;

  void init() {
    WidgetsBinding.instance.addObserver(this);
    unawaited(_setup());
  }

  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) unawaited(_check());
  }

  Future<void> _setup() async {
    await NotificationService.init();
    await _check();
  }

  Future<void> _check() async {
    if (!Platform.isIOS) return;

    final prefs = _ref.read(healthPreferencesProvider);
    if (!await prefs.isEnabled()) return;

    final settings = _ref.read(settingsControllerProvider).value;
    final goal = settings?.dailyStepGoal;
    if (goal == null || goal <= 0) return;

    final steps = await _ref.read(healthServiceProvider).stepsForDay(DateTime.now());
    if (steps == null || steps < goal) return;

    // Dedup: only fire once per calendar day.
    final today = DateTime.now();
    final last = await prefs.lastStepGoalNotifiedDate();
    if (last != null &&
        last.year == today.year &&
        last.month == today.month &&
        last.day == today.day) {
      return;
    }

    final lang = settings?.language ?? LanguagePreference.system;
    final locale = lang == LanguagePreference.hungarian
        ? const Locale('hu')
        : const Locale('en');
    final l10n = lookupAppLocalizations(locale);

    await NotificationService.showGoalReached(
      title: l10n.stepGoalNotificationTitle,
      body: l10n.stepGoalNotificationBody(steps),
    );
    await prefs.setLastStepGoalNotifiedDate(today);
  }
}

final stepGoalNotifierProvider = Provider<StepGoalNotifier>((ref) {
  final notifier = StepGoalNotifier(ref);
  notifier.init();
  ref.onDispose(notifier.dispose);
  return notifier;
});
