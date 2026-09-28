"use client";

import { useRef, useState } from "react";
import { usePathname } from "next/navigation";
import { useTranslations } from "next-intl";
import type { SessionUser } from "@/features/auth/types";
import { routeChrome } from "./routeChrome";
import { DateStepper } from "./DateStepper";
import { AccountMenu } from "./AccountMenu";

export interface MobileHeaderProps {
  user: SessionUser;
  avatarUrl: string | null;
  onLogout: () => void;
}

/**
 * DS-02's mobile header (D-W0.22): page title + an avatar chip opening
 * `AccountMenu` (replaces the desktop sidebar's user chip below 768px,
 * since there's no sidebar there any more), the date stepper on its own
 * full-width row underneath on dated pages.
 */
export function MobileHeader({ user, avatarUrl, onLogout }: MobileHeaderProps) {
  const t = useTranslations("nav");
  const pathname = usePathname();
  const chipRef = useRef<HTMLButtonElement>(null);
  const [menuOpen, setMenuOpen] = useState(false);

  const { titleKey, hasDateStepper } = routeChrome(pathname);
  const title = titleKey ? t(titleKey) : "Lifey";

  return (
    <header
      className="sticky top-0 z-10 flex flex-col gap-3 px-4 pt-3 pb-3"
      style={{ background: "var(--bg)", borderBottom: "1px solid var(--hairline)" }}
    >
      <div className="flex items-center justify-between gap-3">
        <h1 className="type-page truncate">{title}</h1>
        <button
          ref={chipRef}
          type="button"
          onClick={() => setMenuOpen((v) => !v)}
          aria-haspopup="menu"
          aria-expanded={menuOpen}
          className="inline-flex items-center justify-center rounded-full overflow-hidden shrink-0"
          style={{ width: 36, height: 36, background: "var(--primary)", color: "var(--on-primary)", fontSize: 14, fontWeight: 700 }}
        >
          {avatarUrl ? (
            // Blob object URLs aren't compatible with next/image's optimizer.
            // eslint-disable-next-line @next/next/no-img-element
            <img src={avatarUrl} alt="" className="w-full h-full object-cover" />
          ) : (
            user.email.charAt(0).toUpperCase()
          )}
        </button>
        <AccountMenu open={menuOpen} onClose={() => setMenuOpen(false)} anchorRef={chipRef} onLogout={onLogout} />
      </div>
      {hasDateStepper && (
        <div className="flex justify-center w-full">
          <DateStepper />
        </div>
      )}
    </header>
  );
}
