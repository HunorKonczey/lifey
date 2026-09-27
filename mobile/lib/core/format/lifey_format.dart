import 'package:flutter/widgets.dart';
import 'package:intl/intl.dart';

/// One place for how numbers and dates look on screen (design system v2,
/// docs/redesign/77-mobile-redesign-plan.md R0.4).
///
/// Rules from the design system canvas:
/// - Thousands are grouped per locale: "1,739" in English, "1 739" in
///   Hungarian — never "17518.6 kcal".
/// - Decimals only where they carry meaning: weight (1), distance (2),
///   litres (1–2). Calories and grams are whole numbers.
/// - Signed changes use a real minus sign (U+2212), "+" for gains, and no
///   sign on zero.
/// - Every format is built with an explicit locale. The app never sets
///   `Intl.defaultLocale`, so a bare `DateFormat('EEE')` renders English in
///   Hungarian mode — the "Thu, Sep 24" leak the redesign removes.
///
/// **Round only at display time; never add up values that were already
/// rounded** — a meal total built from rounded items drifts from the day
/// total by a few kcal.
///
/// This formats numbers only. Unit conversion (kg ↔ lb, km ↔ mi) stays in
/// `core/utils/unit_converters.dart` and `CardioFormatter`. Display only:
/// don't prefill editable text fields with these strings (a Hungarian decimal
/// comma is not what the number parsers expect).
class LifeyFormat {
  LifeyFormat(this.locale);

  /// The formatter for the app's current locale.
  factory LifeyFormat.of(BuildContext context) =>
      LifeyFormat(Localizations.localeOf(context).toLanguageTag());

  /// BCP-47 tag, e.g. `en` or `hu`.
  final String locale;

  bool get _hu => locale.split(RegExp('[-_]')).first == 'hu';

  static const String minus = '−';

  late final NumberFormat _int = NumberFormat.decimalPattern(locale);

  NumberFormat _fixed(int digits) => NumberFormat.decimalPatternDigits(
        locale: locale,
        decimalDigits: digits,
      );

  // ---------------------------------------------------------------------------
  // Numbers
  // ---------------------------------------------------------------------------

  /// Whole number with locale grouping: "1,739" / "1 739".
  String integer(num value) => _int.format(value.round());

  /// Calories — always whole: 17518.6 → "17,519".
  String kcal(num value) => integer(value);

  /// Grams of a macro — always whole.
  String grams(num value) => integer(value);

  /// Weight with one decimal: "64.5" / "64,5".
  String weight(double value) => _fixed(1).format(value);

  /// Distance with two decimals: "5.21" / "5,21".
  String distance(double value) => _fixed(2).format(value);

  /// Litres with one or two decimals: 2.6 → "2.6", 0.25 → "0.25",
  /// 1 → "1.0".
  String litres(double value) {
    final f = NumberFormat.decimalPattern(locale)
      ..minimumFractionDigits = 1
      ..maximumFractionDigits = 2;
    return f.format(value);
  }

  /// Any value at a fixed number of [digits].
  String decimal(double value, int digits) => _fixed(digits).format(value);

  /// A ratio as a percentage: 0.26 → "26%".
  String percent(double ratio) => NumberFormat.percentPattern(locale).format(ratio);

  /// A signed change: "−0.1", "+2.5", "0". Rounds to [digits] first, so a
  /// change that displays as zero never carries a sign.
  String signedDelta(num value, {int digits = 1}) {
    final text = digits == 0 ? integer(value.abs()) : decimal(value.abs().toDouble(), digits);
    final rounded = num.parse(value.abs().toStringAsFixed(digits));
    if (rounded == 0) return digits == 0 ? integer(0) : decimal(0, digits);
    return value < 0 ? '$minus$text' : '+$text';
  }

  /// Compact chart-axis label: 0 → "0", 650 → "650", 1200 → "1.2k",
  /// 13000 → "13k". "k" in both languages — it is the SI prefix, and the
  /// canvases use it on the Hungarian axes too.
  String compactAxis(num value) {
    if (value.abs() < 1000) return integer(value);
    final thousands = value / 1000;
    final f = NumberFormat.decimalPattern(locale)..maximumFractionDigits = 1;
    return '${f.format(thousands)}k';
  }

  // ---------------------------------------------------------------------------
  // Dates and times
  // ---------------------------------------------------------------------------

  /// Long day label for page headers: "Thursday, 24 Sep" /
  /// "Csütörtök, szeptember 24."
  String dayLabel(DateTime date) {
    if (_hu) return _capitalize(DateFormat('EEEE, MMMM d.', locale).format(date));
    return DateFormat('EEEE, d MMM', locale).format(date);
  }

  /// Short day label for rows and pickers: "Thu, 24 Sep" / "Cs, szept. 24."
  String shortDayLabel(DateTime date) {
    if (_hu) return _capitalize('${DateFormat('EEE', locale).format(date)}, ${DateFormat('MMM d.', locale).format(date)}');
    return DateFormat('EEE, d MMM', locale).format(date);
  }

  /// Month and day for chart axes and history rows: "Sep 24" /
  /// "szept. 24." (the canvases' axis labels).
  String shortDate(DateTime date) => DateFormat(_hu ? 'MMM d.' : 'MMM d', locale).format(date);

  /// Full date with the year, for "since" lines: "24 Sep 2026" /
  /// "2026. szept. 24."
  String fullDate(DateTime date) => DateFormat(_hu ? 'y. MMM d.' : 'd MMM y', locale).format(date);

  /// 24-hour clock time: "07:15".
  String time(DateTime date) => DateFormat('HH:mm', locale).format(date);

  /// Weekday and clock time for a list row: "Wed 17:30" / "Sze 17:30".
  String weekdayTime(DateTime date) =>
      _capitalize('${DateFormat('EEE', locale).format(date)} ${time(date)}');

  /// Three-letter weekday, capitalised: "Thu" / "Cs" (the week strip).
  String weekdayShort(DateTime date) =>
      _capitalize(DateFormat('EEE', locale).format(date));

  /// Shortest unambiguous weekday for chart axes: "T" / "Cs". English uses
  /// the one-letter form; Hungarian uses the abbreviation (H K Sze Cs P Szo
  /// V), because its narrow form repeats "Sz" for Wednesday and Saturday.
  String weekdayNarrow(DateTime date) =>
      DateFormat(_hu ? 'EEE' : 'EEEEE', locale).format(date);

  static String _capitalize(String s) =>
      s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);
}
