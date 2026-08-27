import createMiddleware from "next-intl/middleware";
import { routing } from "@/i18n/routing";

/**
 * The project's first proxy (Next.js 16 renamed `middleware.ts` to
 * `proxy.ts` — see node_modules/next/dist/docs/01-app/03-api-reference/
 * 03-file-conventions/proxy.md). It exists solely to negotiate/redirect the
 * locale for the marketing tree (docs/landing_page/65 §D-W3).
 *
 * The `matcher` below is a correctness-critical line: widening it would put
 * this in front of every authenticated request. It has to stay a literal
 * array declared right here — Next's build-time route-segment-config
 * analysis rejects anything derived from an import, even `{ matcher }` where
 * `matcher` is itself an imported array. It has its own test in
 * `proxy.test.ts`, asserting the authenticated routes it must never touch.
 */
export default createMiddleware(routing);

export const config = {
  matcher: ["/", "/(hu|en)/:path*"],
};
