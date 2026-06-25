import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import 'nav_collapse_controller.dart';

/// A date-range filter for time-ordered lists (meals, sessions).
///
/// [week] is a rolling 7-day window (today and the previous 6 days), matching
/// the dashboard's weekly statistics.
enum DateRangeFilter {
  today,
  week,
  all;

  String label(AppLocalizations l10n) => switch (this) {
        DateRangeFilter.today => l10n.dateFilterToday,
        DateRangeFilter.week => l10n.dateFilterWeek,
        DateRangeFilter.all => l10n.dateFilterAll,
      };

  /// Whether [dateTime] (any zone) falls within this range, evaluated in local time.
  bool matches(DateTime dateTime) {
    if (this == DateRangeFilter.all) return true;
    final local = dateTime.toLocal();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final day = DateTime(local.year, local.month, local.day);
    return switch (this) {
      DateRangeFilter.today => day == today,
      DateRangeFilter.week =>
        !day.isBefore(today.subtract(const Duration(days: 6))),
      DateRangeFilter.all => true,
    };
  }
}

/// Compact filter button for AppBar trailing: shows the active label + opens
/// a popup menu. Animates with the AppBar collapse state.
class DateRangeFilterButton extends StatelessWidget {
  const DateRangeFilterButton({
    super.key,
    required this.value,
    required this.onChanged,
  });

  final DateRangeFilter value;
  final ValueChanged<DateRangeFilter> onChanged;

  @override
  Widget build(BuildContext context) {
    final collapsed = NavCollapseScope.collapsedOf(context);
    final scheme = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;
    final size = collapsed ? 32.0 : 40.0;
    final radius = collapsed ? 11.0 : 13.0;
    final iconSize = collapsed ? 18.0 : 21.0;

    return PopupMenuButton<DateRangeFilter>(
      initialValue: value,
      onSelected: onChanged,
      padding: EdgeInsets.zero,
      itemBuilder: (context) => [
        for (final f in DateRangeFilter.values)
          PopupMenuItem(
            value: f,
            child: Row(
              children: [
                SizedBox(
                  width: 20,
                  child: f == value
                      ? Icon(Icons.check, size: 16, color: scheme.primary)
                      : null,
                ),
                const SizedBox(width: 4),
                Text(f.label(AppLocalizations.of(context)!)),
              ],
            ),
          ),
      ],
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 150),
            child: Text(
              value.label(l10n),
              key: ValueKey(value),
              style: TextStyle(
                fontFamily: 'PlusJakartaSans',
                fontSize: collapsed ? 11.0 : 13.0,
                fontWeight: FontWeight.w600,
                color: scheme.onSurfaceVariant,
              ),
            ),
          ),
          const SizedBox(width: 6),
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: size,
            height: size,
            decoration: BoxDecoration(
              color: scheme.surfaceContainerLowest,
              borderRadius: BorderRadius.circular(radius),
            ),
            child: Center(
              child: Icon(
                Icons.filter_list_rounded,
                size: iconSize,
                color: scheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Generic labeled filter button — same visual as [DateRangeFilterButton] but
/// works with arbitrary [String] values. Use an empty string as a sentinel for
/// "no filter / All" when the real value would be nullable.
class LabeledFilterButton extends StatelessWidget {
  const LabeledFilterButton({
    super.key,
    required this.label,
    required this.items,
    required this.onSelected,
  });

  /// Text shown to the left of the filter icon.
  final String label;

  /// Popup menu entries — build them with [PopupMenuItem<String>].
  final List<PopupMenuEntry<String>> items;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    final collapsed = NavCollapseScope.collapsedOf(context);
    final scheme = Theme.of(context).colorScheme;
    final size = collapsed ? 32.0 : 40.0;
    final radius = collapsed ? 11.0 : 13.0;
    final iconSize = collapsed ? 18.0 : 21.0;

    return PopupMenuButton<String>(
      onSelected: onSelected,
      padding: EdgeInsets.zero,
      itemBuilder: (context) => items,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 150),
            child: Text(
              label,
              key: ValueKey(label),
              style: TextStyle(
                fontFamily: 'PlusJakartaSans',
                fontSize: collapsed ? 11.0 : 13.0,
                fontWeight: FontWeight.w600,
                color: scheme.onSurfaceVariant,
              ),
            ),
          ),
          const SizedBox(width: 6),
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: size,
            height: size,
            decoration: BoxDecoration(
              color: scheme.surfaceContainerLowest,
              borderRadius: BorderRadius.circular(radius),
            ),
            child: Center(
              child: Icon(
                Icons.filter_list_rounded,
                size: iconSize,
                color: scheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Segmented "Today / Week / All" control for filtering a list by date.
class DateRangeFilterBar extends StatelessWidget {
  const DateRangeFilterBar({
    super.key,
    required this.value,
    required this.onChanged,
  });

  final DateRangeFilter value;
  final ValueChanged<DateRangeFilter> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
      child: SegmentedButton<DateRangeFilter>(
        showSelectedIcon: false,
        segments: [
          for (final filter in DateRangeFilter.values)
            ButtonSegment(value: filter, label: Text(filter.label(l10n))),
        ],
        selected: {value},
        onSelectionChanged: (selection) => onChanged(selection.first),
      ),
    );
  }
}
