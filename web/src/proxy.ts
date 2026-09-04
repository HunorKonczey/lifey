import createMiddleware from "next-intl/middleware";
import type { NextRequest } from "next/server";
import { routing } from "@/i18n/routing";
import { ATTRIBUTION_COOKIE, buildAttributionCookieString, extractAttribution } from "@/lib/attribution";

/**
 * The project's first proxy (Next.js 16 renamed `middleware.ts` to
 * `proxy.ts` — see node_modules/next/dist/docs/01-app/03-api-reference/
 * 03-file-conventions/proxy.md). It negotiates/redirects the locale for the
 * marketing tree (docs/landing_page/65 §D-W3) and writes the first-touch
 * attribution cookie (D-W8) on the way out.
 *
 * The `matcher` below is a correctness-critical line: widening it would put
 * this in front of every authenticated request. It has to stay a literal
 * array declared right here — Next's build-time route-segment-config
 * analysis rejects anything derived from an import, even `{ matcher }` where
 * `matcher` is itself an imported array. It has its own test in
 * `proxy.test.ts`, asserting the authenticated routes it must never touch.
 */
const handleI18nRouting = createMiddleware(routing);

export default function proxy(request: NextRequest) {
  const response = handleI18nRouting(request);

  // First-touch attribution, written on the *first response* rather than
  // from a client effect (`AttributionCapture.tsx`, which stays as the
  // fallback): a visitor who bounces before hydration — or never runs the
  // bundle at all — used to be attributed to nothing.
  //
  // First-touch, not last-touch: an existing cookie means the original touch
  // already won, and whatever CTA this request carries must not replace it.
  if (!request.cookies.has(ATTRIBUTION_COOKIE)) {
    const value = extractAttribution(request.nextUrl.search);
    // Appending the same string `AttributionCapture` assigns to
    // `document.cookie` — instead of `response.cookies.set()` — keeps both
    // writers byte-identical: same encoding, same max-age, one format test.
    if (value) response.headers.append("set-cookie", buildAttributionCookieString(value));
  }

  return response;
}

export const config = {
  matcher: ["/", "/(hu|en)/:path*"],
};
