import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/sync/pull_engine.dart';
import '../../../core/sync/sync_engine_provider.dart';
import '../data/daily_vitals_repository.dart';
import '../domain/daily_vitals.dart';

/// Every day of vitals on this device, newest first (docs/integrations/89
/// D-G8). Writes come from the vitals importer (G3.3); the trend cards
/// (G3.4) read this.
class DailyVitalsController extends StreamNotifier<List<DailyVitals>> {
  DailyVitalsRepository get _repo => ref.read(dailyVitalsRepositoryProvider);

  @override
  Stream<List<DailyVitals>> build() => _repo.watchAll();

  /// Push then pull; connectivity errors are swallowed — the local data is
  /// still shown and the next sync retries.
  Future<void> refresh() async {
    try {
      await ref.read(syncEngineProvider).sync();
      await ref.read(pullEngineProvider).pullAll();
    } catch (_) {
      // Offline: keep showing the local cache.
    }
  }
}

final dailyVitalsControllerProvider =
    StreamNotifierProvider<DailyVitalsController, List<DailyVitals>>(DailyVitalsController.new);
