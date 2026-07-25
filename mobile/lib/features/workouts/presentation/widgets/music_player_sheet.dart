import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/music/music_controller.dart';
import '../../../../core/music/music_provider_id.dart';
import '../../../../core/music/music_service.dart';
import '../../../../core/theme/app_tokens.dart';
import '../../../../l10n/app_localizations.dart';
import 'music_provider_picker_sheet.dart';
import 'provider_glyph.dart';

/// Same warn color as `_RestBanner`/`showAppConfirmDialog`'s delete-accent —
/// see docs/music/46-workout-music-controls-plan.md §6.2 (reusing the
/// existing color rather than introducing a one-off design-system token for
/// a single icon/dot).
const _kAttentionColor = Color(0xFFD66B5A);

/// Result popped from [MusicPlayerSheet] when the user taps "Switch" — the
/// sheet itself never re-shows [MusicProviderPickerSheet] (its own
/// BuildContext would be gone the moment it pops), so the caller
/// (`MusicStickyButton`) reacts to this and opens the picker from its own,
/// still-mounted context.
enum MusicPlayerSheetAction { switchProvider }

/// The mini lejátszó (docs/music/46-workout-music-controls-plan.md §3.5) —
/// renders a different body per [MusicConnectionStatus]. [connectPrompt] and
/// [permissionNeeded] render as standalone full-sheet prompts with no header
/// (nothing to show a provider chip/switch action for yet); every other
/// status shares [_ChromeSheet]'s provider-chip header.
class MusicPlayerSheet extends ConsumerWidget {
  const MusicPlayerSheet({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final musicState = ref.watch(musicControllerProvider);
    final provider = musicState.provider;
    switch (musicState.status) {
      case MusicConnectionStatus.permissionNeeded:
        return _PermissionSheet(provider: provider);
      case MusicConnectionStatus.connectPrompt:
        return _ConnectPromptSheet(provider: provider);
      case MusicConnectionStatus.connecting:
        return _ChromeSheet(provider: provider, body: const _LoadingBody());
      case MusicConnectionStatus.noActiveSession:
        return _ChromeSheet(provider: provider, body: _EmptyBody(provider: provider));
      case MusicConnectionStatus.appNotInstalled:
      case MusicConnectionStatus.error:
        return _ChromeSheet(provider: provider, body: _ErrorBody(provider: provider));
      case MusicConnectionStatus.connected:
        return _ChromeSheet(provider: provider, body: _PlayingBody(playback: musicState.playback));
      case MusicConnectionStatus.notConfigured:
        // Defensive fallback only — MusicStickyButton routes notConfigured
        // straight to the picker sheet, never to this one.
        return const _ChromeSheet(provider: null, body: _EmptyBody(provider: null));
    }
  }
}

// ---------------------------------------------------------------------------
// Chrome: provider chip header + "Switch" action, shared by most states
// ---------------------------------------------------------------------------

class _ChromeSheet extends StatelessWidget {
  const _ChromeSheet({required this.provider, required this.body});

