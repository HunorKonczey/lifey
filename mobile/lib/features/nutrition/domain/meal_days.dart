/// Local midnight of [d]'s calendar day.
DateTime dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

/// The seven days the Meals tab's week strip shows: the six before [now]'s
/// day and [now]'s day itself, oldest first (canvas: Fri … Thu, today last).
///
/// Built with calendar arithmetic, not `Duration(days: n)`, so a daylight-
/// saving change inside the week can't shift a day by an hour and repeat or
/// skip a date.
List<DateTime> lastSevenDays(DateTime now) => [
      for (var back = 6; back >= 0; back--) DateTime(now.year, now.month, now.day - back),
    ];

/// The day the Meals tab shows: the user's pick, when it is still one of the
/// [lastSevenDays] (the app may have been open past midnight, so an old pick
/// can have scrolled out of the strip), otherwise today.
DateTime effectiveMealDay(DateTime? selected, DateTime now) {
  final today = dateOnly(now);
  if (selected == null) return today;
  final day = dateOnly(selected);
  final oldest = DateTime(now.year, now.month, now.day - 6);
  return day.isBefore(oldest) || day.isAfter(today) ? today : day;
}
