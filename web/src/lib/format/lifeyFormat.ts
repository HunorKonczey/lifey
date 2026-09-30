/**
 * One place for how numbers and dates look on screen (D-W0.8), on `Intl` —
 * a web counterpart of `mobile/lib/core/format/lifey_format.dart`, adapted to
 * what the web canvases actually show (DS-07). The function *names* and a
 * few examples differ from mobile's file where the web needs a different
 * shape (`grams` keeps one decimal here; mobile's is always whole), but the
 * discipline is the same:
 *
 * - Thousands are grouped per locale: "17,519" English, "17 519" Hungarian.
 * - Round only at display time; never sum values that were already rounded.
 * - Signed changes use a real minus sign (U+2212), "+" for gains, "±" for a
 *   change that rounds to zero — never a bare "0" with no sign at all.
 * - Every format is built with an explicit locale; the app never relies on
 *   a default locale.
 * - `date-fns` stays for date *arithmetic* (adding days, week starts) —
 *   every displayed date goes through this file instead of `date-fns`'
 *   `format()`, which is how the old top bar leaked English month names into
 *   Hungarian ("MMM d" has no locale awareness on its own).
 *
 * Display only — not for prefilling editable fields (a Hungarian decimal
 * comma isn't what a number `<input>` parses).
 */

const MINUS = "−";

export function isHuLocale(locale: string): boolean {
  return locale.split(/[-_]/)[0].toLowerCase() === "hu";
}

function startOfDay(date: Date): Date {
  return new Date(date.getFullYear(), date.getMonth(), date.getDate());
}

function diffCalendarDays(from: Date, to: Date): number {
  const ms = startOfDay(to).getTime() - startOfDay(from).getTime();
  return Math.round(ms / 86_400_000);
}

export interface LifeyFormat {
  readonly locale: string;

  /** Whole number with locale grouping, plus an optional unit: `integer(17519, "kcal")` → "17,519 kcal" / "17 519 kcal". */
  integer(value: number, unit?: string): string;
  /** A number with up to `maxDigits` decimals and no trailing zero: `number(20)` → "20", `number(14.8)` → "14.8" / "14,8". */
  number(value: number, maxDigits?: number): string;
  /** The weight without its unit: `weightNumber(69.6)` → "69.6" / "69,6". */
  weightNumber(value: number): string;
  /** A calendar day relative to today, no time: "today" / "ma", "yesterday" / "tegnap", else `shortDate` ("Sep 25" / "szept. 25."). */
  relativeDay(date: Date, now: Date): string;
  /** One decimal, always shown, plus " kg": `weight(69.6)` → "69.6 kg" / "69,6 kg". */
  weight(value: number): string;
  /** Up to one decimal (no trailing zero forced), plus " g": `grams(166.68)` → "166.7 g" / "166,7 g". */
  grams(value: number): string;
  /** A litre amount without its unit, one decimal minimum: `litreNumber(1.6)` → "1.6" / "1,6", `litreNumber(0.25)` → "0.25" / "0,25". */
  litreNumber(value: number): string;
  /** A litre amount with its unit: `litres(0.5)` → "0.5 L" / "0,5 L". */
  litres(value: number): string;
  /** Two litre amounts over a goal, one string: `litresOfGoal(1.6, 2.5)` → "1.6 / 2.5 L". */
  litresOfGoal(current: number, goal: number): string;
  /** Month + day for axes and rows: "Sep 26" / "szept. 26." */
  shortDate(date: Date): string;
  /** A span of days for a period stepper: "Sep 21 – 27" / "szept. 21–27." within a month, "Aug 31 – Sep 6" / "aug. 31. – szept. 6." across two. */
  dateRange(start: Date, end: Date): string;
  /** A date with its year, no weekday: "May 14, 1994" / "1994. máj. 14.". */
  mediumDate(date: Date): string;
  /** Just the month for a year chart's X axis: "Sep" / "szept.". */
  monthShort(date: Date): string;
  /** A whole month for the month view's stepper: "September 2026" / "2026. szeptember". */
  monthYear(date: Date): string;
  /** Weekday + month + day + year: "Saturday, Sep 27, 2026" / "2026. szept. 27., szombat" */
  longDate(date: Date): string;
  /** The top-bar date-stepper label: "Today · Sat, Sep 27" / "Ma · szept. 27., szombat"; a bare weekday+date with no prefix on any other day. */
  dayLabel(date: Date, today: Date): string;
  /** A timestamp relative to now: "yesterday 6:20 PM" / "tegnap 18:20", "3 days ago" / "3 napja", falling back to `shortDate` past a week. */
  relative(date: Date, now: Date): string;
  /** 24-hour in Hungarian, 12-hour with AM/PM in English — never seconds: "18:00" / "6:00 PM". */
  time(date: Date): string;
  /** Minutes:seconds per kilometre, same shape in both languages: "5:48 /km". */
  pace(secondsPerKm: number): string;
  /** Compact chart-axis label: "2.4k" English, "2,4 e" Hungarian ("e" = ezer, not the SI "k"). */
  compactAxis(value: number): string;
  /** Short weekday for chart/calendar column headers: EN "Mon"…"Sun", HU "H K Sze Cs P Szo V" (Intl's own abbreviations — Hungarian's narrowest form repeats "Sz" for Wednesday and Saturday, so this uses "short", not "narrow"). */
  weekdayShort(date: Date): string;
  /** A signed change: "+2.5", "−0.4 kg" (U+2212), "±0 kg" for a change that rounds to zero — never an unsigned "0". */
  signedDelta(value: number, opts?: { digits?: number; unit?: string }): string;
}

