"use client";

import { useEffect } from "react";
import { buildAttributionCookieString, extractAttribution, readAttributionCookie } from "@/lib/attribution";

/**
 * The *fallback* writer of the `lifey_attrib` first-touch cookie
 * (docs/landing_page/65 D-W8). `src/proxy.ts` is the primary one: it sets the
 * cookie on the response itself, so a visitor who bounces before hydration —
 * or never runs the bundle at all — is still attributed. This effect only has
 * anything left to do on a marketing page the proxy didn't see, its matcher
 * being deliberately narrow (D-W3); otherwise the cookie already exists by
 * the time it runs, and the check below makes it a no-op.
 *
 * Rendered once in the marketing layout, so it covers every marketing page
 * without every page needing its own copy.
 *
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
