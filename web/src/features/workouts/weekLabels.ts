import { formatDate, formatNumber, intlLocale } from "@/lib/i18n/format";
import type { Locale } from "@/lib/hooks/useLocale";
import type { WeekSummary } from "./sessionGroups";

/**
 * "szept. 22–27." / "Sep 22–27" inside one month, "szept. 28. – okt. 4." / "Sep 28 – Oct 4" across two —
 * the range after "Ez a hét ·" in a week header (W3-A).
 */
export function weekRangeLabel(start: Date, end: Date, locale: Locale): string {
  const first = formatDate(start, "day", locale);
  if (start.getMonth() === end.getMonth() && start.getFullYear() === end.getFullYear()) {
    return `${first.replace(/\.$/, "")}–${end.getDate()}${locale === "hu" ? "." : ""}`;
  }
  return `${first} – ${formatDate(end, "day", locale)}`;
}

/** "3 ó 12 p" / "3h 12m"; under an hour "52 p" / "52m". */
export function formatHoursMinutes(totalSeconds: number, locale: Locale): string {
  const minutes = Math.round(totalSeconds / 60);
  const h = Math.floor(minutes / 60);
  const m = minutes % 60;
  const [hUnit, mUnit] = locale === "hu" ? ["ó", "p"] : ["h", "m"];
  const sep = locale === "hu" ? " " : "";
  if (h === 0) return `${m}${sep}${mUnit}`;
  return `${h}${sep}${hUnit} ${m}${sep}${mUnit}`;
}

/** "5,2 km" — one decimal, locale separator. */
export function formatKm(meters: number, locale: Locale): string {
  return `${formatNumber(meters / 1000, locale, 1)} km`;
}

/** "6 240 kg" — whole kilograms; Hungarian groups from four digits on only when asked to. */
export function formatKg(kg: number, locale: Locale): string {
  return `${new Intl.NumberFormat(intlLocale(locale), { maximumFractionDigits: 0, useGrouping: "always" }).format(kg)} kg`;
}

/**
 * The parts after the workout count in a week header: time, volume, distance — a part with nothing in it
 * (no lifting this week, no distance) is left out rather than shown as "0 kg".
 */
export function weekSummaryParts(summary: WeekSummary, locale: Locale): string[] {
  const parts: string[] = [];
  if (Math.round(summary.seconds / 60) > 0) parts.push(formatHoursMinutes(summary.seconds, locale));
  if (summary.volumeKg > 0) parts.push(formatKg(summary.volumeKg, locale));
  if (summary.distanceMeters > 0) parts.push(formatKm(summary.distanceMeters, locale));
  return parts;
}
