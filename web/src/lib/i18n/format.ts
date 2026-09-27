"use client";

import { useCallback } from "react";
import { format } from "date-fns";
import { enUS, hu } from "date-fns/locale";
import { useLocale, type Locale } from "@/lib/hooks/useLocale";

export const DATE_LOCALES = { en: enUS, hu } as const;

/**
 * Semantic date shapes, spelled per UI language. Hungarian puts the year first
 * and closes the day with a dot ("2026. szept. 27."), English does neither
 * ("Sep 27, 2026") — a single date-fns pattern can't serve both.
 */
const PATTERNS = {
  en: {
    day: "MMM d",
    dayTime: "MMM d, HH:mm",
    dayYear: "MMM d, yyyy",
    dayYearTime: "MMM d, yyyy · HH:mm",
    weekday: "EEE",
    dateTime: "yyyy-MM-dd HH:mm",
  },
  hu: {
    day: "MMM d.",
    dayTime: "MMM d. HH:mm",
    dayYear: "yyyy. MMM d.",
    dayYearTime: "yyyy. MMM d. · HH:mm",
    weekday: "EEE",
    dateTime: "yyyy. MM. dd. HH:mm",
  },
} as const;

export type DateShape = keyof (typeof PATTERNS)["en"];

export function formatDate(date: Date | string | number, shape: DateShape, locale: Locale): string {
  const d = date instanceof Date ? date : new Date(date);
  return format(d, PATTERNS[locale][shape], { locale: DATE_LOCALES[locale] });
}

/** BCP-47 tag for Intl APIs ("hu" → "hu-HU"). */
export function intlLocale(locale: Locale): string {
  return locale === "hu" ? "hu-HU" : "en-US";
}

/**
 * Locale-aware number: "69,6" / "11 256" in Hungarian, "69.6" / "11,256" in
 * English. Defaults to at most one decimal — raw floats ("76.394 g") never
 * belong in the UI.
 */
export function formatNumber(value: number, locale: Locale, maxFractionDigits = 1, minFractionDigits = 0): string {
  return new Intl.NumberFormat(intlLocale(locale), {
    maximumFractionDigits: maxFractionDigits,
    minimumFractionDigits: minFractionDigits,
  }).format(value);
}

/** Hook form of {@link formatDate} / {@link formatNumber}, bound to the current UI language. */
export function useFormat() {
  const locale = useLocale((s) => s.locale);
  const date = useCallback((d: Date | string | number, shape: DateShape) => formatDate(d, shape, locale), [locale]);
  const number = useCallback(
    (v: number, maxFractionDigits = 1, minFractionDigits = 0) => formatNumber(v, locale, maxFractionDigits, minFractionDigits),
    [locale],
  );
  return { locale, date, number };
}
