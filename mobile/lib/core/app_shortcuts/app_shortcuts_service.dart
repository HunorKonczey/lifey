import 'dart:io' show Platform;

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// One dynamic app-shortcut (Android `ShortcutManager`, C2.11a;
/// `UIApplicationShortcutItem`, C2.11b) — a top-ranked `QuickStartEntry`
/// (docs/cardio/53-cardio-mobile-plan.md §3.2, D-C.8) turned into what the
/// native side needs to render one launcher-icon-long-press entry: a stable
/// [id] (so the OS can diff an update against what it already has), the
/// already-localized [shortLabel] ([quickStartEntryTitle]'s own output —
/// same text the quick-start sheet tile would show for this rank), and the
/// [deepLinkUri] tapping it opens (`quickStartDeepLinkUri(entry).toString()`).
///
/// No per-type icon here on purpose: every shortcut renders with the app's
/// own launcher icon (native side, C2.11a's Kotlin) — matching the doc's "no
/// new plugin, few lines of native code" scope without also having to ship
/// and maintain a native vector-drawable per `kActivityTypes` entry just for
/// this secondary entry point.
class AppShortcut {
  const AppShortcut({
    required this.id,
    required this.shortLabel,
    required this.deepLinkUri,
  });

  final String id;
  final String shortLabel;
  final String deepLinkUri;

  Map<String, dynamic> toJson() => {
        'id': id,
        'shortLabel': shortLabel,
        'deepLinkUri': deepLinkUri,
      };
}

/// Bridges the top-ranked quick-start entries to the platform's dynamic
/// app-shortcuts (long-press on the launcher icon) — Android's
/// `ShortcutManager.setDynamicShortcuts` (C2.11a) and iOS's
/// `UIApplicationShortcutItem`s (C2.11b, `ShortcutsChannel.swift`), over one
/// shared `lifey/shortcuts` MethodChannel per docs/cardio/53-cardio-mobile-plan.md
/// D-C2.2 ("no new plugin — a few lines of native code in an existing
/// MethodChannel pattern, the same shape as `workout_session_notifier`").
///
/// No-ops off Android/iOS — same "unavailable is a normal outcome, not an
/// error" posture as [WorkoutSessionNotifierService] and
/// [WidgetSnapshotWriter], and for the same reason: shortcuts are a
/// convenience, never something the rest of the app depends on existing.
class AppShortcutsService {
  AppShortcutsService({MethodChannel? channel, bool? isAvailable})
      : _channel = channel ?? const MethodChannel('lifey/shortcuts'),
        isAvailable = isAvailable ?? (Platform.isAndroid || Platform.isIOS);

  final MethodChannel _channel;

  /// Defaults to [Platform.isAndroid] || [Platform.isIOS]; overridable in
  /// the constructor so tests can exercise [update] on a non-mobile test
  /// host.
  final bool isAvailable;

  /// Replaces the current set of dynamic shortcuts. Never throws: a missing
  /// native handler (older build, unsupported OS version) is swallowed —
  /// same as [WorkoutSessionNotifierService]'s Android branch.
  Future<void> update(List<AppShortcut> shortcuts) async {
    if (!isAvailable) return;
    try {
      await _channel.invokeMethod('update', {
        'shortcuts': [for (final s in shortcuts) s.toJson()],
      });
    } on MissingPluginException {
      // No native handler for this OS/build yet — nothing to retry into.
    }
  }
}

final appShortcutsServiceProvider = Provider<AppShortcutsService>((ref) {
  return AppShortcutsService();
});
