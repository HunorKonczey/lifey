import '../../../shared/widgets/charts/time_series_chart.dart';

/// A single day's aggregated value for a [StatMetric] — the unit the
/// statistics screen's chart is built from.
class DailyStatPoint {
  const DailyStatPoint({required this.date, required this.value});

  final DateTime date;
  final double value;

  TimeSeriesPoint toTimeSeriesPoint() => TimeSeriesPoint(date: date, value: value);
}
