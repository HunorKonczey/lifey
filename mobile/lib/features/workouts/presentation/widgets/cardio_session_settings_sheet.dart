import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../l10n/app_localizations.dart';
import '../../../settings/application/settings_controller.dart';
import '../../../settings/domain/user_settings.dart';
import '../../application/auto_pause_preferences.dart';
import '../../application/km_cue_preferences.dart';

/// The DISTANCE family's in-session settings (docs/cardio/61 §2 M35) —
/// reachable from `CardioSessionScreen`'s header, not the main Settings
/// screen: these are plain local flags, not part of `UserSettings`'
/// save-the-whole-object sync flow.
///
/// Holds two things in M35's own order: GPS auto-pause (C4a.5a, the sheet's
/// original and only occupant) and the per-kilometre cue (C6.6). Named after
/// the session rather than after auto-pause since C6.6 — a sheet with two
/// sections shouldn't be named after one of them.
class CardioSessionSettingsSheet extends ConsumerStatefulWidget {
  const CardioSessionSettingsSheet({super.key});

  @override
  ConsumerState<CardioSessionSettingsSheet> createState() => _CardioSessionSettingsSheetState();
}

class _CardioSessionSettingsSheetState extends ConsumerState<CardioSessionSettingsSheet> {
  /// `null` while the initial read is in flight — brief enough (a couple of
  /// `shared_preferences` reads) that a spinner beats a flash of the wrong
  /// default.
  bool? _autoPauseEnabled;
  KmCueSettings? _kmCue;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    final autoPause = await ref.read(autoPausePreferencesProvider).isEnabled();
    final kmCue = await ref.read(kmCuePreferencesProvider).load();
    if (mounted) {
      setState(() {
        _autoPauseEnabled = autoPause;
        _kmCue = kmCue;
      });
    }
  }

  // Optimistic throughout — these are plain local flags, not synced calls.
  Future<void> _toggleAutoPause(bool value) async {
    setState(() => _autoPauseEnabled = value);
    await ref.read(autoPausePreferencesProvider).setEnabled(value);
  }

  Future<void> _toggleVibration(bool value) async {
    setState(() => _kmCue = _kmCue?.copyWith(vibration: value));
    await ref.read(kmCuePreferencesProvider).setVibrationEnabled(value);
  }

  Future<void> _toggleSound(bool value) async {
    setState(() => _kmCue = _kmCue?.copyWith(sound: value));
    await ref.read(kmCuePreferencesProvider).setSoundEnabled(value);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final autoPauseEnabled = _autoPauseEnabled;
    final kmCue = _kmCue;
    final unitSystem = (ref.watch(settingsControllerProvider).value ?? const UserSettings.defaults())
        .unitSystem;

    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.cardioSessionSettingsTitle,
              style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            Text(
              l10n.autoPauseSettingsDescription,
              style: theme.textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant, height: 1.4),
            ),
            const SizedBox(height: 8),
            if (autoPauseEnabled == null || kmCue == null)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 20),
                child: Center(child: CircularProgressIndicator()),
              )
            else ...[
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(l10n.autoPauseSettingsSwitchLabel),
                value: autoPauseEnabled,
                onChanged: _toggleAutoPause,
              ),
              const SizedBox(height: 8),
              _SectionLabel(label: l10n.kmCueSectionLabel),
              const SizedBox(height: 4),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                secondary: Icon(Icons.vibration, color: scheme.onSurfaceVariant),
                title: Text(l10n.kmCueVibrationLabel),
                subtitle: Text(l10n.kmCueVibrationDescription),
                value: kmCue.vibration,
                onChanged: _toggleVibration,
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                secondary: Icon(Icons.volume_up, color: scheme.onSurfaceVariant),
                title: Text(l10n.kmCueSoundLabel),
                subtitle: Text(l10n.kmCueSoundDescription),
                value: kmCue.sound,
                onChanged: _toggleSound,
              ),
              const SizedBox(height: 4),
              _ComingSoonRow(
                icon: Icons.record_voice_over,
                label: l10n.kmCueSpokenLabel,
                example: l10n.kmCueSpokenExample,
                badge: l10n.kmCueComingSoonBadge,
              ),
              const SizedBox(height: 14),
              _UnitExplanation(
                text: unitSystem == UnitSystem.imperial
                    ? l10n.kmCueUnitExplanationImperial
                    : l10n.kmCueUnitExplanationMetric,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Text(
      label,
      style: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        letterSpacing: 1.2,
        color: scheme.onSurfaceVariant,
      ),
    );
  }
}

/// M35's spoken-feedback row: a feature that isn't built (docs/cardio/60
/// Q-C6.1 — decided in design: no TTS now), kept visible so its place is
/// obvious.
///
/// **Dashed border, not just grey text** — that's the whole point of the
/// treatment. A greyed-out switch reads as a broken toggle the user should
/// be able to fix; a dashed outline reads as a space reserved for something
/// that isn't here yet. It carries no switch at all, for the same reason.
class _ComingSoonRow extends StatelessWidget {
  const _ComingSoonRow({
    required this.icon,
    required this.label,
    required this.example,
    required this.badge,
  });

  final IconData icon;
  final String label;
  final String example;
  final String badge;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return CustomPaint(
      painter: _DashedBorderPainter(color: scheme.outlineVariant, radius: 14),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            Icon(icon, color: scheme.outline, size: 22),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          label,
                          style: theme.textTheme.bodyLarge?.copyWith(color: scheme.outline),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: scheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          badge,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    example,
                    style: theme.textTheme.bodySmall?.copyWith(color: scheme.outline),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The sheet's closing line — it **explains** the unit, it doesn't set it
/// (M35). Rendered as plain text with an info icon rather than as a row that
/// could be mistaken for a control.
class _UnitExplanation extends StatelessWidget {
  const _UnitExplanation({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(Icons.info_outline, size: 15, color: scheme.outline),
        const SizedBox(width: 9),
        Expanded(
          child: Text(
            text,
            style: theme.textTheme.bodySmall?.copyWith(color: scheme.outline, height: 1.4),
          ),
        ),
      ],
    );
  }
}

class _DashedBorderPainter extends CustomPainter {
  const _DashedBorderPainter({required this.color, required this.radius});

  final Color color;
  final double radius;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    final rrect = RRect.fromRectAndRadius(
      Rect.fromLTWH(0.5, 0.5, size.width - 1, size.height - 1),
      Radius.circular(radius),
    );
    const dash = 4.0;
    const gap = 4.0;
    for (final metric in (Path()..addRRect(rrect)).computeMetrics()) {
      var distance = 0.0;
      while (distance < metric.length) {
        canvas.drawPath(
          metric.extractPath(distance, (distance + dash).clamp(0.0, metric.length)),
          paint,
        );
        distance += dash + gap;
      }
    }
  }

  @override
  bool shouldRepaint(_DashedBorderPainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.radius != radius;
}

/// Shows [CardioSessionSettingsSheet]. Fire-and-forget from the caller's
/// side — there's no choice to act on afterward, the sheet writes straight
/// through the preference stores itself.
Future<void> showCardioSessionSettingsSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => const CardioSessionSettingsSheet(),
  );
}
