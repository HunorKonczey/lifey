import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/widgets/charts/time_series_chart.dart';
import '../domain/body_measurement.dart';
import '../domain/measurement_series.dart';
import 'body_measurement_controller.dart';

/// Which site the measurements screen is showing.
class SelectedMeasurementSite extends Notifier<MeasurementSite> {
  @override
  MeasurementSite build() => MeasurementSite.waist;

  void select(MeasurementSite site) => state = site;
}

final selectedMeasurementSiteProvider =
    NotifierProvider<SelectedMeasurementSite, MeasurementSite>(SelectedMeasurementSite.new);

/// The chart series for the selected site, derived from the live entries.
final measurementChartDataProvider = Provider<AsyncValue<List<TimeSeriesPoint>>>((ref) {
  final site = ref.watch(selectedMeasurementSiteProvider);
  return ref.watch(bodyMeasurementControllerProvider).whenData((all) => measurementSeries(all, site));
});
