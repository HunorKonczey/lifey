"use client";

import { useLocale } from "next-intl";
import { Link, usePathname } from "@/i18n/navigation";
import { routing } from "@/i18n/routing";

/**
 * Footer-only per the delivered canvas (design/Lifey Landing.dc.html, L02) —
 * there is no header language switch in this design (confirmed against the
 * canvas source; the original 65/68 written spec called for one in the
 * header too, but the canvas is the source of truth per 68 §12).
 *
 * `usePathname()` from the marketing navigation module returns the internal,
 * locale-agnostic route key (e.g. "/pricing"), which is exactly what `Link`
 * needs to produce the correctly localized URL for the target locale —
 * switching language never loses the current page (65 §10.3).
 */
export function FooterLanguageSwitch() {
  const locale = useLocale();
  const pathname = usePathname();

  return (
    <div className="flex gap-1.5 mt-4">
      {routing.locales.map((l) => {
        const active = l === locale;
        return (
          <Link
            key={l}
            href={pathname}
            locale={l}
            className="h-9 rounded-pill flex items-center px-3 text-[13px] font-extrabold"
            style={{
              background: active ? "var(--surface-container)" : "transparent",
              color: active ? "var(--on-surface)" : "var(--muted)",
            }}
            aria-current={active ? "true" : undefined}
          >
            {l.toUpperCase()}
          </Link>
        );
      })}
    </div>
  );
}
