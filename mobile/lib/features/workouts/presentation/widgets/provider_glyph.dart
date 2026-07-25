import 'package:flutter/material.dart';

import '../../../../core/music/music_provider_id.dart';

/// Monochrome circular monogram placeholder for a music provider — the
/// design system never uses provider brand colors as a background
/// (docs/music/46-workout-music-controls-plan.md §3.4); real brand glyphs
/// are a later asset swap (§6.7). `provider == null` (no provider chosen
/// yet) falls back to a generic note icon.
class ProviderGlyph extends StatelessWidget {
  const ProviderGlyph({
    super.key,
    required this.provider,
    this.diameter = 22,
    this.background,
    this.foreground,
  });

  final MusicProviderId? provider;
  final double diameter;

  /// Fill color for the circle. Null renders an outline ring instead (the
  /// sticky button's "resting" look).
  final Color? background;
  final Color? foreground;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final fg = foreground ?? scheme.onSurfaceVariant;
    if (provider == null) {
      return Icon(Icons.music_note_rounded, size: diameter, color: fg);
    }
    return Container(
      width: diameter,
      height: diameter,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: background,
        border: background == null ? Border.all(color: fg, width: 2) : null,
      ),
      child: Text(
        provider!.monogram,
        style: TextStyle(
          fontFamily: 'PlusJakartaSans',
          fontSize: diameter * 0.46,
          fontWeight: FontWeight.w800,
          color: fg,
        ),
      ),
    );
  }
}
