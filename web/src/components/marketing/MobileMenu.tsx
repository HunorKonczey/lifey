"use client";

import { useEffect, useState } from "react";
import Link from "next/link";
import { MarketingNav } from "./MarketingNav";
import { HeaderAuthActions } from "./HeaderAuthActions";

type NavLabels = React.ComponentProps<typeof MarketingNav>["labels"];
type AuthLabels = React.ComponentProps<typeof HeaderAuthActions>["labels"];

/**
 * Hamburger toggle + full-width drawer (design/Lifey Landing.dc.html, L02
 * state 3). Below `md`; the desktop nav/auth row is a sibling, hidden here
 * via `md:hidden` on this whole component's root.
 */
export function MobileMenu({
  navLabels,
  authLabels,
  menuLabels,
}: {
  navLabels: NavLabels;
  authLabels: AuthLabels;
  menuLabels: { openMenu: string; closeMenu: string };
}) {
  const [open, setOpen] = useState(false);

  // Lock body scroll while the drawer is open, and close on Escape.
  useEffect(() => {
    if (!open) return;
    const previousOverflow = document.body.style.overflow;
    document.body.style.overflow = "hidden";
    const onKeyDown = (e: KeyboardEvent) => {
      if (e.key === "Escape") setOpen(false);
    };
    window.addEventListener("keydown", onKeyDown);
    return () => {
      document.body.style.overflow = previousOverflow;
      window.removeEventListener("keydown", onKeyDown);
    };
  }, [open]);

  return (
    <div className="ml-auto md:hidden">
      <button
        type="button"
        onClick={() => setOpen(true)}
        className="w-11 h-11 flex items-center justify-center"
        aria-label={menuLabels.openMenu}
        aria-expanded={open}
      >
        <span className="material-symbols-rounded text-[26px]">menu</span>
      </button>

      {open && (
        <div
          className="fixed inset-0 z-50 bg-surface flex flex-col"
          role="dialog"
          aria-modal="true"
        >
          <div className="h-16 flex items-center px-4 border-b border-outline">
            <Link
              href="/"
              onClick={() => setOpen(false)}
              className="flex items-center gap-2"
            >
              <span
                className="w-[30px] h-[30px] rounded-[9px] flex items-center justify-center"
                style={{ background: "var(--primary)", color: "var(--bg)" }}
              >
                <span
                className="material-symbols-rounded text-[18px]"
                style={{ fontVariationSettings: "'FILL' 1" }}
              >
                eco
              </span>
              </span>
              <span className="text-[17px] font-extrabold">Lifey</span>
            </Link>
            <button
              type="button"
              onClick={() => setOpen(false)}
              className="ml-auto w-11 h-11 flex items-center justify-center"
              aria-label={menuLabels.closeMenu}
            >
              <span className="material-symbols-rounded text-[26px]">close</span>
            </button>
          </div>
          <div className="px-4 pt-2 pb-6 overflow-auto">
            <MarketingNav labels={navLabels} variant="mobile" onNavigate={() => setOpen(false)} />
            <HeaderAuthActions
              labels={authLabels}
              variant="mobile"
              onNavigate={() => setOpen(false)}
            />
          </div>
        </div>
      )}
    </div>
  );
}
