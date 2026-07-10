import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/weight/application/weight_controller.dart';
import '../../features/weight/domain/weight_entry.dart';
import 'health_preferences.dart';
import 'health_service.dart';

/// Phase 3 — pulls the latest Apple Health body-weight sample into the app's
/// weight log, silently and without any UI (docs/16-apple-health-integration-plan.md).
///
/// Dedup is deliberately conservative: a HealthKit sample is only imported if
/// it's at least [_dedupWindow] away from BOTH the app's most recently logged
/// weight entry and the last sample we already imported. That avoids
/// re-importing the same real-world measurement the user just logged by hand,
/// and avoids re-adding the same Health sample every time this runs (it has
/// no other memory of "have I seen this exact sample before").
class WeightHealthImporter {
  WeightHealthImporter(this._ref);

  final Ref _ref;

  /// 30 days, not 1 — the explicit timestamp comparison against both the last
  /// import and the latest logged entry already rules out re-importing the
  /// same measurement, so widening this further doesn't risk a duplicate; it
  /// just means importing settles into "roughly monthly" cadence rather than
  /// reacting to every new HealthKit sample.
  static const _dedupWindow = Duration(days: 30);

  Future<void> import() async {
    try {
      final prefs = _ref.read(healthPreferencesProvider);
      if (!(await prefs.isEnabled())) return;

      final sample = await _ref.read(healthServiceProvider).latestBodyMass();
      if (sample == null) return;

      final lastImported = await prefs.lastHealthWeightImportedAt();
      if (lastImported != null && sample.timestamp.difference(lastImported).abs() < _dedupWindow) {
        return;
      }

      final entries = await _ref.read(weightControllerProvider.future);
      final latestEntry = _mostRecentlyLogged(entries);
      if (latestEntry != null &&
          sample.timestamp.difference(latestEntry.recordedAt).abs() < _dedupWindow) {
        return;
      }

      await _ref
          .read(weightControllerProvider.notifier)
          .addEntry(date: sample.timestamp, weight: sample.kg);
      await prefs.setLastHealthWeightImportedAt(sample.timestamp);
    } catch (_) {
      // Best-effort: no connectivity, no permission, or a backend hiccup
      // just means we try again on the next resume.
    }
  }

  WeightEntry? _mostRecentlyLogged(List<WeightEntry> entries) {
    if (entries.isEmpty) return null;
    return entries.reduce((a, b) => a.recordedAt.isAfter(b.recordedAt) ? a : b);
  }
}

final weightHealthImporterProvider = Provider<WeightHealthImporter>((ref) {
  return WeightHealthImporter(ref);
});

/// Fires [WeightHealthImporter.import] on app resume (plus once at startup,
/// since the very first "resumed" transition happens before this observer is
/// registered). The "right after permission grant" trigger lives in
/// [HealthController.setEnabled] instead, since that's a one-shot event
/// rather than a lifecycle transition. No background polling — see the plan
/// doc's Phase 3 design.
class WeightHealthImportLifecycle with WidgetsBindingObserver {
  WeightHealthImportLifecycle(this._importer) {
    WidgetsBinding.instance.addObserver(this);
    unawaited(_importer.import());
  }

  final WeightHealthImporter _importer;

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(_importer.import());
    }
  }

  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
  }
}

/// Plain (non-autoDispose) provider: instantiated once via [LifeyApp] and
/// kept alive for the app's lifetime, same as `connectivitySyncControllerProvider`.
final weightHealthImportLifecycleProvider = Provider<WeightHealthImportLifecycle>((ref) {
  final lifecycle = WeightHealthImportLifecycle(ref.watch(weightHealthImporterProvider));
  ref.onDispose(lifecycle.dispose);
  return lifecycle;
});
