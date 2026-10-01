"use client";

import { useRef, useState } from "react";
import { usePathname } from "next/navigation";
import { useTranslations } from "next-intl";
import { useQuery } from "@tanstack/react-query";
import { Icon } from "@/components/ds/Icon";
import { Avatar } from "@/components/ds/Avatar";
import { useUnreadTotal } from "@/features/chat/hooks";
import { unreadBadgeLabel } from "@/features/chat/thread";
import { trainerRequestApi } from "@/features/trainer-requests/api";
import { queryKeys } from "@/lib/api/queryKeys";
import type { SessionUser } from "@/features/auth/types";
import type { NavGroup } from "./navConfig";
import { SETTINGS_NAV_ITEM } from "./navConfig";
import { SidebarItem } from "./SidebarItem";
import { AccountMenu } from "./AccountMenu";

export interface SidebarProps {
  user: SessionUser;
  avatarUrl: string | null;
  collapsed: boolean;
  onToggleCollapsed: () => void;
  onLogout: () => void;
  /** DS-02's nav content, one shell shared by every role (D-W0.14) — a flat
   *  single group for the client, three labelled groups for the trainer. */
  groups: NavGroup[];
  /** A clay/neutral pill under the logo — "EDZŐ"/"RENDSZER" (D-W0.23/24). */
  roleBadge?: { icon: string; label: string };
  /** Clay ring for the trainer avatar, neutral for superadmin (D-W0.23/24). */
  roleRing?: "trainer" | "superadmin";
  /** Replaces the e-mail line under the user's name ("Edző · Pro" etc). */
  chipSubtitle?: string;
  /** The client's own dedicated bottom row — trainer/superadmin reach
   *  Settings through the (now shared) account menu instead. Default true. */
  showSettingsRow?: boolean;
  /** Adds the weekly-report-email switch to the account menu (D-W0.23). */
  trainerPrefs?: boolean;
}

function displayName(user: SessionUser) {
  return user.firstName && user.lastName ? `${user.firstName} ${user.lastName}` : user.email.split("@")[0];
}

/**
 * DS-02's floating sidebar (D-W0.20/23/24): a 12px-inset panel, grouped nav,
 * an optional role badge, and the user chip opening `AccountMenu`.
 * Desktop-only (>=768px) — `AppShell` renders `MobileHeader` + `BottomNav`
 * below that (D-W0.22).
 */
