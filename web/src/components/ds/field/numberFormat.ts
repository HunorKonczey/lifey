
/** "166,7" and "166.7" are both 166.7, whatever the UI language: a comma or a
 *  point is always the decimal separator (there are no thousands separators in
 *  what people type into these fields). `null` for anything that isn't a
 *  number — never throws, so a field can revert to the last good value on blur. */
export function parseLocaleNumber(text: string): number | null {
  const normalized = text.replace(/\s/g, "").replace(",", ".");
  if (normalized === "" || normalized === "-") return null;
  const n = Number(normalized);
  return Number.isFinite(n) ? n : null;
}

/** 166.7 → "166,7" (HU) or "166.7" (EN) — no grouping (a number field's
 *  value is always a single small number, not a list of thousands). */
export function formatLocaleNumber(value: number, locale: string, maxDecimals: number): string {
  return new Intl.NumberFormat(locale, { maximumFractionDigits: maxDecimals, useGrouping: false }).format(value);
}

export function clampNumber(value: number, min?: number, max?: number): number {
  let v = value;
  if (min !== undefined) v = Math.max(min, v);
  if (max !== undefined) v = Math.min(max, v);
  return v;
}

export function roundToDecimals(value: number, decimals: number): number {
  const factor = 10 ** decimals;
  return Math.round(value * factor) / factor;
}
