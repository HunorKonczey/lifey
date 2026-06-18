/// Aggregated dashboard summary model.
class DashboardSummary {
  const DashboardSummary({
    required this.todayCalories,
    required this.todayProtein,
    this.latestWeight,
  });

  final double todayCalories;
  final double todayProtein;
  final double? latestWeight;
}
