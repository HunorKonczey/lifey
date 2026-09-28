"use client";

import { useEffect, useState } from "react";
import { usePathname } from "next/navigation";
import { useTranslations } from "next-intl";
import { ThemeToggle } from "@/components/layout/ThemeToggle";
import { routeChrome } from "./routeChrome";
import { DateStepper } from "./DateStepper";

/**
 * DS-02's top bar (D-W0.21) — desktop only (>=768px) since W0.22, which
 * replaced the mobile hamburger + drawer here with `MobileHeader` +
 * `BottomNav`. Transparent over `--bg` at rest, a float surface (82% bg +
 * blur) with a hairline once the page scrolls under it; page title left,
 * the date stepper centred on dated pages (D-W0.14's `routeChrome`), theme
 * toggle right.
 */
export function TopBar() {
  const t = useTranslations();
  const pathname = usePathname();
  const [scrolled, setScrolled] = useState(false);

  useEffect(() => {
    const onScroll = () => setScrolled(window.scrollY > 8);
    onScroll();
    window.addEventListener("scroll", onScroll, { passive: true });
    return () => window.removeEventListener("scroll", onScroll);
  }, []);

  const { titleKey, hasDateStepper } = routeChrome(pathname);
  const title = titleKey ? t(titleKey) : "Lifey";

  return (
    <header
      className="sticky top-0 z-10 flex items-center justify-between gap-4 px-6 transition-colors"
      style={{
        height: 72,
        background: scrolled ? "color-mix(in srgb, var(--bg) 82%, transparent)" : "transparent",
        backdropFilter: scrolled ? "blur(24px)" : "none",
        WebkitBackdropFilter: scrolled ? "blur(24px)" : "none",
        borderBottom: `1px solid ${scrolled ? "var(--hairline)" : "transparent"}`,
        transitionDuration: "var(--dur-hover)",
      }}
    >
      <h1 className="type-page truncate">{title}</h1>

      {hasDateStepper && (
        <div className="flex-1 flex justify-center min-w-0">
          <DateStepper />
        </div>
      )}

      <div className="flex items-center gap-2 shrink-0">
        <ThemeToggle />
      </div>
    </header>
  );
}
