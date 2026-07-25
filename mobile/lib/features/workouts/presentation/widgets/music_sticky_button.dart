import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/music/music_controller.dart';
import '../../../../core/music/music_provider_id.dart';
import '../../../../core/music/music_service.dart';
import '../../../../core/theme/app_tokens.dart';
import '../../../../l10n/app_localizations.dart';
import 'music_player_sheet.dart';
import 'music_provider_picker_sheet.dart';
import 'provider_glyph.dart';

/// Same warn color as `_RestBanner`/`showAppConfirmDialog`'s delete-accent —
/// see docs/music/46-workout-music-controls-plan.md §6.2.
const _kAttentionColor = Color(0xFFD66B5A);

/// Sticky zene-gomb (docs/music/46-workout-music-controls-plan.md §3.4):
/// 54x54, sits left of "Finish workout" in the running session's sticky
/// bottom row. Tapping opens the provider picker (no provider chosen yet) or
/// the mini player (a provider is already selected); a "Switch" tap inside
/// the player routes back here to reopen the picker.
class MusicStickyButton extends ConsumerStatefulWidget {
  const MusicStickyButton({super.key});

  @override
  ConsumerState<MusicStickyButton> createState() => _MusicStickyButtonState();
}

class _MusicStickyButtonState extends ConsumerState<MusicStickyButton>
    with TickerProviderStateMixin {
  static const _minBarHeight = 6.0;
  static const _maxBarHeight = 16.0;
  static const _barDurations = [
    Duration(milliseconds: 900),
    Duration(milliseconds: 800),
    Duration(milliseconds: 1000),
  ];

  late final List<AnimationController> _barControllers = [
    for (final duration in _barDurations) AnimationController(vsync: this, duration: duration),
  ];
  bool _animating = false;

  @override
  void dispose() {
    for (final controller in _barControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  /// Starts/stops the three equalizer bars as playback starts/stops.
  /// Reduce-motion settings get static mid-height bars instead of a loop —
  /// docs/music/46-workout-music-controls-plan.md §6.1.
  void _syncAnimation(bool playing) {
    if (playing == _animating) return;
    _animating = playing;
    final reduceMotion = MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    for (final controller in _barControllers) {
      if (playing && !reduceMotion) {
        controller.repeat(reverse: true);
      } else {
        controller.stop();
        controller.value = playing ? 0.5 : 0.0;
      }
    }
  }

  Future<void> _handleTap() async {
    final status = ref.read(musicControllerProvider).status;
    if (status == MusicConnectionStatus.notConfigured) {
      await _openPicker();
      return;
    }
    final action = await showModalBottomSheet<MusicPlayerSheetAction>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => const MusicPlayerSheet(),
    );
    if (action == MusicPlayerSheetAction.switchProvider && mounted) {
      await _openPicker();
    }
  }

  Future<void> _openPicker() {
    return showModalBottomSheet<MusicProviderId>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => const MusicProviderPickerSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    final musicState = ref.watch(musicControllerProvider);
    final playing = musicState.playback?.isPlaying ?? false;
    _syncAnimation(playing);

    final attention = musicState.status == MusicConnectionStatus.permissionNeeded ||
        musicState.status == MusicConnectionStatus.error;

    return GestureDetector(
      onTap: _handleTap,
      child: Tooltip(
        message: l10n.musicButtonTooltip,
        child: Container(
          width: 54,
          height: 54,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.card),
            boxShadow: [
              BoxShadow(color: Colors.black.withValues(alpha: 0.30), blurRadius: 18, offset: const Offset(0, 8)),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.card),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
              child: Container(
                color: scheme.surfaceContainer.withValues(alpha: 0.90),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        ProviderGlyph(provider: musicState.provider, diameter: 22),
                        if (playing) ...[
                          const SizedBox(width: 5),
                          _Equalizer(
                            controllers: _barControllers,
                            color: scheme.primary,
                            minHeight: _minBarHeight,
                            maxHeight: _maxBarHeight,
                          ),
                        ],
                      ],
                    ),
                    if (attention)
                      Positioned(
                        top: 6,
                        right: 6,
                        child: Container(
                          width: 10,
                          height: 10,
                          decoration: BoxDecoration(
                            color: _kAttentionColor,
                            shape: BoxShape.circle,
                            border: Border.all(color: scheme.surfaceContainer, width: 2),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Equalizer extends StatelessWidget {
  const _Equalizer({
    required this.controllers,
    required this.color,
    required this.minHeight,
    required this.maxHeight,
  });

  final List<AnimationController> controllers;
  final Color color;
  final double minHeight;
  final double maxHeight;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: maxHeight,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < controllers.length; i++) ...[
            if (i > 0) const SizedBox(width: 2),
            AnimatedBuilder(
              animation: controllers[i],
              builder: (context, _) => Container(
                width: 3,
                height: minHeight + (maxHeight - minHeight) * controllers[i].value,
                decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2)),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
