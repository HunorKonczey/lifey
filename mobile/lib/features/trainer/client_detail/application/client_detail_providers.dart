import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/client_detail_repository.dart';
import '../domain/client_data.dart';

/// Reads behind the client detail tabs (docs/chat/41 T2).
///
/// Plain `FutureProvider.family` rather than notifiers: every one of these is
/// a read with no mutation to own, refreshed by invalidating it. The tabs
/// keep their own period/day selection as widget state, exactly as the web
/// page does — it is view state, not something worth persisting.

/// Statistics for one client and one period.
final clientStatisticsProvider = FutureProvider.family<ClientStatistics,
    ({int clientId, ClientStatisticsPeriod period})>((ref, key) {
  return ref
      .watch(clientDetailRepositoryProvider)
      .fetchStatistics(key.clientId, key.period);
});

/// The client's step history over a trailing window, oldest first.
///
/// [days] is part of the key so the overview (7 days) and the steps tab
/// (30 days) don't fight over one cache entry.
final clientStepsProvider =
    FutureProvider.family<List<ClientStepDay>, ({int clientId, int days})>(
        (ref, key) async {
  final steps = await ref.watch(clientDetailRepositoryProvider).fetchSteps(
        key.clientId,
        from: _daysAgo(key.days - 1),
      );
  // Sorted into a copy, never in place: the list belongs to whoever built
  // it, and an unmodifiable one would throw here.
  return [...steps]..sort((a, b) => a.date.compareTo(b.date));
});

/// The client's weigh-ins over a trailing window, oldest first — the order
/// the chart and the "latest / previous" delta both assume.
final clientWeightsProvider =
    FutureProvider.family<List<ClientWeightEntry>, ({int clientId, int days})>(
        (ref, key) async {
  final weights = await ref.watch(clientDetailRepositoryProvider).fetchWeights(
        key.clientId,
        from: _daysAgo(key.days - 1),
      );
  return [...weights]..sort((a, b) => a.date.compareTo(b.date));
});

/// One day of the client's meals. [day] must be a date at local midnight —
/// use [dayKey], otherwise two "same day" keys differing by a second would
/// each get their own request.
final clientMealsProvider =
    FutureProvider.family<List<ClientMeal>, ({int clientId, DateTime day})>(
        (ref, key) {
  return ref
      .watch(clientDetailRepositoryProvider)
      .fetchMealsForDay(key.clientId, key.day);
});

final clientNutritionGoalsProvider =
    FutureProvider.family<ClientNutritionGoals, int>((ref, clientId) {
  return ref.watch(clientDetailRepositoryProvider).fetchNutritionGoals(clientId);
});

/// Normalises a date to local midnight so it can be used as a family key.
DateTime dayKey(DateTime date) => DateTime(date.year, date.month, date.day);

DateTime _daysAgo(int days) {
  final today = dayKey(DateTime.now());
  return today.subtract(Duration(days: days));
}