export function Sidebar({
  user,
  avatarUrl,
  collapsed,
  onToggleCollapsed,
  onLogout,
  groups,
  roleBadge,
  roleRing,
  chipSubtitle,
  showSettingsRow = true,
  trainerPrefs,
}: SidebarProps) {
  const t = useTranslations();
  const nav = useTranslations("nav");
  const common = useTranslations("common");
  const pathname = usePathname();
  const chipRef = useRef<HTMLButtonElement>(null);
  const [menuOpen, setMenuOpen] = useState(false);
  // Cheap when 0 (client groups never contain a "chat" item, so it's simply unused there).
  const unread = useUnreadTotal();
  const hasRequestsItem = groups.some((g) => g.items.some((i) => i.key === "trainerRequestsTitle"));
  const { data: pendingRequests } = useQuery({
    queryKey: queryKeys.trainerRequests.pending({ page: 0, size: 1 }),
    queryFn: () => trainerRequestApi.pending({ page: 0, size: 1 }),
    enabled: hasRequestsItem,
    staleTime: 60_000,
  });

  const width = collapsed ? 76 : 248;

  return (
    <aside className="h-full shrink-0" style={{ padding: 12, width: width + 24 }}>
      <div
        className="flex flex-col h-full overflow-hidden"
        style={{
          width,
          background: "var(--card)",
          borderRadius: "var(--r-card)",
          boxShadow: "var(--e2), var(--edge-card)",
          padding: 16,
        }}
      >
        {/* Logo row */}
        <div className="flex items-center gap-3" style={{ height: 36 }}>
          <span
            className="inline-flex items-center justify-center shrink-0"
            style={{ width: 36, height: 36, borderRadius: "var(--r-control)", background: "var(--primary)" }}
          >
            <Icon name="eco" size={20} color="var(--on-primary)" fill={1} />
          </span>
          {!collapsed && <span style={{ fontSize: 20, fontWeight: 800, letterSpacing: "-0.01em" }}>Lifey</span>}
          {!collapsed && (
            <button
              type="button"
              onClick={onToggleCollapsed}
              aria-label={common("collapseSidebar")}
              className="lifey-button ml-auto inline-flex items-center justify-center rounded-[var(--r-control)]"
              style={{ width: 32, height: 32, color: "var(--text-2)" }}
            >
              <Icon name="left_panel_close" size={20} />
            </button>
          )}
        </div>

        {roleBadge && !collapsed && (
          <span
            className="inline-flex items-center gap-1 self-start mt-3 rounded-[var(--r-pill)] px-2.5 py-1"
            style={
              roleRing === "trainer"
                ? { background: "var(--role)", color: "var(--bg)", fontSize: 10, fontWeight: 800, letterSpacing: "0.02em" }
                : {
                    boxShadow: "inset 0 0 0 1.5px var(--outline)",
                    color: "var(--text-2)",
                    fontSize: 10,
                    fontWeight: 800,
                    letterSpacing: "0.02em",
                  }
            }
          >
            <Icon name={roleBadge.icon} size={13} fill={1} color={roleRing === "trainer" ? "var(--bg)" : "var(--text-2)"} />
            {roleBadge.label}
          </span>
        )}

        <div className={collapsed ? "mt-2" : "mt-4"} />

        {collapsed && (
          <button
            type="button"
            onClick={onToggleCollapsed}
            aria-label={common("expandSidebar")}
            className="lifey-button mb-2 inline-flex items-center justify-center rounded-[var(--r-control)] self-center"
            style={{ width: 48, height: 32, color: "var(--text-2)" }}
          >
            <Icon name="left_panel_open" size={20} />
          </button>
        )}

        {/* Nav */}
        <nav className="flex-1 flex flex-col gap-4 overflow-y-auto" aria-label={nav("mainNavigation")}>
          {groups.map((group, i) => (
            <div key={group.label ?? i} className="flex flex-col gap-1">
              {group.label && !collapsed && (
                <p className="type-label px-3 mb-0.5" style={{ color: "var(--text-3)" }}>
                  {t(group.label)}
                </p>
              )}
              {group.items.map((item) => {
                const isChat = item.key === "chat";
                const isRequests = item.key === "trainerRequestsTitle";
                const requestCount = pendingRequests?.totalElements ?? 0;
                const badge = isChat && unread > 0 ? unreadBadgeLabel(unread) : isRequests && requestCount > 0 ? String(requestCount) : null;
                const badgeLabel = isChat
                  ? t("chat.unreadCount", { count: unread })
                  : isRequests
                    ? t("superadmin.pendingRequestsBadge", { count: requestCount })
                    : undefined;
                return (
                  <SidebarItem
                    key={item.href}
                    item={item}
                    label={t(`${item.namespace ?? "nav"}.${item.key}`)}
                    active={item.href === "/admin" ? pathname === item.href : pathname.startsWith(item.href)}
                    collapsed={collapsed}
                    badge={badge}
                    badgeLabel={badgeLabel}
                  />
                );
              })}
            </div>
          ))}
        </nav>

        {showSettingsRow && (
          <>
            <div className="my-2" style={{ borderTop: "1px solid var(--hairline)" }} />
            <SidebarItem
              item={SETTINGS_NAV_ITEM}
              label={nav("settings")}
              active={pathname.startsWith("/settings")}
              collapsed={collapsed}
            />
          </>
        )}

        {/* User chip → account menu */}
        <button
          ref={chipRef}
          type="button"
          onClick={() => setMenuOpen((v) => !v)}
          aria-haspopup="menu"
          aria-expanded={menuOpen}
          className="lifey-button mt-2 flex items-center gap-2.5 rounded-[var(--r-control)]"
          style={{
            height: 52,
            padding: collapsed ? 0 : "0 8px",
            justifyContent: collapsed ? "center" : "flex-start",
            background: "var(--nested)",
          }}
        >
          <Avatar
            name={displayName(user)}
            email={user.email}
            src={avatarUrl ?? undefined}
            roleRing={roleRing}
            size={36}
          />
          {!collapsed && (
            <>
              <span className="flex-1 min-w-0 text-left">
                <span className="block truncate" style={{ fontSize: 14, fontWeight: 700 }}>
                  {displayName(user)}
                </span>
                <span className="block truncate" style={{ fontSize: 12, fontWeight: 500, color: "var(--text-3)" }}>
                  {chipSubtitle ?? user.email}
                </span>
              </span>
              <Icon name="unfold_more" size={18} color="var(--text-3)" />
            </>
          )}
        </button>

        <AccountMenu open={menuOpen} onClose={() => setMenuOpen(false)} anchorRef={chipRef} onLogout={onLogout} trainerPrefs={trainerPrefs} />
      </div>
    </aside>
  );
}
