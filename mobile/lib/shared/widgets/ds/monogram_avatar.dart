import 'package:flutter/material.dart';

import '../../../core/theme/app_tokens.dart';
import '../../../core/theme/app_type.dart';

/// A round avatar with the person's initials — "AK" for Anna Kovács
/// (design system v2; docs/redesign/77-mobile-redesign-plan.md R0.7).
///
/// The canvas fixes a bug of the old header: initials come from the **name**,
/// not the first letter of the e-mail; the e-mail is only the fallback. The
/// signed-in user's avatar is brand olive (the default); other people get a
/// stable metric hue from [MonogramAvatar.colorFor] so a list of clients or
/// chats is easy to scan. With [image] the photo is shown and the initials
/// are the fallback while it loads or if it fails.
class MonogramAvatar extends StatelessWidget {
  const MonogramAvatar({
    super.key,
    this.name,
    this.email,
    this.size = 44,
    this.color,
    this.image,
  });

  /// Display name, e.g. "Anna Kovács".
  final String? name;

  /// Fallback source of the initial when there is no name.
  final String? email;

  /// Diameter; the canvases use 44 (header, chat), 48 (client card), 56
  /// (settings profile).
  final double size;

  /// Tint for someone else's avatar; null = the brand olive tint.
  final Color? color;

  final ImageProvider? image;

  /// "AK" from "Anna Kovács", "A" from "Anna", the e-mail's first letter
  /// when there is no name, "?" when there is nothing. Uses grapheme
  /// clusters, so accented and composed letters stay whole.
  static String initialsFor(String? name, String? email) {
    final words = (name ?? '').trim().split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
    String first(String s) => s.characters.first.toUpperCase();
    if (words.length >= 2) return first(words.first) + first(words.last);
    if (words.length == 1) return first(words.single);
    final mail = (email ?? '').trim();
    if (mail.isNotEmpty) return first(mail);
    return '?';
  }

  /// A stable per-person hue from the metric palette (same seed, same
  /// colour, on every device).
  static Color colorFor(String seed, AppMetricColors m) {
    final hues = [m.water, m.steps, m.fat, m.carbs, m.calories, m.weight];
    final hash = seed.codeUnits.fold<int>(0, (h, c) => (h * 31 + c) & 0x7fffffff);
    return hues[hash % hues.length];
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final brightness = Theme.of(context).brightness;
    final Color bg;
    final Color fg;
    if (color == null) {
      bg = p.primaryTint;
      fg = p.onPrimaryTint;
    } else {
      bg = color!.withValues(alpha: brightness == Brightness.dark ? 0.16 : 0.12);
      fg = color!;
    }
    final initials = Center(
      child: Text(
        initialsFor(name, email),
        style: TextStyle(
          fontFamily: AppType.fontFamily,
          fontSize: size * 0.34,
          fontWeight: FontWeight.w800,
          color: fg,
          height: 1,
        ),
        textScaler: TextScaler.noScaling,
      ),
    );
    return Semantics(
      label: name ?? email,
      image: true,
      excludeSemantics: true,
      child: SizedBox.square(
        dimension: size,
        child: DecoratedBox(
          decoration: BoxDecoration(color: Color.alphaBlend(bg, p.bg), shape: BoxShape.circle),
          child: image == null
              ? initials
              : ClipOval(
                  child: Image(
                    image: image!,
                    width: size,
                    height: size,
                    fit: BoxFit.cover,
                    frameBuilder: (context, child, frame, sync) =>
                        frame == null && !sync ? initials : child,
                    errorBuilder: (context, error, stackTrace) => initials,
                  ),
                ),
        ),
      ),
    );
  }
}
