import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'features/auth/application/auth_controller.dart';

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

    final router = ref.watch(appRouterProvider);
    return MaterialApp.router(
      title: 'Lifey',
      theme: AppTheme.light,
      routerConfig: router,
    );
  }
}
