import 'package:flutter/material.dart';

import '../../../../core/theme/app_tokens.dart';
import '../../../../shared/widgets/ds/lifey_card.dart';

/// A tappable date on a nested card — calendar glyph, the date, a chevron — as
/// in the log-weight sheet. Used for the date of birth in the wizard and in
/// Body & goals.
class DateRow extends StatelessWidget {
  const DateRow({super.key, required this.text, required this.onTap, this.placeholder = false});

  final String text;
  final VoidCallback onTap;

  /// [text] is a prompt ("Date of birth"), not a chosen date: drawn quieter.
  final bool placeholder;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final t = Theme.of(context).textTheme;
    return LifeyCard.nested(
      onTap: onTap,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s16, vertical: AppSpacing.s16),
      child: Row(
        children: [
          Icon(Icons.calendar_today_rounded, size: 22, color: placeholder ? p.text2 : p.text),
          const SizedBox(width: AppSpacing.s12),
          Expanded(
            child: Text(
              text,
              style: t.titleMedium!.copyWith(color: placeholder ? p.text2 : p.text),
            ),
          ),
          Icon(Icons.keyboard_arrow_down_rounded, size: 24, color: p.text2),
        ],
      ),
    );
  }
}
