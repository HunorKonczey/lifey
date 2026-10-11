import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'health_preferences.dart';
import 'health_service.dart';

/// Copies a weigh-in the user logged in Lifey to Apple Health / Health Connect (LIF-109) - the other half of the import
/// ([WeightHealthImporter]).
///
/// Only the weigh-ins typed into the app go out, never one that came *from* Health: the importer calls the weight controller
/// directly, and this is called from the log-weight sheet, so nothing can loop. The written sample is stamped with the entry's own
/// time, which is what the importer's duplicate check compares against, so it does not come back as a "new" sample.
///
/// Best effort, silent: the weigh-in is already saved when this runs, and a refused permission or an absent Health Connect is not
/// the user's problem at that moment.
class WeightHealthWriter {
  WeightHealthWriter(this._prefs, this._service);

  final HealthPreferences _prefs;
  final HealthService _service;

  /// True when the sample was written.
  Future<bool> write({required double kg, required DateTime at}) async {
    try {
      if (!_service.isAvailable || !await _prefs.isEnabled()) return false;
      return await _service.writeBodyMass(kg: kg, at: at);
    } catch (_) {
      return false;
    }
  }
}

final weightHealthWriterProvider = Provider<WeightHealthWriter>((ref) {
  return WeightHealthWriter(ref.watch(healthPreferencesProvider), ref.watch(healthServiceProvider));
});

/// Whether a weigh-in saved now would also be written to the health store: the integration is on *and* the write permission is
/// there. Decides whether the log-weight sheet may say "Also saved to ...".
final healthWeightWriteAvailableProvider = FutureProvider.autoDispose<bool>((ref) async {
  final service = ref.watch(healthServiceProvider);
  if (!service.isAvailable) return false;
  try {
    return await ref.watch(healthPreferencesProvider).isEnabled() && await service.canWriteBodyMass();
  } catch (_) {
    return false;
  }
});
