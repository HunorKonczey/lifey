import 'package:flutter/material.dart';

import '../../../../core/theme/app_tokens.dart';
import '../../../../core/theme/app_type.dart';

/// One section of the debug design gallery. [builder] runs inside the
/// gallery's preview scope, so `Theme.of`, `context.palette`, the locale and
/// the text scaler all reflect the toolbar choices.
///
/// Debug tooling: section text is not localized (it never ships — the route
/// only exists under `kDebugMode`). Sample *content* follows the preview
/// locale where it shows Hungarian length or formatting.
class GallerySection {
  const GallerySection({required this.title, required this.source, required this.builder});

  final String title;

  /// Where on the canvas this section is specified, e.g.
  /// "Design System › Színtokenek" — so a reviewer knows what to hold it
  /// against.
  final String source;

  final WidgetBuilder builder;
}

/// Section header inside the preview.
class GalleryHeading extends StatelessWidget {
  const GalleryHeading(this.section, {super.key});

  final GallerySection section;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.s40, bottom: AppSpacing.s16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(section.title, style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: AppSpacing.s4),
          Text(section.source, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: p.text3)),
        ],
      ),
    );
  }
}

/// A small caps caption, used for sub-groups inside a section.
class GalleryCaption extends StatelessWidget {
  const GalleryCaption(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: AppSpacing.s24, bottom: AppSpacing.s8),
        child: Text(text.toUpperCase(), style: AppType.sectionLabel(color: context.palette.text2)),
      );
}

/// "#RRGGBB", or "#RRGGBB · 82 %" for a translucent colour.
String hexOf(Color c) {
  String two(double v) => (v * 255).round().toRadixString(16).padLeft(2, '0').toUpperCase();
  final hex = '#${two(c.r)}${two(c.g)}${two(c.b)}';
  return c.a >= 0.999 ? hex : '$hex · ${(c.a * 100).round()} %';
}
