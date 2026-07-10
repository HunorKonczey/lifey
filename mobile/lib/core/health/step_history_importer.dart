import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/steps/data/step_count_repository.dart';
import '../sync/outbox_writer.dart';
import 'health_preferences.dart';
import 'health_service.dart';

/// Reads the last [_backfillDays] days of steps from Apple Health and upserts
/// each day's total into [StepCountRepository]. Because [upsertForDay] is
/// idempotent per date, re-running on every app resume is safe — it simply
/// refreshes each day's running total rather than duplicating rows.
///
/// iOS-only: all calls no-op silently on Android via [HealthService.isAvailable].
class StepHistoryImporter {
  StepHistoryImporter(this._ref);

  final Ref _ref;

  static const _backfillDays = 7;

  Future<void> import() async {
    try {
      final prefs = _ref.read(healthPreferencesProvider);
      if (!(await prefs.isEnabled())) return;

      // Reset any step-count ops that previously failed with a non-network
      // error (e.g. a @PastOrPresent 400 during the 2-hour UTC lag window)
      // so they are retried now that the server clock has caught up.
      await _ref.read(outboxWriterProvider).resetFailed('daily_step_count');

      final service = _ref.read(healthServiceProvider);
      final repo = _ref.read(stepCountRepositoryProvider);

      final stepsByDay = await service.stepsByDay(lastDays: _backfillDays);
      for (final entry in stepsByDay.entries) {
        await repo.upsertForDay(date: entry.key, steps: entry.value);
      }
    } catch (_) {
      // Best-effort: no connectivity, no permission, or a HealthKit hiccup
      // just means we try again on the next resume.
    }
  }
}

final stepHistoryImporterProvider = Provider<StepHistoryImporter>((ref) {
  return StepHistoryImporter(ref);
});

/// Fires [StepHistoryImporter.import] once at startup and on every app resume,
/// mirroring the weight import lifecycle. The "right after permission grant"
/// trigger lives in [HealthController.setEnabled].
class StepImportLifecycle with WidgetsBindingObserver {
  StepImportLifecycle(this._importer) {
    WidgetsBinding.instance.addObserver(this);
    unawaited(_importer.import());
  }

  final StepHistoryImporter _importer;

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

final stepImportLifecycleProvider = Provider<StepImportLifecycle>((ref) {
  final lifecycle = StepImportLifecycle(ref.watch(stepHistoryImporterProvider));
  ref.onDispose(lifecycle.dispose);
  return lifecycle;
});
