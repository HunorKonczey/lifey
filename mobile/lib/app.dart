import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/health/health_workout_observer.dart';
import 'core/health/health_workout_pairing_service.dart';
import 'core/router/app_router.dart';
import 'core/sync/connectivity_sync_controller.dart';
import 'core/theme/app_theme.dart';
import 'features/auth/application/auth_controller.dart';
import 'features/settings/application/settings_controller.dart';
import 'features/settings/domain/user_settings.dart';
import 'l10n/app_localizations.dart';
import 'shared/widgets/offline_banner.dart';

/// Root application widget.
class LifeyApp extends ConsumerWidget {
  const LifeyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Wait for the stored token to be read before handing off to the router,
    // so the redirect doesn't briefly flash the dashboard or login screen.
    final authLoading = ref.watch(authControllerProvider).isLoading;
    if (authLoading) {
      return MaterialApp(
        theme: AppTheme.light,
        home: const Scaffold(body: Center(child: CircularProgressIndicator())),
      );
    }

    // Keeps itself alive for the app's lifetime; the return value is unused.
    ref.watch(connectivitySyncControllerProvider);
    // Same — starts listening for HealthKit workout-completion events (iOS only).
    // Pairing (closing + enriching a session) only runs once the user taps that
    // notification, never on detection alone.
    ref.watch(healthWorkoutObserverServiceProvider).onWorkoutNotificationTapped =
        ref.watch(healthWorkoutPairingServiceProvider).handle;

    final router = ref.watch(appRouterProvider);
    final settings = ref.watch(settingsControllerProvider).value;
    final themePreference = settings?.theme ?? ThemePreference.system;
    final languagePreference = settings?.language ?? LanguagePreference.system;

    return MaterialApp.router(
      title: 'Lifey',
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: _themeMode(themePreference),
      locale: _locale(languagePreference),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      routerConfig: router,
      // Wraps every routed screen with the global offline strip, so it
      // shows up app-wide without each screen needing to know about it.
      builder: (context, child) => Column(
        children: [
          const OfflineBanner(),
          Expanded(child: child ?? const SizedBox.shrink()),
        ],
      ),
    );
  }

  ThemeMode _themeMode(ThemePreference preference) {
    switch (preference) {
      case ThemePreference.light:
        return ThemeMode.light;
      case ThemePreference.dark:
        return ThemeMode.dark;
      case ThemePreference.system:
        return ThemeMode.system;
    }
  }

  // null tells MaterialApp to pick the best match from supportedLocales,
  // i.e. follow the device locale (falling back to en).
  Locale? _locale(LanguagePreference preference) {
    switch (preference) {
      case LanguagePreference.english:
        return const Locale('en');
      case LanguagePreference.hungarian:
        return const Locale('hu');
      case LanguagePreference.system:
        return null;
    }
  }
}
