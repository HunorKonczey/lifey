import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/workouts/application/watch_template_sync.dart';
import 'watch_workout_service.dart';

/// Pushes the watch's standalone-picker template cache whenever it changes
/// (docs/watch/49-watch-f6b-template-sync-plan.md T2.2).
///
/// Holds only the debounce timer and the dedup key; *what* to push is
/// [watchTemplateSyncPayloadProvider]'s job, and *when* is
/// [watchTemplateSyncControllerProvider]'s. Kept out of that provider so it
/// survives every re-derivation — a controller rebuilt on each payload
/// change would reset its own debounce and dedup state, defeating both.
class WatchTemplateSyncController {
  WatchTemplateSyncController(this._service);

  /// Matches [WidgetSnapshotController]'s own debounce. Every source behind
  /// the payload is a Drift stream that re-emits on any write to its tables,
  /// so a single sync pull can easily fire several times for one logical
  /// change.
  static const _debounce = Duration(seconds: 2);

  final WatchWorkoutService _service;
  Timer? _debounceTimer;

  /// The last payload actually sent, encoded — the dedup key. Unlike
  /// [WidgetSnapshotController], which rewrites its local snapshot
  /// unconditionally because writing to prefs is free, a push here costs a
  /// WCSession/Data Layer round trip, so an unchanged payload is dropped.
  /// Null until the first push, which therefore always goes out.
  String? _lastPushed;

  /// [payload] being null means "the sources haven't loaded yet", not "the
  /// watch should hold nothing" (see [watchTemplateSyncPayloadProvider]) —
  /// pushing then would wipe a good cache at every cold start.
  void schedulePush(List<WatchTemplatePayload>? payload) {
    if (!_service.isAvailable || payload == null) return;
    _debounceTimer?.cancel();
    _debounceTimer = Timer(_debounce, () => unawaited(_pushNow(payload)));
  }

  Future<void> _pushNow(List<WatchTemplatePayload> payload) async {
    final encoded = jsonEncode([for (final template in payload) template.toJson()]);
    if (encoded == _lastPushed) return;
    // Recorded before awaiting, so a second change arriving mid-flight is
    // compared against what we're sending, not the previous payload.
    _lastPushed = encoded;
    await _service.syncTemplates(payload);
  }

  void dispose() {
    _debounceTimer?.cancel();
  }
}

/// The stable half — rebuilt only if the service itself changes, which it
/// never does at runtime.
final _watchTemplateSyncControllerProvider = Provider<WatchTemplateSyncController>((ref) {
  final controller = WatchTemplateSyncController(ref.watch(watchWorkoutServiceProvider));
  ref.onDispose(controller.dispose);
  return controller;
});

/// Keeps the watch's template cache in sync with the phone. Watched once at
/// app root ([LifeyApp]); the return value is unused, the `ref.watch` is the
/// point. That first evaluation is also the app-start push §4.3 asks for, so
/// no separate startup hook is needed.
///
/// **The `ref.watch` here is load-bearing, not a style choice.** Riverpod 3
/// leaves a plain [Provider] dirty-but-unrecomputed while its only subscriber
/// is a `ref.listen` — the callback then simply never fires, and not even
/// `fireImmediately: true` changes that (verified against this exact
/// setup). Reaching for `ref.listen` inside the controller, the way
/// [WidgetSnapshotController] does, therefore silently breaks here:
/// that class gets away with it because it listens to `StreamNotifier`s,
/// which stay hot on their own, whereas [watchTemplateSyncPayloadProvider]
/// is derived. An actively-watched provider is what forces the
/// re-derivation, so this indirection is the mechanism, not ceremony —
/// deleting it would leave templates syncing at app start and never again.
final watchTemplateSyncControllerProvider = Provider<void>((ref) {
  ref
      .read(_watchTemplateSyncControllerProvider)
      .schedulePush(ref.watch(watchTemplateSyncPayloadProvider));
});
