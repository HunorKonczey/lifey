import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../l10n/app_localizations.dart';
import '../../application/auto_pause_preferences.dart';

/// The "Kikapcsolható" (togglable) half of GPS auto-pause
/// (docs/cardio/53-cardio-mobile-plan.md §4.3, C4a.5a) — a small settings
/// sheet reachable from the DISTANCE-family header (see
/// `CardioSessionScreen`'s AppBar), not the main Settings screen: unlike
/// `UserSettings`, `AutoPausePreferences` is a plain local flag, not synced
/// to the backend, so it doesn't fit that screen's save-the-whole-object flow.
class AutoPauseSettingsSheet extends ConsumerStatefulWidget {
  const AutoPauseSettingsSheet({super.key});

  @override
  ConsumerState<AutoPauseSettingsSheet> createState() => _AutoPauseSettingsSheetState();
}

class _AutoPauseSettingsSheetState extends ConsumerState<AutoPauseSettingsSheet> {
  /// `null` while the initial read is in flight — brief enough (a single
  /// `shared_preferences` read) that a spinner beats a flash of the wrong
  /// default.
  bool? _enabled;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    final enabled = await ref.read(autoPausePreferencesProvider).isEnabled();
    if (mounted) setState(() => _enabled = enabled);
  }

  Future<void> _toggle(bool value) async {
    setState(() => _enabled = value); // optimistic — this is a plain local flag, not a synced call
    await ref.read(autoPausePreferencesProvider).setEnabled(value);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final enabled = _enabled;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.autoPauseSettingsTitle,
            style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          Text(
            l10n.autoPauseSettingsDescription,
            style: theme.textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant, height: 1.4),
          ),
          const SizedBox(height: 8),
          if (enabled == null)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 20),
              child: Center(child: CircularProgressIndicator()),
            )
          else
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(l10n.autoPauseSettingsSwitchLabel),
              value: enabled,
              onChanged: _toggle,
            ),
        ],
      ),
    );
  }
}

/// Shows [AutoPauseSettingsSheet]. Fire-and-forget from the caller's side —
/// unlike `showGpsExplainerSheet`, there's no choice to act on afterward,
/// the sheet writes straight through [AutoPausePreferences] itself.
Future<void> showAutoPauseSettingsSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => const AutoPauseSettingsSheet(),
  );
}
