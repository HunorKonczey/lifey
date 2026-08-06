import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../l10n/app_localizations.dart';

/// "Today" / "Yesterday" / "1 Aug" chip separating days in the stream.
class DayDivider extends StatelessWidget {
  const DayDivider({super.key, required this.day});

  final DateTime day;

  /// True when [a] and [b] fall on different calendar days, i.e. a divider
  /// belongs between them.
  static bool separates(DateTime a, DateTime b) {
    return a.year != b.year || a.month != b.month || a.day != b.day;
  }

  String _label(BuildContext context, AppLocalizations l10n) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final that = DateTime(day.year, day.month, day.day);
    final difference = today.difference(that).inDays;
    if (difference == 0) return l10n.chatToday;
    if (difference == 1) return l10n.chatYesterday;
    final locale = Localizations.localeOf(context).languageCode;
    // Year only once the message is from a different year — "3 Aug" reads
    // better than "3 Aug 2026" for the common case.
    return that.year == today.year
        ? DateFormat.MMMd(locale).format(that)
        : DateFormat.yMMMd(locale).format(that);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;

    return Center(
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 12),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
        decoration: BoxDecoration(
          color: scheme.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(
          _label(context, l10n),
          style: TextStyle(
            fontFamily: 'PlusJakartaSans',
            fontSize: 11.5,
            fontWeight: FontWeight.w600,
            color: scheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}
