import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/widgets/charts/stats_range.dart';

/// How much history the weight chart shows. [all] has no cutoff.
///
/// The cutoff day-counts themselves live in [StatsRange] (shared/), so other
/// daily-metric charts don't have to redefine them — this enum just keeps
/// the weight-specific type used by the weight screen's SegmentedButton.
enum WeightRange {
  week,
  month,
  quarter,
  all;

  StatsRange get _statsRange => switch (this) {
        WeightRange.week => StatsRange.week,
        WeightRange.month => StatsRange.month,
        WeightRange.quarter => StatsRange.quarter,
        WeightRange.all => StatsRange.all,
      };

  /// The oldest local-midnight date still included, or null for [all].
  DateTime? cutoff() => _statsRange.cutoff();
}

/// The user's currently selected [WeightRange] for the weight chart.
/// In-memory only — resets to [WeightRange.month] on app restart.
class WeightRangeController extends Notifier<WeightRange> {
  @override
  WeightRange build() => WeightRange.week;

  void select(WeightRange range) => state = range;
}

final weightRangeControllerProvider =
    NotifierProvider<WeightRangeController, WeightRange>(WeightRangeController.new);
