import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/sleep/data/sleep_session_repository.dart';
import 'health_preferences.dart';
import 'health_service.dart';
import 'health_sleep.dart';

/// Imports sleep sessions from the health store (docs/integrations/89 M2,
/// G2.3, D-G7), for example a Garmin night synced by Garmin Connect or an
/// Apple Watch night.
///
/// The same rules as the cardio import (G1.5):
/// - **Opt-in** (D-G5): runs only while both the general Health toggle and
///   the sleep-import toggle are on. The toggle itself is G2.4.
/// - **Cursor** (D-G5): reads from the end of the last imported session. The
///   first run looks back [firstRunLookback].
/// - **Dedupe** (D-G3): a session whose record id is already on a local row
///   is skipped. A re-import of a night the user deleted gets the server's
///   409, and the sync engine drops that local copy.
/// - **One row per session:** [HealthService.recentSleepSessions] merges the
///   session record and its stages ([mergeSleep]).
/// - **Write path:** every session goes through [SleepSessionRepository] and
///   the outbox.
class SleepHealthImporter {
  SleepHealthImporter({
    required HealthPreferences prefs,
    required HealthService service,
    required SleepSessionRepository sessions,
    DateTime Function()? now,
  })  : _prefs = prefs,
        _service = service,
        _sessions = sessions,
        _now = now ?? DateTime.now;

  final HealthPreferences _prefs;
  final HealthService _service;
  final SleepSessionRepository _sessions;
  final DateTime Function() _now;

  /// How far back the very first import reaches (D-G5).
  static const firstRunLookback = Duration(days: 14);

  /// The import in flight, if any: app start and app resume can fire within
  /// moments of each other, and two overlapping runs would both create the
  /// same night. A second call joins the running one.
  Future<int>? _running;

  /// Runs one import and returns how many sessions it created. Best-effort:
  /// a failure imports nothing more and leaves the cursor at the last
  /// session handled, so the next resume tries again.
  Future<int> import() => _running ??= _import().whenComplete(() => _running = null);

  Future<int> _import() async {
    try {
      if (!await _prefs.isEnabled() || !await _prefs.isSleepImportEnabled()) return 0;

      final since = await _prefs.sleepImportCursor() ?? _now().subtract(firstRunLookback);
      final nights = await _service.recentSleepSessions(since: since);

      var created = 0;
      for (final night in nights) {
        if (!await _sessions.existsByHealthRecordId(night.healthRecordId)) {
          await _sessions.create(
            startedAt: night.start,
            endedAt: night.end,
            asleepMinutes: night.asleepMinutes,
            deepMinutes: night.deepMinutes,
            lightMinutes: night.lightMinutes,
            remMinutes: night.remMinutes,
            awakeMinutes: night.awakeMinutes,
            sourceAppName: night.sourceName,
            healthRecordId: night.healthRecordId,
          );
          created++;
        }
        // Advance after each session, in end order, so a failure half-way
        // resumes from the first one not yet handled.
        await _prefs.setSleepImportCursor(night.end);
      }
      return created;
    } catch (_) {
      return 0;
    }
  }
}

final sleepHealthImporterProvider = Provider<SleepHealthImporter>((ref) {
  return SleepHealthImporter(
    prefs: ref.watch(healthPreferencesProvider),
    service: ref.watch(healthServiceProvider),
    sessions: ref.watch(sleepSessionRepositoryProvider),
  );
});

/// Fires [SleepHealthImporter.import] once at startup and on every app
/// resume, the same lifecycle as the cardio import.
class SleepImportLifecycle with WidgetsBindingObserver {
  SleepImportLifecycle(this._importer) {
    WidgetsBinding.instance.addObserver(this);
    unawaited(_importer.import());
  }

  final SleepHealthImporter _importer;

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

final sleepImportLifecycleProvider = Provider<SleepImportLifecycle>((ref) {
  final lifecycle = SleepImportLifecycle(ref.watch(sleepHealthImporterProvider));
  ref.onDispose(lifecycle.dispose);
  return lifecycle;
});
