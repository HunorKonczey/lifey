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

/// Tracks the name of the topmost route on the root navigator's stack.
/// `ModalRoute.of` can't be used for this from outside the widget tree
/// (`rootNavigatorKey.currentContext` sits *above* the routes, not inside
/// one) — this observer is the workaround, letting
/// `workout_resume_prompt.dart`'s Live Activity/notification tap handling
/// tell whether the running session's screen is already on top before
/// pushing a duplicate.
class _TopRouteObserver extends NavigatorObserver {
  String? currentName;

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    currentName = route.settings.name;
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    currentName = previousRoute?.settings.name;
  }

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) {
    currentName = previousRoute?.settings.name;
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    currentName = newRoute?.settings.name;
  }
}

final _topRouteObserver = _TopRouteObserver();

/// The name of the topmost route currently on the root navigator's stack, or
/// null if it's unnamed (true of every go_router-managed page route).
String? get topRouteName => _topRouteObserver.currentName;

/// Provides the application's GoRouter configuration: public `/login` and
/// `/register` routes, plus a bottom-navigation shell (one branch per
/// top-level tab) that's gated behind being signed in.
final appRouterProvider = Provider<GoRouter>((ref) {
  final authRefresh = _AuthRefreshListenable(ref);
  ref.onDispose(authRefresh.dispose);

  return GoRouter(
    navigatorKey: rootNavigatorKey,
    observers: [_topRouteObserver],
    initialLocation: '/dashboard',
    refreshListenable: authRefresh,
    // The iOS widget/Live Activity deep links are `lifey://today` and
    // `lifey://workout`. When the app is warm in the background, iOS
    // delivers that raw URL to Flutter as-is (scheme included) instead of
    // just its path, so it never matches a GoRoute — fall back to the
    // dashboard rather than showing the "Page Not Found" error screen, and
    // for `workout` additionally jump to the running session if one exists
    // (mirrors the Android ongoing-notification tap in workout_resume_prompt.dart).
    onException: (context, state, router) {
      router.go('/dashboard');
      if (state.uri.scheme == 'lifey' && state.uri.host == 'workout') {
        unawaited(openActiveWorkoutSession(ref));
      }
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
