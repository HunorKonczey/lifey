import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../settings/application/settings_controller.dart';
import '../../settings/domain/user_settings.dart';
import '../domain/daily_macros.dart';
import '../domain/remaining_budget.dart';
import 'daily_macros_controller.dart';

/// Today's remaining calorie/protein budget — goal minus what's already
/// logged today. Derived from [dailyMacrosProvider] (today's bucket is
/// always exact regardless of meal pagination, per that provider's docs) and
/// [settingsControllerProvider].
///
/// Live by construction: [LogMealScreen] autosaves every entry change to
/// Drift, so this updates as the user builds a meal — no separate delta
/// tracking needed while a meal is being edited.
final remainingBudgetProvider = Provider<AsyncValue<RemainingBudget>>((ref) {
  final macrosAsync = ref.watch(dailyMacrosProvider);
  final settingsAsync = ref.watch(settingsControllerProvider);

  return macrosAsync.when(
    loading: () => const AsyncValue.loading(),
    error: (e, st) => AsyncValue.error(e, st),
    data: (days) {
      final settings = settingsAsync.value ?? const UserSettings.defaults();
      final today = _todayBucket(days);
      return AsyncValue.data(RemainingBudget.compute(today, settings));
    },
  );
});

DailyMacros? _todayBucket(List<DailyMacros> days) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  for (final day in days) {
    if (day.day == today) return day;
  }
  return null;
}
