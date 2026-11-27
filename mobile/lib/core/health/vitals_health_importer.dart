import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/vitals/data/daily_vitals_repository.dart';
import '../utils/date_math.dart';
import 'health_preferences.dart';
import 'health_service.dart';
import 'health_vitals.dart';

/// Imports daily resting heart rate and HRV from the health store
/// (docs/integrations/89 M3, G3.3, D-G8), for example the values Garmin
/// Connect or an Apple Watch writes there.
///
/// The same rules as the cardio and sleep imports (G1.5, G2.3), adapted to
/// daily values:
/// - **Opt-in** (D-G5): runs only while both the general Health toggle and
///   the vitals-import toggle are on.
/// - **Whole days:** the read always starts at a local midnight, so a day's
///   HRV average covers the full day ([dailyVitalsFrom]).
/// - **Cursor** (D-G5): the newest sample imported. The next run re-reads
///   from the start of the day *before* the cursor's day, because a watch
///   that syncs late writes yesterday's values after today's were read. The
///   first run looks back [firstRunLookback].
/// - **Dedupe:** [DailyVitalsRepository.upsertForDay] keeps one row per day
///   and queues nothing for an unchanged day, so re-reading days is cheap.
/// - **Method:** each day's HRV goes in with the method it was measured with,
///   never mixed with the other one (D-G8).
class VitalsHealthImporter {
  VitalsHealthImporter({
    required HealthPreferences prefs,
    required HealthService service,
    required DailyVitalsRepository vitals,
    DateTime Function()? now,
  })  : _prefs = prefs,
        _service = service,
        _vitals = vitals,
        _now = now ?? DateTime.now;

  final HealthPreferences _prefs;
  final HealthService _service;
  final DailyVitalsRepository _vitals;
  final DateTime Function() _now;

  /// How far back the very first import reaches (D-G5).
  static const firstRunLookback = Duration(days: 14);

  /// The import in flight, if any: app start and app resume can fire within
  /// moments of each other. A second call joins the running one.
  Future<int>? _running;

  /// Runs one import and returns how many days it read. Best-effort: a
  /// failure imports nothing more and leaves the cursor at the last day
  /// handled, so the next resume tries again.
  Future<int> import() => _running ??= _import().whenComplete(() => _running = null);

  Future<int> _import() async {
    try {
      if (!await _prefs.isEnabled() || !await _prefs.isVitalsImportEnabled()) return 0;

      final days = await _service.recentDailyVitals(since: await _readFrom());
      for (final day in days) {
        await _vitals.upsertForDay(
          date: day.date,
          restingHr: day.restingHr,
          hrvMs: day.hrvMs,
          hrvMethod: day.hrvMethod,
        );
        // Advance after each day, oldest first, so a failure half-way resumes
        // from the first day not yet handled.
        await _prefs.setVitalsImportCursor(day.lastSampleAt);
      }
      return days.length;
    } catch (_) {
      return 0;
    }
  }

  /// Local midnight of the day before the cursor's day, or of the first-run
  /// lookback.
  Future<DateTime> _readFrom() async {
    final cursor = (await _prefs.vitalsImportCursor())?.toLocal();
    final from = cursor == null ? _now().toLocal().subtract(firstRunLookback) : addDays(cursor, -1);
    return DateTime(from.year, from.month, from.day);
  }
}

final vitalsHealthImporterProvider = Provider<VitalsHealthImporter>((ref) {
  return VitalsHealthImporter(
    prefs: ref.watch(healthPreferencesProvider),
    service: ref.watch(healthServiceProvider),
    vitals: ref.watch(dailyVitalsRepositoryProvider),
  );
});

/// Fires [VitalsHealthImporter.import] once at startup and on every app
/// resume, the same lifecycle as the cardio and sleep imports.
class VitalsImportLifecycle with WidgetsBindingObserver {
  VitalsImportLifecycle(this._importer) {
    WidgetsBinding.instance.addObserver(this);
    unawaited(_importer.import());
  }

  final VitalsHealthImporter _importer;

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

final vitalsImportLifecycleProvider = Provider<VitalsImportLifecycle>((ref) {
  final lifecycle = VitalsImportLifecycle(ref.watch(vitalsHealthImporterProvider));
  ref.onDispose(lifecycle.dispose);
  return lifecycle;
});
