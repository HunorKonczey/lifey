import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/music/music_controller.dart';
import '../../../../core/music/music_provider_id.dart';
import '../../../../core/theme/app_tokens.dart';
import '../../../../l10n/app_localizations.dart';
import 'provider_glyph.dart';

/// Sheet shown from `MusicStickyButton` (no provider chosen yet) or from
/// `MusicPlayerSheet`'s "Switch" action
/// (docs/music/46-workout-music-controls-plan.md §3.5). Selecting a
/// supported+installed row persists it via [MusicController.selectProvider]
/// and pops the sheet with that id — callers that want to follow up with the
/// player sheet react to a non-null result.
class MusicProviderPickerSheet extends ConsumerStatefulWidget {
  const MusicProviderPickerSheet({super.key});

  @override
  ConsumerState<MusicProviderPickerSheet> createState() => _MusicProviderPickerSheetState();
}

class _MusicProviderPickerSheetState extends ConsumerState<MusicProviderPickerSheet> {
  // Installed-state per provider — Android package queries / iOS
  // canOpenURL, both async native calls. Always resolves true in the M1
  // stub (docs/music/46-workout-music-controls-plan.md §2.1/§2.2); rows
  // simply read as "Available" until M2/M3 wire up real detection.
  Map<MusicProviderId, bool> _installed = const {};

  @override
  void initState() {
    super.initState();
    unawaited(_loadInstalled());
  }

  Future<void> _loadInstalled() async {
    final service = ref.read(musicServiceProvider);
    final entries = await Future.wait(MusicProviderId.values.map(
      (id) async => MapEntry(id, await service.isProviderInstalled(id)),
    ));
    if (!mounted) return;
    setState(() => _installed = Map.fromEntries(entries));
  }

  Future<void> _select(MusicProviderId id) async {
    await ref.read(musicControllerProvider.notifier).selectProvider(id);
    if (mounted) Navigator.of(context).pop(id);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    final current = ref.watch(musicControllerProvider).provider;
    final providers = MusicProviderId.values;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.musicPickerTitle,
              style: TextStyle(
                fontFamily: 'PlusJakartaSans',
                fontSize: 19,
                fontWeight: FontWeight.w800,
                color: scheme.onSurface,
                letterSpacing: -0.3,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              l10n.musicPickerSubtitle,
              style: TextStyle(
                fontFamily: 'PlusJakartaSans',
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: scheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 18),
            for (final id in providers) ...[
              _ProviderRow(
                provider: id,
                selected: id == current,
                selectable: id.isSupportedOnThisPlatform && (_installed[id] ?? true),
                statusLabel: _statusLabel(l10n, id, current),
                onTap: () => _select(id),
              ),
              if (id != providers.last) const SizedBox(height: 9),
            ],
            const SizedBox(height: 16),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.info_outline_rounded, size: 17, color: scheme.onSurfaceVariant),
                const SizedBox(width: 9),
                Expanded(
                  child: Text(
                    l10n.musicPickerFooterNote,
                    style: TextStyle(
                      fontFamily: 'PlusJakartaSans',
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: scheme.onSurfaceVariant,
                      height: 1.45,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _statusLabel(AppLocalizations l10n, MusicProviderId id, MusicProviderId? current) {
    if (!id.isSupportedOnThisPlatform) return l10n.musicProviderUnsupportedIos;
    if (id == current) return l10n.musicProviderConnected;
    if (_installed[id] == false) return l10n.musicProviderNotInstalled;
    return l10n.musicProviderAvailable;
  }
}

class _ProviderRow extends StatelessWidget {
  const _ProviderRow({
    required this.provider,
    required this.selected,
    required this.selectable,
    required this.statusLabel,
    required this.onTap,
  });

  final MusicProviderId provider;
  final bool selected;
  final bool selectable;
  final String statusLabel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final row = Container(
      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 13),
      decoration: BoxDecoration(
        color: selected ? scheme.primary.withValues(alpha: 0.14) : scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(AppRadius.input),
        border: selected
            ? Border.all(color: scheme.primary.withValues(alpha: 0.45), width: 1.5)
            : Border.all(color: Colors.transparent, width: 1.5),
      ),
      child: Row(
        children: [
          ProviderGlyph(
            provider: provider,
            diameter: 44,
            background: scheme.surfaceContainerHigh,
            foreground: scheme.onSurface,
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  provider.displayName,
                  style: TextStyle(
                    fontFamily: 'PlusJakartaSans',
                    fontSize: 15.5,
                    fontWeight: FontWeight.w800,
                    color: scheme.onSurface,
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  statusLabel,
                  style: TextStyle(
                    fontFamily: 'PlusJakartaSans',
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: selected ? scheme.primary : scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          if (selected)
            Icon(Icons.check_circle_rounded, size: 24, color: scheme.primary)
          else if (selectable)
            Icon(Icons.chevron_right_rounded, size: 22, color: scheme.onSurfaceVariant.withValues(alpha: 0.6)),
        ],
      ),
    );
    return Opacity(
      opacity: selectable ? 1 : 0.45,
      child: selectable ? GestureDetector(onTap: onTap, child: row) : row,
    );
  }
}