  final MusicProviderId? provider;
  final Widget body;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 22),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.fromLTRB(8, 7, 14, 7),
                  decoration: BoxDecoration(
                    color: scheme.primary.withValues(alpha: 0.14),
                    borderRadius: AppRadius.pill,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ProviderGlyph(
                        provider: provider,
                        diameter: 24,
                        background: scheme.surfaceContainerHigh,
                        foreground: scheme.onSurface,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        provider?.displayName ?? '',
                        style: TextStyle(
                          fontFamily: 'PlusJakartaSans',
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                          color: scheme.onSurface,
                        ),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                GestureDetector(
                  onTap: () => Navigator.of(context).pop(MusicPlayerSheetAction.switchProvider),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.swap_horiz_rounded, size: 18, color: scheme.primary),
                      const SizedBox(width: 5),
                      Text(
                        l10n.musicSwitchProvider,
                        style: TextStyle(
                          fontFamily: 'PlusJakartaSans',
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: scheme.primary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            body,
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Bodies
// ---------------------------------------------------------------------------

class _LoadingBody extends StatelessWidget {
  const _LoadingBody();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 20),
      child: Column(
        children: [
          const SizedBox(
            width: 28,
            height: 28,
            child: CircularProgressIndicator(strokeWidth: 2.5),
          ),
          const SizedBox(height: 14),
          Text(
            l10n.musicConnectingMessage,
            style: TextStyle(
              fontFamily: 'PlusJakartaSans',
              fontSize: 13.5,
              fontWeight: FontWeight.w600,
              color: scheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyBody extends ConsumerWidget {
  const _EmptyBody({required this.provider});

  final MusicProviderId? provider;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    final name = provider?.displayName ?? '';
    return Column(
      children: [
        Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(color: scheme.surfaceContainerLow, shape: BoxShape.circle),
          child: Icon(Icons.music_off_rounded, size: 30, color: scheme.onSurfaceVariant),
        ),
        const SizedBox(height: 12),
        Text(
          l10n.musicNoActiveSessionMessage(name),
          textAlign: TextAlign.center,
          style: TextStyle(
            fontFamily: 'PlusJakartaSans',
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: scheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 16),
        _FilledCta(
          icon: Icons.open_in_new_rounded,
          label: l10n.musicOpenAppButton(name),
          onTap: () => ref.read(musicControllerProvider.notifier).openProviderApp(),
        ),
      ],
    );
  }
}

class _ErrorBody extends ConsumerWidget {
  const _ErrorBody({required this.provider});

  final MusicProviderId? provider;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    return Column(
      children: [
        Container(
          width: 64,
          height: 64,
          decoration:
              BoxDecoration(color: _kAttentionColor.withValues(alpha: 0.14), shape: BoxShape.circle),
          child: const Icon(Icons.cloud_off_rounded, size: 30, color: _kAttentionColor),
        ),
        const SizedBox(height: 12),
        Text(
          l10n.musicErrorMessage(provider?.displayName ?? ''),
          textAlign: TextAlign.center,
          style: TextStyle(
            fontFamily: 'PlusJakartaSans',
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: scheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 16),
        _TonalCta(
          icon: Icons.refresh_rounded,
          label: l10n.musicRetryButton,
          onTap: () => ref.read(musicControllerProvider.notifier).refresh(),
        ),
      ],
    );
  }
}

class _PlayingBody extends ConsumerWidget {
  const _PlayingBody({required this.playback});

  final MusicPlaybackState? playback;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final notifier = ref.read(musicControllerProvider.notifier);
    final isPlaying = playback?.isPlaying ?? false;
    final artwork = playback?.artworkPng;

    return Column(
      children: [
        Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(AppRadius.md),
              child: artwork != null
                  ? Image.memory(artwork, width: 64, height: 64, fit: BoxFit.cover)
                  : Container(
                      width: 64,
                      height: 64,
                      color: scheme.surfaceContainerHigh,
                      child: Icon(Icons.music_note_rounded, size: 26, color: scheme.onSurfaceVariant),
                    ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    playback?.title ?? '',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: 'PlusJakartaSans',
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      color: scheme.onSurface,
                      letterSpacing: -0.3,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    playback?.artist ?? '',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: 'PlusJakartaSans',
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 22),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _TransportButton(icon: Icons.skip_previous_rounded, onTap: notifier.previous),
            const SizedBox(width: 26),
            _PlayPauseButton(isPlaying: isPlaying, onTap: isPlaying ? notifier.pause : notifier.play),
            const SizedBox(width: 26),
            _TransportButton(icon: Icons.skip_next_rounded, onTap: notifier.next),
          ],
        ),
      ],
    );
  }
}

class _TransportButton extends StatelessWidget {
  const _TransportButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: scheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
        child: Icon(icon, size: 26, color: scheme.onSurface),
      ),
    );
  }
}

class _PlayPauseButton extends StatelessWidget {
  const _PlayPauseButton({required this.isPlaying, required this.onTap});

  final bool isPlaying;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 64,
        height: 64,
        decoration: BoxDecoration(
          color: scheme.primary,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(color: Colors.black.withValues(alpha: 0.25), blurRadius: 22, offset: const Offset(0, 8)),
          ],
        ),
        child: Icon(isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded, size: 32, color: scheme.onPrimary),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Standalone prompts (no chrome header): permission / connect
// ---------------------------------------------------------------------------

class _PermissionSheet extends ConsumerWidget {
  const _PermissionSheet({required this.provider});

  final MusicProviderId? provider;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    // Two different underlying grants share this sheet: Android's
    // notification access (two-line prominent disclosure required by Play
    // policy — §2.1/§6.8) and iOS Apple Music's `MPMediaLibrary`
    // authorization (M3) — a single, differently-worded line, since the
    // Android copy's "we never read your other notifications" disclosure
    // doesn't apply to a library-access grant.
    final explanationLines =
        Platform.isIOS ? [l10n.musicPermissionExplanationIos] : [
          l10n.musicPermissionExplanationLine1,
          l10n.musicPermissionExplanationLine2,
        ];
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(22, 8, 22, 22),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: scheme.primary.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
              child: Icon(Icons.graphic_eq_rounded, size: 32, color: scheme.primary),
            ),
            const SizedBox(height: 16),
            Text(
              l10n.musicPermissionTitle,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'PlusJakartaSans',
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: scheme.onSurface,
                letterSpacing: -0.3,
              ),
            ),
            const SizedBox(height: 10),
            for (final line in explanationLines) ...[
              Text(
                line,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'PlusJakartaSans',
                  fontSize: 13.5,
                  fontWeight: FontWeight.w500,
                  color: scheme.onSurfaceVariant,
                  height: 1.55,
                ),
              ),
              if (line != explanationLines.last) const SizedBox(height: 4),
            ],
            const SizedBox(height: 20),
            _FilledCta(
              icon: Icons.settings_rounded,
              label: l10n.musicPermissionCta,
              onTap: () => ref.read(musicControllerProvider.notifier).requestPermission(),
            ),
            const SizedBox(height: 15),
            _NotNowLink(label: l10n.musicNotNowButton),
          ],
        ),
      ),
    );
  }
}

