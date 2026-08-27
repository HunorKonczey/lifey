"use client";

import { useEffect } from "react";
import { buildAttributionCookieString, extractAttribution, readAttributionCookie } from "@/lib/attribution";

/**
 * Writes the `lifey_attrib` cookie on a visitor's first-touch page load
 * (docs/landing_page/65 D-W8) — rendered once in the marketing layout, so
 * it runs on every marketing page without every page needing its own copy.
 * Reads `window.location.search` directly rather than `useSearchParams()`
 * (as `InviteDeepLink.tsx` does, Prompt 7) — no Suspense boundary needed,
 * since this never blocks or changes what's rendered, it just writes a
 * cookie as a side effect.
 *
 * First-touch, not last-touch: if the cookie already exists, this is a
 * later visit or a later page in the same visit — the *original* touch
 * already won and must not be overwritten by whatever CTA the visitor
 * clicked most recently.
 */
export function AttributionCapture() {
  useEffect(() => {
    if (readAttributionCookie(document.cookie)) return;
    const value = extractAttribution(window.location.search);
    if (value) document.cookie = buildAttributionCookieString(value);
  }, []);

  return null;
}
