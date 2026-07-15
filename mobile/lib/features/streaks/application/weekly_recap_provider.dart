import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../nutrition/application/daily_macros_controller.dart';
import '../../settings/application/settings_controller.dart';
import '../../settings/domain/user_settings.dart';
import '../../steps/data/step_count_repository.dart';
import '../../water/application/daily_water_totals_provider.dart';
import '../../weight/application/weight_controller.dart';
import '../../workouts/application/workout_session_controller.dart';
import '../domain/weekly_recap.dart';
import 'streaks_provider.dart';

/// One [WeeklyRecap] per requested [weekStart] (local-midnight Monday) — a
/// plain derived family [Provider], same pattern as `dashboardControllerProvider`
/// and `streaksProvider`: reads `.value` off each underlying stream so a
/// still-loading source just contributes empty/default data rather than
/// blocking the whole recap.
final weeklyRecapProvider = Provider.family<WeeklyRecap, DateTime>((ref, weekStart) {
  final dailyMacros = ref.watch(dailyMacrosProvider).value ?? const [];
  final sessions = ref.watch(workoutSessionControllerProvider).value ?? const [];
  final weights = ref.watch(weightControllerProvider).value ?? const [];
  final dailyWater = ref.watch(dailyWaterTotalsProvider).value ?? const {};
  final dailySteps = ref.watch(allStepCountsProvider).value ?? const [];
  final settings = ref.watch(settingsControllerProvider).value ?? const UserSettings.defaults();
  final streaks = ref.watch(streaksProvider);

  return WeeklyRecap.compute(
    weekStart: weekStart,
    dailyMacros: dailyMacros,
    sessions: sessions,
    weights: weights,
    dailyWaterLiters: dailyWater,
    dailySteps: dailySteps,
    settings: settings,
    streaks: streaks,
  );
});

/// The default landing recap — the most recently completed week (see
/// [WeeklyRecap.lastCompletedWeekStart]). The recap screen (M5) pages
/// backwards from here by requesting other [weeklyRecapProvider] weeks.
final latestWeeklyRecapProvider = Provider<WeeklyRecap>((ref) {
  return ref.watch(weeklyRecapProvider(WeeklyRecap.lastCompletedWeekStart()));
});
