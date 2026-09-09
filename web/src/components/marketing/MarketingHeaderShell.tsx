"use client";

import { useEffect, useState } from "react";

/**
 * The sticky chrome around the marketing header: translucent + blurred
 * background always on, a hairline border that only appears once the page
 * has scrolled a little (design/Lifey Landing.dc.html, L02; the "after 8px
 * of scroll" nuance is 68 §3.1 — not shown in the static frame, kept as
 * written since it doesn't contradict the canvas).
 *
 * Text/links inside stay server-rendered; this wrapper only owns the scroll
 * listener, so the header's actual content never needs "use client".
 */
export function MarketingHeaderShell({ children }: { children: React.ReactNode }) {
  const [scrolled, setScrolled] = useState(false);

  useEffect(() => {
    const onScroll = () => setScrolled(window.scrollY > 8);
    onScroll();
    window.addEventListener("scroll", onScroll, { passive: true });
    return () => window.removeEventListener("scroll", onScroll);
  }, []);

  return (
    <header
      className="sticky top-0 z-40 transition-[border-color] duration-150"
      style={{
        background: "color-mix(in srgb, var(--bg) 82%, transparent)",
        backdropFilter: "blur(12px)",
        WebkitBackdropFilter: "blur(12px)",
        borderBottom: `1px solid ${scrolled ? "var(--outline)" : "transparent"}`,
      }}
    >
      {children}
    </header>
  );
}
