import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/dashboard/application/dashboard_controller.dart';
import '../../features/dashboard/application/today_steps_controller.dart';
import '../../features/settings/application/settings_controller.dart';
import '../../features/settings/domain/user_settings.dart';
import '../../features/workouts/application/activity_ranking.dart';
import '../../features/workouts/application/quick_start_options_provider.dart';
import '../../l10n/app_localizations.dart';
import '../app_shortcuts/app_shortcuts_service.dart';
import 'widget_snapshot_writer.dart';

/// Keeps the home screen widget's snapshot (App Group UserDefaults on iOS,
/// SharedPreferences on Android) — and, since C2.11a, the OS's dynamic
/// app-shortcuts — in sync with the app.
///
/// Listens to [dashboardControllerProvider] (calories),
/// [todayStepsControllerProvider] and [settingsControllerProvider] (goals +
/// language) and writes a debounced snapshot on change, plus once
/// immediately on [AppLifecycleState.paused] so the very last state before
/// backgrounding is always captured (a debounced write in flight could
/// otherwise be cut off by the OS suspending the app).
///
/// The quick-start ranking ([quickStartEntriesProvider]) deliberately isn't
/// in that watch list: docs/cardio/53-cardio-mobile-plan.md §3.2/3.3 both
/// call for refreshing it "app háttérbe kerülésekor, nem minden
/// képernyőnyitáskor" (on backgrounding, not on every rebuild) — a session
/// finishing rebuilds [dashboardControllerProvider] too, which would
/// otherwise recompute it on every set logged, not just once per
/// background/foreground cycle. [_refreshQuickStart] instead only runs from
/// the constructor (so a fresh install/cold start isn't stuck without one
/// until the user first backgrounds the app) and from [AppLifecycleState.
/// paused], and its result is cached in [_quickStart] for every debounced
/// [_writeNow] in between to reuse unchanged.
///
/// Watched once at app root ([LifeyApp]), same as
/// [ConnectivitySyncController] — this provider's return value is unused,
/// it exists to keep the listener alive for the app's lifetime.
class WidgetSnapshotController with WidgetsBindingObserver {
  WidgetSnapshotController(this._ref, this._writer, this._shortcuts) {
    if (!_writer.isAvailable && !_shortcuts.isAvailable) return;
    WidgetsBinding.instance.addObserver(this);
    _ref.listen(dashboardControllerProvider, (previous, next) => _scheduleWrite());
    _ref.listen(todayStepsControllerProvider, (previous, next) => _scheduleWrite());
    _ref.listen(settingsControllerProvider, (previous, next) => _scheduleWrite());
    _refreshQuickStart();
    _scheduleWrite();
  }

  static const _debounce = Duration(seconds: 2);

  final Ref _ref;
  final WidgetSnapshotWriter _writer;
  final AppShortcutsService _shortcuts;
  Timer? _debounceTimer;
  List<ResolvedQuickStartEntry> _quickStart = const [];

  void _scheduleWrite() {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(_debounce, () => unawaited(_writeNow()));
  }

  Future<void> _writeNow() async {
    final settings = _ref.read(settingsControllerProvider).value;
    if (settings == null) return;
    final stats = _ref.read(dashboardControllerProvider).stats;
    final steps = _ref.read(todayStepsControllerProvider).value;
    await _writer.write(
      stats: stats,
      steps: steps,
      settings: settings,
      quickStartEntries: _quickStart,
    );
  }

  /// Recomputes [_quickStart] from the same ranking the quick-start sheet
  /// uses, and pushes the top 3 of it to the OS as dynamic app-shortcuts
  /// (docs/cardio/53-cardio-mobile-plan.md §3.2: "a három legmagasabb rangú
  /// edzés"). Reads rather than watches [quickStartEntriesProvider] — this
  /// is deliberately *not* a listener, called only from the constructor and
  /// [didChangeAppLifecycleState] (see class doc for why).
  void _refreshQuickStart() {
    final settings = _ref.read(settingsControllerProvider).value;
    if (settings == null) return;
    _quickStart = _ref.read(quickStartEntriesProvider);
    final l10n = lookupAppLocalizations(_localeFor(settings.language));
    unawaited(_shortcuts.update([
      for (final resolved in _quickStart.take(3))
        AppShortcut(
          id: _shortcutId(resolved.entry),
          shortLabel: quickStartEntryTitle(l10n, resolved),
          deepLinkUri: quickStartDeepLinkUri(resolved.entry).toString(),
        ),
    ]));
  }

  String _shortcutId(QuickStartEntry entry) => entry.isCardio
      ? 'cardio:${entry.activityType}'
      : 'strength:${entry.templateClientId ?? "freeform"}';

  // Matches WidgetSnapshotWriter._localeFor exactly (also duplicated in
  // step_goal_notifier.dart) — small enough, and l10n resolution without a
  // BuildContext is a recurring enough need in this app's headless
  // (non-widget-tree) services, that a shared helper isn't worth the extra
  // indirection for three call sites.
  Locale _localeFor(LanguagePreference preference) {
    return preference == LanguagePreference.hungarian ? const Locale('hu') : const Locale('en');
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.paused) return;
    _refreshQuickStart();
    _debounceTimer?.cancel();
    unawaited(_writeNow());
  }

  void dispose() {
    if (!_writer.isAvailable && !_shortcuts.isAvailable) return;
    WidgetsBinding.instance.removeObserver(this);
    _debounceTimer?.cancel();
  }
}

final widgetSnapshotControllerProvider = Provider<WidgetSnapshotController>((ref) {
  final controller = WidgetSnapshotController(
    ref,
    WidgetSnapshotWriter(),
    AppShortcutsService(),
  );
  ref.onDispose(controller.dispose);
  return controller;
});
