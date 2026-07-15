import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/water_entry_repository.dart';

/// Full-history per-day water totals (local calendar day → liters logged).
///
/// An aggregation of [allWaterEntriesProvider]'s already-unbounded stream —
/// unlike the meals side (see `daily_macros_controller.dart`), there's no
/// separate paged UI window to work around here, so no new repository query
/// is needed, only a day-bucketing pass in Dart. Feeds the water streak
/// (docs/37-streaks-weekly-recap-plan.md) and the weekly recap.
final dailyWaterTotalsProvider = Provider<AsyncValue<Map<DateTime, double>>>((ref) {
  return ref.watch(allWaterEntriesProvider).whenData((entries) {
    final byDay = <DateTime, double>{};
    for (final entry in entries) {
      final local = entry.consumedAt.toLocal();
      final day = DateTime(local.year, local.month, local.day);
      byDay.update(day, (sum) => sum + entry.volumeLiters, ifAbsent: () => entry.volumeLiters);
    }
    return byDay;
  });
});
