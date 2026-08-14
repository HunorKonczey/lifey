import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/stat_kind_filter.dart';

/// The user's currently selected [StatKindFilter] for the statistics
/// screen's "edzés jellegű" metrics (docs/cardio/56-cardio-statistics-plan.md
/// D-C3.4). In-memory only — resets to [StatKindFilter.all] on app restart,
/// same as [StatMetricController]/`StatsRangeController`.
class StatKindFilterController extends Notifier<StatKindFilter> {
  @override
  StatKindFilter build() => StatKindFilter.all;

  void select(StatKindFilter filter) => state = filter;
}

final statKindFilterControllerProvider =
    NotifierProvider<StatKindFilterController, StatKindFilter>(StatKindFilterController.new);
