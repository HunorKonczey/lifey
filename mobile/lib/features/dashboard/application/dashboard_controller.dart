import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/dashboard_repository.dart';
import '../domain/dashboard_data.dart';

/// Loads the dashboard data. [refresh] reloads silently (keeps the current data
/// visible while fetching) so re-entering the tab doesn't flash a spinner.
class DashboardController extends AsyncNotifier<DashboardData> {
  @override
  Future<DashboardData> build() => ref.read(dashboardRepositoryProvider).load();

  Future<void> refresh() async {
    state = await AsyncValue.guard(() => ref.read(dashboardRepositoryProvider).load());
  }
}

final dashboardControllerProvider =
    AsyncNotifierProvider<DashboardController, DashboardData>(DashboardController.new);
