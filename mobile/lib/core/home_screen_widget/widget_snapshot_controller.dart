import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/dashboard/application/dashboard_controller.dart';
import '../../features/dashboard/application/today_steps_controller.dart';
import '../../features/settings/application/settings_controller.dart';
import 'widget_snapshot_writer.dart';

/// Keeps the home screen widget's snapshot (App Group UserDefaults on iOS,
/// SharedPreferences on Android) in sync with the dashboard.
///
/// Listens to [dashboardControllerProvider] (calories),
/// [todayStepsControllerProvider] and [settingsControllerProvider] (goals +
/// language) and writes a debounced snapshot on change, plus once
/// immediately on [AppLifecycleState.paused] so the very last state before
/// backgrounding is always captured (a debounced write in flight could
/// otherwise be cut off by the OS suspending the app).
///
/// Watched once at app root ([LifeyApp]), same as
/// [ConnectivitySyncController] — this provider's return value is unused,
/// it exists to keep the listener alive for the app's lifetime.
class WidgetSnapshotController with WidgetsBindingObserver {
  WidgetSnapshotController(this._ref, this._writer) {
    if (!_writer.isAvailable) return;
    WidgetsBinding.instance.addObserver(this);
    _ref.listen(dashboardControllerProvider, (previous, next) => _scheduleWrite());
    _ref.listen(todayStepsControllerProvider, (previous, next) => _scheduleWrite());
    _ref.listen(settingsControllerProvider, (previous, next) => _scheduleWrite());
    _scheduleWrite();
  }

  static const _debounce = Duration(seconds: 2);

  final Ref _ref;
  final WidgetSnapshotWriter _writer;
  Timer? _debounceTimer;

  void _scheduleWrite() {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(_debounce, () => unawaited(_writeNow()));
  }

  Future<void> _writeNow() async {
    final settings = _ref.read(settingsControllerProvider).value;
    if (settings == null) return;
    final stats = _ref.read(dashboardControllerProvider).stats;
    final steps = _ref.read(todayStepsControllerProvider).value;
    await _writer.write(stats: stats, steps: steps, settings: settings);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.paused) return;
    _debounceTimer?.cancel();
    unawaited(_writeNow());
  }

  void dispose() {
    if (!_writer.isAvailable) return;
    WidgetsBinding.instance.removeObserver(this);
    _debounceTimer?.cancel();
  }
}

final widgetSnapshotControllerProvider = Provider<WidgetSnapshotController>((ref) {
  final controller = WidgetSnapshotController(ref, WidgetSnapshotWriter());
  ref.onDispose(controller.dispose);
  return controller;
});
