import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/sync/pull_engine.dart';
import '../../../core/sync/sync_engine_provider.dart';
import '../data/food_repository.dart';
import '../domain/food.dart';

/// Number of foods shown per page; [FoodController.loadMore] grows the
/// visible window by this amount.
const _pageSize = 40;

/// Streams foods from the local cache and exposes the mutations themselves.
///
/// Pagination is purely a local-cache windowing concern: the visible window
/// is [_limit] foods (by name), grown by [loadMore]. The backend is never
/// paged for this — see docs/14-pagination-plan.md.
///
/// Bridges the repository's per-limit stream through a single broadcast
/// [StreamController] that [build] returns once: [loadMore]/[refresh] swap
/// the repository subscription underneath (cancel-then-relisten) rather than
/// invalidating the provider, since `ref.invalidateSelf()` would construct a
/// fresh [FoodController] and reset [_limit] back to [_pageSize].
class FoodController extends StreamNotifier<List<Food>> {
  FoodRepository get _repo => ref.read(foodRepositoryProvider);

  int _limit = _pageSize;

  /// True if the last emitted page was full, i.e. more foods may exist
  /// beyond the current window. Requesting [_limit] + 1 rows and trimming
  /// the extra one (rather than comparing to [_limit] directly) avoids a
  /// false "no more" when the table has exactly [_limit] rows.
  bool hasMore = true;

  StreamController<List<Food>>? _controller;
  StreamSubscription<List<Food>>? _repoSubscription;

  @override
  Stream<List<Food>> build() {
    final controller = StreamController<List<Food>>.broadcast();
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

  Future<void> addFood({
    required String name,
    required double calories,
    required double protein,
    double? carbs,
    double? fat,
    String? barcode,
  }) {
    return _repo.create(
        name: name, calories: calories, protein: protein, carbs: carbs, fat: fat, barcode: barcode);
  }

  Future<void> updateFood(
    String clientId, {
    required String name,
    required double calories,
    required double protein,
    double? carbs,
    double? fat,
    String? barcode,
  }) {
    return _repo.update(clientId,
        name: name, calories: calories, protein: protein, carbs: carbs, fat: fat, barcode: barcode);
  }

  Future<void> deleteFood(String clientId) {
    return _repo.delete(clientId);
  }

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

final foodControllerProvider =
    StreamNotifierProvider<FoodController, List<Food>>(FoodController.new);
