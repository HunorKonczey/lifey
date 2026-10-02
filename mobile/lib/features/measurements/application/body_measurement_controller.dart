import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/sync/pull_engine.dart';
import '../../../core/sync/sync_engine_provider.dart';
import '../data/body_measurement_repository.dart';
import '../domain/body_measurement.dart';

class BodyMeasurementController extends StreamNotifier<List<BodyMeasurement>> {
  BodyMeasurementRepository get _repo => ref.read(bodyMeasurementRepositoryProvider);

  @override
  Stream<List<BodyMeasurement>> build() => _repo.watchAll();

  Future<void> add({
    required DateTime date,
    required MeasurementSite site,
    required double valueCm,
  }) =>
      _repo.create(date: date, site: site, valueCm: valueCm);

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

final bodyMeasurementControllerProvider =
    StreamNotifierProvider<BodyMeasurementController, List<BodyMeasurement>>(
  BodyMeasurementController.new,
);
