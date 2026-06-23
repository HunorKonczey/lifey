import 'package:flutter_riverpod/flutter_riverpod.dart';

/// How much history the weight chart shows. [all] has no cutoff.
enum WeightRange {
  week,
  month,
  quarter,
  all;

  /// The oldest local-midnight date still included, or null for [all].
  DateTime? cutoff() {
    if (this == WeightRange.all) return null;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final daysBack = switch (this) {
      WeightRange.week => 6,
      WeightRange.month => 29,
      WeightRange.quarter => 89,
      WeightRange.all => 0,
    };
    return today.subtract(Duration(days: daysBack));
  }
}

/// The user's currently selected [WeightRange] for the weight chart.
/// In-memory only — resets to [WeightRange.month] on app restart.
class WeightRangeController extends Notifier<WeightRange> {
  @override
  WeightRange build() => WeightRange.month;

  void select(WeightRange range) => state = range;
}

final weightRangeControllerProvider =
    NotifierProvider<WeightRangeController, WeightRange>(WeightRangeController.new);
