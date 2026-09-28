"use client";

import Link from "next/link";
import { usePathname } from "next/navigation";
import { useTranslations } from "next-intl";
import { Icon } from "@/components/ds/Icon";
import type { NavItemDef } from "./navConfig";

export interface BottomNavProps {
  /** Exactly four items for the client/trainer shells (D-W0.22); the
   *  superadmin shell (D-W0.24) has only three and no "Több" overflow. */
  items: NavItemDef[];
  moreOpen: boolean;
  onMoreClick: () => void;
  /** Hides the "Több" trigger when there's nothing to overflow into. Default true. */
  showMore?: boolean;
}

function label(t: ReturnType<typeof useTranslations>, item: NavItemDef) {
  return t(`${item.namespace ?? "nav"}.${item.key}`);
}

/**
 * DS-02's floating mobile bottom nav (D-W0.22): 68px, r30, `--float` + blur,
 * e3. The active item is a filled primary pill with its icon and label;
 * every other item (including "Több") is a plain 48x48 icon.
 */
export function BottomNav({ items, moreOpen, onMoreClick, showMore = true }: BottomNavProps) {
  const t = useTranslations();
  const common = useTranslations("common");
  const pathname = usePathname();

  return (
    <nav
      className="fixed left-3 right-3 z-20 flex items-center justify-around gap-1 px-2"
      aria-label={t("nav.mainNavigation")}
      style={{
        bottom: "calc(env(safe-area-inset-bottom) + 12px)",
        height: 68,
        borderRadius: "var(--r-hero)",
        background: "var(--float)",
        backdropFilter: "blur(20px)",
        WebkitBackdropFilter: "blur(20px)",
        boxShadow: "var(--e3)",
      }}
    >
      {items.map((item) => {
        const active = pathname.startsWith(item.href);
        const text = label(t, item);
        return (
          <Link
            key={item.href}
            href={item.href}
            aria-label={active ? undefined : text}
            aria-current={active ? "page" : undefined}
            className="lifey-button flex items-center justify-center rounded-[var(--r-pill)] shrink-0"
            style={{
              height: 48,
              minWidth: 48,
              padding: active ? "0 16px" : 0,
              gap: active ? 8 : 0,
              background: active ? "var(--primary)" : "transparent",
              color: active ? "var(--on-primary)" : "var(--text-2)",
            }}
          >
            <Icon name={item.icon} size={24} fill={active ? 1 : 0} />
            {active && <span style={{ fontSize: 14, fontWeight: 700 }}>{text}</span>}
          </Link>
        );
      })}

      {showMore && (
        <button
          type="button"
          onClick={onMoreClick}
          aria-haspopup="dialog"
          aria-expanded={moreOpen}
          aria-label={moreOpen ? undefined : common("more")}
          className="lifey-button flex items-center justify-center rounded-[var(--r-pill)] shrink-0"
          style={{
            height: 48,
            minWidth: 48,
            padding: moreOpen ? "0 16px" : 0,
            gap: moreOpen ? 8 : 0,
            background: moreOpen ? "var(--primary)" : "transparent",
            color: moreOpen ? "var(--on-primary)" : "var(--text-2)",
          }}
        >
          <Icon name="more_horiz" size={24} fill={moreOpen ? 1 : 0} />
          {moreOpen && <span style={{ fontSize: 14, fontWeight: 700 }}>{common("more")}</span>}
        </button>
      )}
    </nav>
  );
}
