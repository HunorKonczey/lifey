import 'package:flutter/material.dart';

import '../../../core/theme/app_tokens.dart';

/// The brand tile: a 64 dp rounded square in the primary colour with the
/// initial — the canvas's "L" (login, onboarding welcome).
class BrandTile extends StatelessWidget {
  const BrandTile({super.key, this.icon});

  /// A glyph instead of the initial ("connect Health").
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Align(
      alignment: Alignment.centerLeft,
      child: ExcludeSemantics(
        child: Container(
          width: 64,
          height: 64,
          alignment: Alignment.center,
          decoration: BoxDecoration(color: scheme.primary, borderRadius: AppRadius.controlAll),
          child: icon != null
              ? Icon(icon, size: 32, color: scheme.onPrimary)
              : Text('L', style: Theme.of(context).textTheme.displaySmall!.copyWith(color: scheme.onPrimary)),
        ),
      ),
    );
  }
}

/// A 36/800 screen title with an optional one-line explanation under it — the
/// heading of the sign-in screens and of every onboarding step.
class ScreenHeading extends StatelessWidget {
  const ScreenHeading({super.key, required this.title, this.subtitle});

  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final p = context.palette;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Semantics(header: true, child: Text(title, style: t.displaySmall!.copyWith(color: p.text))),
        if (subtitle != null) ...[
          const SizedBox(height: AppSpacing.s12),
          Text(subtitle!, style: t.bodyLarge!.copyWith(fontWeight: FontWeight.w500, color: p.text2)),
        ],
      ],
    );
  }
}
