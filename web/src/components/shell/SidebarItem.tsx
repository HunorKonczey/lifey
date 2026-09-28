"use client";

import Link from "next/link";
import { Icon } from "@/components/ds/Icon";
import { Tooltip } from "@/components/ds/Tooltip";
import type { NavItemDef } from "./navConfig";

export interface SidebarItemProps {
  item: NavItemDef;
  label: string;
  active: boolean;
  collapsed: boolean;
  onClick?: () => void;
  /** An unread-style pill (e.g. chat's count) — a dot when collapsed. */
  badge?: string | null;
  badgeLabel?: string;
}

/**
 * DS-02's nav row: 44px, r14, icon + 15/600 label, gap 12; active = filled
 * primary pill with a FILL-1 icon and 15/700 label; hover `--nested` 120ms.
 * Collapsed to a 48x44 icon-only tile with a label+shortcut tooltip.
 */
export function SidebarItem({ item, label, active, collapsed, onClick, badge, badgeLabel }: SidebarItemProps) {
  const link = (
    <Link
      href={item.href}
      onClick={onClick}
      aria-label={collapsed ? label : undefined}
      className="relative flex items-center shrink-0 transition-colors"
      style={{
        height: 44,
        width: collapsed ? 48 : "100%",
        justifyContent: collapsed ? "center" : "flex-start",
        gap: 12,
        padding: collapsed ? 0 : "0 12px",
        borderRadius: "var(--r-control)",
        background: active ? "var(--primary)" : "transparent",
        color: active ? "var(--on-primary)" : "var(--text-2)",
        transitionDuration: "var(--dur-hover)",
      }}
      onMouseEnter={(e) => {
        if (!active) e.currentTarget.style.background = "var(--nested)";
      }}
      onMouseLeave={(e) => {
        if (!active) e.currentTarget.style.background = "transparent";
      }}
    >
      <Icon name={item.icon} size={22} fill={active ? 1 : 0} />
      {!collapsed && (
        <span className="flex-1 truncate" style={{ fontSize: 15, fontWeight: active ? 700 : 600 }}>
          {label}
        </span>
      )}
      {badge &&
        (collapsed ? (
          <span
            className="absolute top-1.5 right-1.5 w-2 h-2 rounded-full"
            style={{ background: active ? "var(--on-primary)" : "var(--heart)" }}
            aria-label={badgeLabel}
          />
        ) : (
          <span
            className="min-w-[20px] h-5 rounded-[var(--r-pill)] px-1.5 flex items-center justify-center shrink-0"
            style={{
              fontSize: 11,
              fontWeight: 800,
              background: active ? "var(--on-primary)" : "var(--heart)",
              color: active ? "var(--primary)" : "var(--on-primary)",
            }}
            aria-label={badgeLabel}
          >
            {badge}
          </span>
        ))}
    </Link>
  );

  if (!collapsed) return link;
  return (
    <Tooltip label={label} shortcut={`G ${item.shortcut}`}>
      {link}
    </Tooltip>
  );
}
