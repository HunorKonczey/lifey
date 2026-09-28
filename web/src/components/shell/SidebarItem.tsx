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
}

/**
 * DS-02's nav row: 44px, r14, icon + 15/600 label, gap 12; active = filled
 * primary pill with a FILL-1 icon and 15/700 label; hover `--nested` 120ms.
 * Collapsed to a 48x44 icon-only tile with a label+shortcut tooltip.
 */
export function SidebarItem({ item, label, active, collapsed, onClick }: SidebarItemProps) {
  const link = (
    <Link
      href={item.href}
      onClick={onClick}
      aria-label={collapsed ? label : undefined}
      className="flex items-center shrink-0 transition-colors"
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
        <span className="truncate" style={{ fontSize: 15, fontWeight: active ? 700 : 600 }}>
          {label}
        </span>
      )}
    </Link>
  );

  if (!collapsed) return link;
  return (
    <Tooltip label={label} shortcut={`G ${item.shortcut}`}>
      {link}
    </Tooltip>
  );
}