class _ConnectPromptSheet extends ConsumerWidget {
  const _ConnectPromptSheet({required this.provider});

  final MusicProviderId? provider;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    final name = provider?.displayName ?? '';
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(22, 8, 22, 22),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: scheme.primary.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
              child: Icon(Icons.link_rounded, size: 32, color: scheme.primary),
            ),
            const SizedBox(height: 16),
            Text(
              l10n.musicConnectTitle(name),
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'PlusJakartaSans',
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: scheme.onSurface,
                letterSpacing: -0.3,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              l10n.musicConnectBody(name),
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'PlusJakartaSans',
                fontSize: 13.5,
                fontWeight: FontWeight.w500,
                color: scheme.onSurfaceVariant,
                height: 1.55,
              ),
            ),
            const SizedBox(height: 18),
            _FilledCta(
              icon: Icons.link_rounded,
              label: l10n.musicConnectCta,
              onTap: () => ref.read(musicControllerProvider.notifier).requestPermission(),
            ),
            const SizedBox(height: 15),
            _NotNowLink(label: l10n.musicNotNowButton),
          ],
        ),
      ),
    );
  }
}

class _NotNowLink extends StatelessWidget {
  const _NotNowLink({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: () => Navigator.of(context).pop(),
      child: Text(
        label,
        style: TextStyle(
          fontFamily: 'PlusJakartaSans',
          fontSize: 13.5,
          fontWeight: FontWeight.w700,
          color: scheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Shared CTA buttons — 50 tall, radius md, per the design's spec card
// ---------------------------------------------------------------------------

class _FilledCta extends StatelessWidget {
  const _FilledCta({required this.icon, required this.label, required this.onTap});

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: FilledButton.icon(
        onPressed: onTap,
        style: FilledButton.styleFrom(
          backgroundColor: scheme.primary,
          foregroundColor: scheme.onPrimary,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
        ),
        icon: Icon(icon, size: 20),
        label: Text(
          label,
          style: const TextStyle(fontFamily: 'PlusJakartaSans', fontSize: 14, fontWeight: FontWeight.w800),
        ),
      ),
    );
  }
}

class _TonalCta extends StatelessWidget {
  const _TonalCta({required this.icon, required this.label, required this.onTap});

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: FilledButton.icon(
        onPressed: onTap,
        style: FilledButton.styleFrom(
          backgroundColor: scheme.surfaceContainerHigh,
          foregroundColor: scheme.onSurface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
        ),
        icon: Icon(icon, size: 20),
        label: Text(
          label,
          style: const TextStyle(fontFamily: 'PlusJakartaSans', fontSize: 14, fontWeight: FontWeight.w800),
        ),
      ),
    );
  }
}