export function createFormat(locale: string): LifeyFormat {
  const hu = isHuLocale(locale);
  const todayWord = hu ? "Ma" : "Today";
  const yesterdayWord = hu ? "tegnap" : "yesterday";

  // `useGrouping: "always"` — Hungarian's CLDR default only groups from 5
  // digits up (`minimumGroupingDigits: 2`), so a bare `new
  // Intl.NumberFormat("hu")` renders "1739", not "1 739". Forcing grouping
  // keeps 4-digit numbers grouped like every other client (mobile's `intl`
  // package groups them by default) — "both clients show the same numbers".
  const intFmt = new Intl.NumberFormat(locale, { maximumFractionDigits: 0, useGrouping: "always" });
  const weightFmt = new Intl.NumberFormat(locale, { minimumFractionDigits: 1, maximumFractionDigits: 1, useGrouping: "always" });
  const gramsFmt = new Intl.NumberFormat(locale, { minimumFractionDigits: 0, maximumFractionDigits: 1, useGrouping: "always" });
  const litresFmt = new Intl.NumberFormat(locale, { minimumFractionDigits: 1, maximumFractionDigits: 2, useGrouping: "always" });
  const shortDateFmt = new Intl.DateTimeFormat(locale, { month: "short", day: "numeric" });
  const mediumDateFmt = new Intl.DateTimeFormat(locale, { year: "numeric", month: "short", day: "numeric" });
  const monthShortFmt = new Intl.DateTimeFormat(locale, { month: "short" });
  const monthYearFmt = new Intl.DateTimeFormat(locale, { month: "long", year: "numeric" });
  const longDateFmt = new Intl.DateTimeFormat(locale, {
    weekday: "long",
    year: "numeric",
    month: "short",
    day: "numeric",
  });
  // HU spells the weekday out ("szombat"), EN abbreviates it ("Sat") — both
  // canvas examples (DS-02's day-label pill; W1's "Today · Sat, Sep 27").
  const weekdayDateFmt = new Intl.DateTimeFormat(locale, {
    weekday: hu ? "long" : "short",
    month: "short",
    day: "numeric",
  });
  const timeFmt = new Intl.DateTimeFormat(locale, hu
    ? { hour: "2-digit", minute: "2-digit", hour12: false }
    : { hour: "numeric", minute: "2-digit", hour12: true });
  const weekdayShortFmt = new Intl.DateTimeFormat(locale, { weekday: "short" });

  function integer(value: number, unit?: string): string {
    const text = intFmt.format(Math.round(value));
    return unit ? `${text} ${unit}` : text;
  }

  function decimal(value: number, digits: number): string {
    return new Intl.NumberFormat(locale, {
      minimumFractionDigits: digits,
      maximumFractionDigits: digits,
      useGrouping: "always",
    }).format(value);
  }

  function number(value: number, maxDigits = 1): string {
    return new Intl.NumberFormat(locale, { minimumFractionDigits: 0, maximumFractionDigits: maxDigits, useGrouping: "always" }).format(value);
  }

  function weightNumber(value: number): string {
    return weightFmt.format(value);
  }

  function relativeDay(date: Date, now: Date): string {
    const diff = diffCalendarDays(date, now);
    if (diff === 0) return hu ? "ma" : "today";
    if (diff === 1) return yesterdayWord;
    return shortDate(date);
  }

  function weight(value: number): string {
    return `${weightFmt.format(value)} kg`;
  }

  function grams(value: number): string {
    return `${gramsFmt.format(value)} g`;
  }

  function litreNumber(value: number): string {
    return litresFmt.format(value);
  }

  function litres(value: number): string {
    return `${litresFmt.format(value)} L`;
  }

  function litresOfGoal(current: number, goal: number): string {
    return `${litresFmt.format(current)} / ${litresFmt.format(goal)} L`;
  }

  function shortDate(date: Date): string {
    return shortDateFmt.format(date);
  }

  function dateRange(start: Date, end: Date): string {
    return shortDateFmt.formatRange(start, end);
  }

  function mediumDate(date: Date): string {
    return mediumDateFmt.format(date);
  }

  function monthShort(date: Date): string {
    return monthShortFmt.format(date);
  }

  function monthYear(date: Date): string {
    return monthYearFmt.format(date);
  }

  function longDate(date: Date): string {
    return longDateFmt.format(date);
  }

  function weekdayDate(date: Date): string {
    return weekdayDateFmt.format(date);
  }

  function dayLabel(date: Date, today: Date): string {
    const label = weekdayDate(date);
    return diffCalendarDays(date, today) === 0 ? `${todayWord} · ${label}` : label;
  }

  function time(date: Date): string {
    return timeFmt.format(date);
  }

  function relative(date: Date, now: Date): string {
    const diff = diffCalendarDays(date, now);
    if (diff === 0) return `${todayWord} ${time(date)}`;
    if (diff === 1) return `${yesterdayWord} ${time(date)}`;
    if (diff >= 2 && diff <= 6) return hu ? `${diff} napja` : `${diff} days ago`;
    return shortDate(date);
  }

  function pace(secondsPerKm: number): string {
    const totalSeconds = Math.round(secondsPerKm);
    const minutes = Math.floor(totalSeconds / 60);
    const seconds = totalSeconds % 60;
    return `${minutes}:${String(seconds).padStart(2, "0")} /km`;
  }

  function compactAxis(value: number): string {
    if (Math.abs(value) < 1000) return integer(value);
    const thousands = value / 1000;
    const text = new Intl.NumberFormat(locale, { maximumFractionDigits: 1, useGrouping: "always" }).format(thousands);
    return hu ? `${text} e` : `${text}k`;
  }

  function signedDelta(value: number, opts: { digits?: number; unit?: string } = {}): string {
    const { digits = 1, unit } = opts;
    const roundedAbs = Number(Math.abs(value).toFixed(digits));
    const text = digits === 0 ? integer(roundedAbs) : decimal(roundedAbs, digits);
    const suffix = unit ? ` ${unit}` : "";
    if (roundedAbs === 0) return `±${text}${suffix}`;
    return (value < 0 ? MINUS : "+") + text + suffix;
  }

  function weekdayShort(date: Date): string {
    return weekdayShortFmt.format(date);
  }

  return {
    locale,
    integer,
    number,
    weightNumber,
    relativeDay,
    weight,
    grams,
    litreNumber,
    litres,
    litresOfGoal,
    shortDate,
    dateRange,
    mediumDate,
    monthShort,
    monthYear,
    longDate,
    dayLabel,
    relative,
    time,
    pace,
    compactAxis,
    weekdayShort,
    signedDelta,
  };
}
