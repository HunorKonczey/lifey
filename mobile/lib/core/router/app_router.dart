import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/application/auth_controller.dart';
import '../../features/auth/presentation/forgot_password_screen.dart';
import '../../features/auth/presentation/login_screen.dart';
import '../../features/auth/presentation/register_screen.dart';
import '../../features/dashboard/presentation/dashboard_screen.dart';
import '../../features/nutrition/presentation/nutrition_screen.dart';
import '../../features/onboarding/presentation/onboarding_screen.dart';
import '../../features/settings/presentation/settings_screen.dart';
import '../../features/statistics/presentation/statistics_screen.dart';
import '../../features/streaks/presentation/weekly_recap_screen.dart';
import '../../features/weight/presentation/weight_screen.dart';
import '../../features/workouts/application/workout_resume_prompt.dart';
import '../../features/workouts/presentation/workouts_screen.dart';
import '../../shared/widgets/main_shell.dart';

/// Notifies GoRouter to re-run its redirect whenever the signed-in user changes.
class _AuthRefreshListenable extends ChangeNotifier {
  _AuthRefreshListenable(Ref ref) {
    ref.listen(authControllerProvider, (_, __) => notifyListeners());
  }
}

/// The router's top-level navigator key — also lets code outside the widget
/// tree reach a [BuildContext] via `rootNavigatorKey.currentContext` if needed.
final rootNavigatorKey = GlobalKey<NavigatorState>();

/// Provides the application's GoRouter configuration: public `/login` and
/// `/register` routes, plus a bottom-navigation shell (one branch per
/// top-level tab) that's gated behind being signed in.
final appRouterProvider = Provider<GoRouter>((ref) {
  final authRefresh = _AuthRefreshListenable(ref);
  ref.onDispose(authRefresh.dispose);

  return GoRouter(
    navigatorKey: rootNavigatorKey,
    initialLocation: '/dashboard',
    refreshListenable: authRefresh,
    // The iOS widget/Live Activity deep links are `lifey://today` and
    // `lifey://workout`. When the app is warm in the background, iOS
    // delivers that raw URL to Flutter as-is (scheme included) instead of
    // just its path, so it never matches a GoRoute — fall back to the
    // dashboard rather than showing the "Page Not Found" error screen, and
    // for `workout` additionally jump to the running session if one exists
    // (mirrors the Android ongoing-notification tap in workout_resume_prompt.dart).
    // Only falls back to the dashboard once `openActiveWorkoutSession`
    // confirms there's nothing to reopen — it must not run unconditionally,
    // since a live LogSessionScreen may already be showing the correct state.
    onException: (context, state, router) {
      if (state.uri.scheme == 'lifey' && state.uri.host == 'workout') {
        unawaited(() async {
          final opened = await openActiveWorkoutSession(ref);
          if (!opened) router.go('/dashboard');
        }());
        return;
      }
      router.go('/dashboard');
    },
    redirect: (context, state) {
      final auth = ref.read(authControllerProvider);
      if (auth.isLoading) return null;

      final isLoggedIn = auth.value != null;
      final isAuthRoute = state.matchedLocation == '/login' ||
          state.matchedLocation == '/register' ||
          state.matchedLocation == '/forgot-password';

      if (!isLoggedIn && !isAuthRoute) return '/login';
      if (isLoggedIn && isAuthRoute) return '/dashboard';
      return null;
    },
    routes: [
      GoRoute(path: '/login', builder: (context, state) => const LoginScreen()),
      GoRoute(path: '/register', builder: (context, state) => const RegisterScreen()),
      GoRoute(
        path: '/forgot-password',
        builder: (context, state) => const ForgotPasswordScreen(),
      ),
      GoRoute(path: '/settings', builder: (context, state) => const SettingsScreen()),
      GoRoute(path: '/recap', builder: (context, state) => const WeeklyRecapScreen()),
      GoRoute(path: '/onboarding', builder: (context, state) => const OnboardingScreen()),
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) =>
            MainShell(navigationShell: navigationShell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/dashboard',
                builder: (context, state) => const DashboardScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/nutrition',
                builder: (context, state) => const NutritionScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/workouts',
                builder: (context, state) => const WorkoutsScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/weight',
                builder: (context, state) => const WeightScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/statistics',
                builder: (context, state) => const StatisticsScreen(),
              ),
            ],
          ),
        ],
      ),
    ],
  );
});
