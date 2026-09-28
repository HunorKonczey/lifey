"use client";

import { useRef, useState } from "react";
import { usePathname } from "next/navigation";
import { useTranslations } from "next-intl";
import { Avatar } from "@/components/ds/Avatar";
import type { SessionUser } from "@/features/auth/types";
import { routeChrome } from "./routeChrome";
import { DateStepper } from "./DateStepper";
import { AccountMenu } from "./AccountMenu";

export interface MobileHeaderProps {
  user: SessionUser;
  avatarUrl: string | null;
  onLogout: () => void;
  roleRing?: "trainer" | "superadmin";
  trainerPrefs?: boolean;
}

function displayName(user: SessionUser) {
  return user.firstName && user.lastName ? `${user.firstName} ${user.lastName}` : user.email.split("@")[0];
}

/**
 * DS-02's mobile header (D-W0.22/23): page title + an avatar chip opening
 * `AccountMenu` (replaces the desktop sidebar's user chip below 768px,
 * since there's no sidebar there any more), the date stepper on its own
 * full-width row underneath on dated pages.
 */
export function MobileHeader({ user, avatarUrl, onLogout, roleRing, trainerPrefs }: MobileHeaderProps) {
  const t = useTranslations();
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
          className="shrink-0"
        >
          <Avatar name={displayName(user)} email={user.email} src={avatarUrl ?? undefined} roleRing={roleRing} size={36} />
        </button>
        <AccountMenu open={menuOpen} onClose={() => setMenuOpen(false)} anchorRef={chipRef} onLogout={onLogout} trainerPrefs={trainerPrefs} />
      </div>
      {hasDateStepper && (
        <div className="flex justify-center w-full">
          <DateStepper />
        </div>
      )}
    </header>
  );
}
