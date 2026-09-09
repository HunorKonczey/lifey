/**
 * First-touch marketing attribution (docs/landing_page/65 D-W8). Pure
 * functions only — `AttributionCapture.tsx` is the one place that actually
 * touches `document.cookie`, so this file stays trivially unit-testable
 * without a DOM.
 */
export const ATTRIBUTION_COOKIE = "lifey_attrib";
export const ATTRIBUTION_COOKIE_MAX_AGE_DAYS = 30;

const UTM_KEYS = ["utm_source", "utm_medium", "utm_campaign", "utm_term", "utm_content"] as const;

/**
 * What a visitor's *first* page load in this browser was tagged with —
 * an inbound `utm_*` set (an external campaign) if present, else this
 * site's own `?src=<page>-<slot>` if that's what the first page carried.
 * `utm_*` wins when both are present: it identifies where the visitor
 * actually came from, which `src` (an internal landing detail) can't.
 * Returns `null` when the query string carries neither — nothing to
 * attribute yet, try again on the next page.
 */
export function extractAttribution(search: string): string | null {
  const params = new URLSearchParams(search);
  const utmPairs = UTM_KEYS.map((key) => [key, params.get(key)] as const).filter(([, v]) => v);
  if (utmPairs.length > 0) {
    return utmPairs.map(([key, value]) => `${key}=${encodeURIComponent(value as string)}`).join("&");
  }
  const src = params.get("src");
  return src ? `src=${encodeURIComponent(src)}` : null;
}

/** Reads `ATTRIBUTION_COOKIE` from a raw `document.cookie` string. */
export function readAttributionCookie(cookieString: string): string | null {
  const match = cookieString.match(new RegExp(`(?:^|; )${ATTRIBUTION_COOKIE}=([^;]*)`));
  return match ? decodeURIComponent(match[1]) : null;
}

/** The `document.cookie` assignment string — 30 days, no personal data (63 §5). */
export function buildAttributionCookieString(value: string): string {
  const maxAgeSeconds = ATTRIBUTION_COOKIE_MAX_AGE_DAYS * 24 * 60 * 60;
  return `${ATTRIBUTION_COOKIE}=${encodeURIComponent(value)}; max-age=${maxAgeSeconds}; path=/; samesite=lax`;
}
