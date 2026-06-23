import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/health/health_service.dart';

/// Today's HealthKit step count (iOS only), refreshed about once a minute
/// while the app is foregrounded — never polls in the background.
///
/// Kept as a separate provider from `dashboardControllerProvider` (a plain
/// derived `Provider`) so this timer-driven refresh doesn't force the whole
/// dashboard to recompute. Steps are a read-through display only — never
/// persisted locally or synced to the backend, since they're device/Health-
/// owned and change constantly; only "now" matters.
class TodayStepsController extends AsyncNotifier<int?> with WidgetsBindingObserver {
  static const _refreshInterval = Duration(seconds: 60);

  HealthService get _service => ref.read(healthServiceProvider);
  Timer? _timer;

  @override
  Future<int?> build() async {
    WidgetsBinding.instance.addObserver(this);
    ref.onDispose(() {
      WidgetsBinding.instance.removeObserver(this);
      _timer?.cancel();
    });
    _startTimer();
    return _service.todaySteps();
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(_refreshInterval, (_) => _refresh());
  }

  Future<void> _refresh() async {
    state = AsyncData(await _service.todaySteps());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(_refresh());
      _startTimer();
    } else if (state == AppLifecycleState.paused) {
      _timer?.cancel();
    }
  }
}

final todayStepsControllerProvider =
    AsyncNotifierProvider<TodayStepsController, int?>(TodayStepsController.new);
