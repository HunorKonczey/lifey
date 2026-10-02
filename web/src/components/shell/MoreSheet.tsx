"use client";

import Link from "next/link";
import { usePathname } from "next/navigation";
import { useTranslations } from "next-intl";
import { Icon } from "@/components/ds/Icon";
import { Modal } from "@/components/ds/overlay/Modal";
import type { NavItemDef } from "./navConfig";

export interface MoreSheetProps {
  open: boolean;
  onClose: () => void;
  items: NavItemDef[];
}

/**
 * The bottom nav's "Több" (D-W0.22) — a plain list of the remaining nav
 * items in `Modal`'s existing <768px sheet shape, so it's keyboard-operable
 * (focus trap, Esc, scrim close) for free rather than a bespoke overlay.
 */
export function MoreSheet({ open, onClose, items }: MoreSheetProps) {
  const t = useTranslations();
  const common = useTranslations("common");
  const pathname = usePathname();

  return (
    <Modal open={open} onClose={onClose} aria-label={common("more")}>
      <div className="px-2 pb-4">
        <h2 className="type-title-s px-4 pt-1 pb-3">{common("more")}</h2>
        <div className="flex flex-col">
          {items.map((item) => {
            const active = pathname.startsWith(item.href);
            return (
              <Link
                key={item.href}
                href={item.href}
                onClick={onClose}
                className="lifey-button flex items-center gap-3 px-4 rounded-[var(--r-control)]"
                style={{
                  height: 52,
                  background: active ? "var(--primary)" : "transparent",
                  color: active ? "var(--on-primary)" : "var(--text)",
                }}
              >
                <Icon name={item.icon} size={22} fill={active ? 1 : 0} />
                <span style={{ fontSize: 15, fontWeight: 600 }}>{t(`${item.namespace ?? "nav"}.${item.key}`)}</span>
              </Link>
            );
          })}
        </div>
      </div>
    </Modal>
  );
}
