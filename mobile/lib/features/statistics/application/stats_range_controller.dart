import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/widgets/charts/stats_range.dart';

/// The user's currently selected [StatsRange] for the statistics chart.
/// In-memory only — resets to [StatsRange.month] on app restart.
class StatsRangeController extends Notifier<StatsRange> {
  @override
  StatsRange build() => StatsRange.month;

  void select(StatsRange range) => state = range;
}

final statsRangeControllerProvider =
    NotifierProvider<StatsRangeController, StatsRange>(StatsRangeController.new);
