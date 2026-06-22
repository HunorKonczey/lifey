import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/local_db/app_database.dart';
import 'core/router/app_router.dart';
import 'core/sync/connectivity_sync_controller.dart';
import 'core/sync/outbox_writer.dart';
import 'core/sync/sync_status_provider.dart';
import 'core/theme/app_theme.dart';
import 'features/auth/application/auth_controller.dart';
import 'features/settings/application/settings_controller.dart';
import 'features/settings/domain/user_settings.dart';
import 'l10n/app_localizations.dart';
import 'shared/widgets/offline_banner.dart';

/// Global so [LifeyApp] can pop a SnackBar for a background sync failure
/// from outside any particular screen's [BuildContext] — see the delete
/// listener in [LifeyApp.build].
final scaffoldMessengerKey = GlobalKey<ScaffoldMessengerState>();

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

    // A delete removes the local row immediately (for a responsive UI), so
    // if the server later rejects it (e.g. 409 — still referenced by a meal,
    // recipe, or workout), there's no list item left for the usual per-item
    // SyncStatusIndicator to attach to. This is the only way that failure
    // ever reaches the user: pop a SnackBar the moment a delete op flips to
    // `failed`, with a Retry action wired to the same outbox retry used by
    // the indicator's menu.
    ref.listen<List<PendingOperationRow>>(
      pendingOperationsProvider.select((s) => s.value ?? const []),
      (previous, next) {
        final previouslyFailedIds = (previous ?? const [])
            .where((op) => op.operation == 'delete' && op.status == 'failed')
            .map((op) => op.id)
            .toSet();
        final newlyFailed = next.where((op) =>
            op.operation == 'delete' &&
            op.status == 'failed' &&
            !previouslyFailedIds.contains(op.id));
        for (final op in newlyFailed) {
          final l10n = AppLocalizations.of(context)!;
          scaffoldMessengerKey.currentState?.showSnackBar(SnackBar(
            content: Text(l10n.deleteFailedOnServerMessage),
            action: SnackBarAction(
              label: l10n.retrySyncMenuItem,
              onPressed: () => ref.read(outboxWriterProvider).retry(op.clientId),
            ),
            duration: const Duration(seconds: 8),
          ));
        }
      },
    );

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
      scaffoldMessengerKey: scaffoldMessengerKey,
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
