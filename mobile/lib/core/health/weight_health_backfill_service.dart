import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/weight/application/weight_controller.dart';
import '../../features/weight/domain/weight_entry.dart';
import 'health_service.dart';

/// Backs the manual "Import from Apple Health" button on the weight screen — a
/// fully user-initiated 30-day backfill of body-mass samples.
///
/// Dedup mirrors the steps importer's per-day idempotency rather than the
/// silent [WeightHealthImporter]'s timestamp-window heuristic: at most one
/// weight entry per calendar day, and a day that already has an entry (logged
/// manually or imported earlier) is skipped. So re-tapping the button is a
/// no-op, and it never overwrites or double-counts a manual measurement.
class WeightHealthBackfillService {
  WeightHealthBackfillService(this._ref);

  final Ref _ref;

  static const _backfillDays = 30;

  /// Imports any of the last [_backfillDays] days that have an Apple Health
  /// body-mass sample but no existing weight entry. Returns the number of
  /// entries created. Throws on failure so the UI can surface an error — unlike
  /// the best-effort background importers, this is an explicit user action.
  Future<int> backfill() async {
    final byDay = await _ref.read(healthServiceProvider).bodyMassByDay(lastDays: _backfillDays);
    if (byDay.isEmpty) return 0;

    final entries = await _ref.read(weightControllerProvider.future);
    final existingDays = entries.map(_dayOf).toSet();

    var imported = 0;
    final controller = _ref.read(weightControllerProvider.notifier);
    for (final entry in byDay.entries) {
      if (existingDays.contains(entry.key)) continue;
      await controller.addEntry(date: entry.key, weight: entry.value.kg);
      imported++;
    }
    return imported;
  }

  DateTime _dayOf(WeightEntry e) => DateTime(e.date.year, e.date.month, e.date.day);
}

final weightHealthBackfillServiceProvider = Provider<WeightHealthBackfillService>((ref) {
  return WeightHealthBackfillService(ref);
});
