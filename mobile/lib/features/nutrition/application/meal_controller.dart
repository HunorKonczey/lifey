import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/sync/pull_engine.dart';
import '../../../core/sync/sync_engine_provider.dart';
import '../data/meal_repository.dart';
import '../domain/meal.dart';

/// Number of meals shown per page; [MealController.loadMore] grows the
/// visible window by this amount.
const _pageSize = 40;

/// Streams logged meals from the local cache and exposes the mutations.
///
/// Pagination is purely a local-cache windowing concern: the visible window
/// is [_limit] meals (by date, most recent first), grown by [loadMore]. The
/// backend is never paged for this — see docs/14-pagination-plan.md.
///
/// Bridges the repository's per-limit stream through a single broadcast
/// [StreamController] that [build] returns once: [loadMore]/[refresh] swap
/// the repository subscription underneath (cancel-then-relisten) rather than
/// invalidating the provider, since `ref.invalidateSelf()` would construct a
/// fresh [MealController] and reset [_limit] back to [_pageSize].
class MealController extends StreamNotifier<List<Meal>> {
  MealRepository get _repo => ref.read(mealRepositoryProvider);

  int _limit = _pageSize;

  /// True if the last emitted page was full, i.e. more meals may exist
  /// beyond the current window. Requesting [_limit] + 1 rows and trimming
  /// the extra one (rather than comparing to [_limit] directly) avoids a
  /// false "no more" when there are exactly [_limit] meals.
  bool hasMore = true;

  StreamController<List<Meal>>? _controller;
  StreamSubscription<List<Meal>>? _repoSubscription;

  @override
  Stream<List<Meal>> build() {
    final controller = StreamController<List<Meal>>.broadcast();
    _controller = controller;
    ref.onDispose(() {
      _repoSubscription?.cancel();
      controller.close();
    });
    _resubscribe();
    return controller.stream;
  }

  /// Cancels any previous repository subscription and listens fresh against
  /// the current [_limit], forwarding pages into the bridging controller.
  void _resubscribe() {
    _repoSubscription?.cancel();
    _repoSubscription = _repo.watchPaged(limit: _limit + 1).listen((rows) {
      hasMore = rows.length > _limit;
      _controller?.add(hasMore ? rows.take(_limit).toList() : rows);
    });
  }

  /// Grows the visible window by one page.
  void loadMore() {
    if (!hasMore) return;
    _limit += _pageSize;
    _resubscribe();
  }

  Future<String> logMeal({
    required DateTime dateTime,
    required MealType mealType,
    required List<MealEntryInput> entries,
  }) {
    return _repo.create(dateTime: dateTime, mealType: mealType, entries: entries);
  }

  Future<void> updateMeal(
    String clientId, {
    required DateTime dateTime,
    required MealType mealType,
    required List<MealEntryInput> entries,
  }) {
    return _repo.update(clientId, dateTime: dateTime, mealType: mealType, entries: entries);
  }

  Future<void> deleteMeal(String clientId) => _repo.delete(clientId);

  /// Drains the outbox, then re-pulls from the server — matching what the
  /// dashboard's pull-to-refresh does. Without the pull half, swiping to
  /// refresh only pushes local edits and never reconciles a stale/corrupted
  /// local row with the server's truth. Also resets pagination back to the
  /// first page.
  Future<void> refresh() async {
    _limit = _pageSize;
    _resubscribe();
    try {
      await ref.read(syncEngineProvider).sync();
      await ref.read(pullEngineProvider).pullAll();
    } catch (_) {
      // Best-effort: no connectivity or a backend hiccup leaves the cache as-is.
    }
  }
}

final mealControllerProvider =
    StreamNotifierProvider<MealController, List<Meal>>(MealController.new);
