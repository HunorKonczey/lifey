import 'package:flutter/material.dart';

/// A date-range filter for time-ordered lists (meals, sessions).
///
/// [week] is a rolling 7-day window (today and the previous 6 days), matching
/// the dashboard's weekly statistics.
enum DateRangeFilter {
  today('Today'),
  week('Week'),
  all('All');

  const DateRangeFilter(this.label);

  final String label;

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
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
      child: SegmentedButton<DateRangeFilter>(
        showSelectedIcon: false,
        segments: [
          for (final filter in DateRangeFilter.values)
            ButtonSegment(value: filter, label: Text(filter.label)),
        ],
        selected: {value},
        onSelectionChanged: (selection) => onChanged(selection.first),
      ),
    );
  }
}
