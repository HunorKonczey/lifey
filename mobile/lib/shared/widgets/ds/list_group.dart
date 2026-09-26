import 'package:flutter/material.dart';

import '../../../core/theme/app_tokens.dart';
import '../../../core/theme/app_type.dart';
import 'lifey_card.dart';

/// Related rows in **one** card, split by hairlines — the design's "fewer
/// boxes, more groups" rule (docs/redesign/77-mobile-redesign-plan.md R0.8;
/// dashboard canvas "Today's meals").
///
/// Dividers start under the text (inset 74 = 16 padding + 44 icon + 14 gap),
/// not under the icon — pass [dividerInset] 16 for rows without a leading
/// icon. The card clips, so row ink stays inside the rounded corners.
class ListGroup extends StatelessWidget {
  const ListGroup({
    super.key,
    required this.children,
    this.dividerInset = 74,
    this.footer,
  });

  final List<Widget> children;
  final double dividerInset;

  /// Sits inside the card under the last row **without** a divider — the
  /// dashboard's "+ Meal / Photo" buttons.
  final Widget? footer;

  @override
  Widget build(BuildContext context) {
    final hairline = context.palette.hairline;
    return LifeyCard(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.s4),
      clip: true,
      child: Material(
        type: MaterialType.transparency,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (var i = 0; i < children.length; i++) ...[
              if (i > 0) Divider(height: 1, thickness: 1, indent: dividerInset, color: hairline),
              children[i],
            ],
            if (footer != null) footer!,
          ],
        ),
      ),
    );
  }
}

/// One row of a [ListGroup]: optional icon holder, title, secondary line and
/// a trailing value or chevron. Height follows the content (two-line titles
/// wrap, nothing truncates — the Hungarian rule), never below 48.
class ListRow extends StatelessWidget {
  const ListRow({
    super.key,
    required this.title,
    this.subtitle,
    this.leading,
    this.trailing,
    this.onTap,
    this.onLongPress,
    this.subtitleMaxLines = 2,
  });

  final String title;

  /// Secondary line — "Breakfast · 07:15". Wraps to [subtitleMaxLines].
  final String? subtitle;

  /// Usually a [ListIconHolder].
  final Widget? leading;

  /// Usually a [ListRowValue] or a chevron.
  final Widget? trailing;

  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final int subtitleMaxLines;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final t = Theme.of(context).textTheme;
    final row = ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 48),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s16, vertical: AppSpacing.s12),
        child: Row(
          children: [
            if (leading != null) ...[leading!, const SizedBox(width: 14)],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(title, style: t.titleMedium!.copyWith(fontSize: 15, height: 1.3, color: p.text)),
                  if (subtitle != null) ...[
                    const SizedBox(height: 3),
                    Text(
                      subtitle!,
                      maxLines: subtitleMaxLines,
                      overflow: TextOverflow.ellipsis,
                      style: t.bodySmall!.copyWith(height: 1.4, color: p.text2),
                    ),
                  ],
                ],
              ),
            ),
            if (trailing != null) ...[const SizedBox(width: AppSpacing.s12), trailing!],
          ],
        ),
      ),
    );
    if (onTap == null && onLongPress == null) return row;
    return InkWell(onTap: onTap, onLongPress: onLongPress, child: row);
  }
}

/// The 44 px rounded-square icon badge at the start of a row, tinted in a
/// metric colour (16 % dark / 12 % light) with a filled icon.
class ListIconHolder extends StatelessWidget {
  const ListIconHolder({super.key, required this.icon, required this.color, this.size = 44});

  final IconData icon;
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    final alpha = Theme.of(context).brightness == Brightness.dark ? 0.16 : 0.12;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color.withValues(alpha: alpha),
        borderRadius: AppRadius.controlAll,
      ),
      child: Icon(icon, size: size / 2, color: color),
    );
  }
}

/// The trailing number of a row — "383 kcal": 15/800 tabular, unit 12/600
/// in the secondary text colour. [size] is the number's size (the nutrition
/// meal rows draw it at 16).
class ListRowValue extends StatelessWidget {
  const ListRowValue({super.key, required this.value, this.unit, this.color, this.size = 15});

  final String value;
  final String? unit;
  final Color? color;
  final double size;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Text.rich(
      TextSpan(children: [
        TextSpan(
          text: value,
          style: TextStyle(
            fontFamily: AppType.fontFamily,
            fontSize: size,
            fontWeight: FontWeight.w800,
            color: color ?? p.text,
            fontFeatures: AppType.tabular,
          ),
        ),
        if (unit != null)
          TextSpan(
            text: ' $unit',
            style: TextStyle(fontFamily: AppType.fontFamily, fontSize: 12, fontWeight: FontWeight.w600, color: p.text2),
          ),
      ]),
      maxLines: 1,
      softWrap: false,
    );
  }
}
