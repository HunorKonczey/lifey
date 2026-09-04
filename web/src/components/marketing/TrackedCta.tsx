"use client";

import Link from "next/link";
import { track } from "@vercel/analytics";

/**
 * The `cta_click` event (docs/landing_page/65 §7: props `page`, `slot`,
 * `audience`). A client leaf inside a server shell — same pattern as
 * `HeaderAuthActions`/`MarketingNav` (Prompt 3) — rather than converting
 * whole sections (Hero, Fork, ...) to client components: only the CTA
 * element itself needs the click handler, not its surrounding copy.
 *
 * Builds the `?src=<page>-<slot>` query itself from the same `page`/`slot`
 * passed to `track()`, so the attribution query param and the analytics
 * event can never drift apart the way two hand-typed copies could.
 * `href` is the plain, already-locale-resolved path with no query string —
 * the server parent computes it (a literal string for an app route like
 * `/register`, or `getPathname({ locale, href })` for a marketing route),
 * since typed marketing pathnames aren't worth threading through a shared
 * client component for what's ultimately still a plain string.
 */
export function TrackedCta({
  href,
  page,
  slot,
  audience,
  className,
  style,
  children,
}: {
  href: string;
  page: string;
  slot: string;
  audience: "trainer" | "client" | "both";
  className?: string;
  style?: React.CSSProperties;
  children: React.ReactNode;
}) {
  const fullHref = `${href}${href.includes("?") ? "&" : "?"}src=${page}-${slot}`;

  return (
    <Link
      href={fullHref}
      className={className}
      style={style}
      onClick={() => track("cta_click", { page, slot, audience })}
    >
      {children}
    </Link>
  );
}
