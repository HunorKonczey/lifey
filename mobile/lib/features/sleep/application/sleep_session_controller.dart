import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/sync/pull_engine.dart';
import '../../../core/sync/sync_engine_provider.dart';
import '../data/sleep_session_repository.dart';
import '../domain/sleep_session.dart';

/// Every sleep session on this device, newest wake-up first
/// (docs/integrations/89 D-G7). Creates come only from the health importer
/// (G2.3), so the controller offers delete and refresh, nothing else.
class SleepSessionController extends StreamNotifier<List<SleepSession>> {
  SleepSessionRepository get _repo => ref.read(sleepSessionRepositoryProvider);

  @override
  Stream<List<SleepSession>> build() => _repo.watchAll();

  Future<void> remove(String clientId) => _repo.delete(clientId);

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

final sleepSessionControllerProvider =
    StreamNotifierProvider<SleepSessionController, List<SleepSession>>(
  SleepSessionController.new,
);
