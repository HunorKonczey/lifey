import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/stat_metric.dart';

/// The user's currently selected [StatMetric] for the statistics chart.
/// In-memory only — resets to [StatMetric.calories] on app restart.
class StatMetricController extends Notifier<StatMetric> {
  @override
  StatMetric build() => StatMetric.calories;

  void select(StatMetric metric) => state = metric;
}

final statMetricControllerProvider =
    NotifierProvider<StatMetricController, StatMetric>(StatMetricController.new);
