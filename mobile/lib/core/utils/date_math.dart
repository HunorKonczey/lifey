/// [date] moved by [days] **calendar** days, keeping its wall-clock time.
///
/// `date.add(Duration(days: n))` adds `n * 24` hours, and a local day is 23 or
/// 25 hours long on the two nights a year the clocks change: a local midnight
/// then lands at 23:00 the day before, or at 01:00 the same day, so a "next
/// day" can repeat the day or a week step can land on a Sunday evening. Moving
/// the date fields instead stays on the same wall-clock time (and an exact
/// midnight stays an exact midnight, which the `==` / `Set` lookups on day keys
/// rely on).
DateTime addDays(DateTime date, int days) => date.isUtc
    ? DateTime.utc(date.year, date.month, date.day + days, date.hour, date.minute,
        date.second, date.millisecond, date.microsecond)
    : DateTime(date.year, date.month, date.day + days, date.hour, date.minute,
        date.second, date.millisecond, date.microsecond);
