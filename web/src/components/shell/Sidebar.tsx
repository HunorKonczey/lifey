"use client";

import { useRef, useState } from "react";
import { usePathname } from "next/navigation";
import { useTranslations } from "next-intl";
import { Icon } from "@/components/ds/Icon";
import { useMediaQuery } from "@/lib/hooks/useMediaQuery";
import { useUiStore } from "@/lib/hooks/useUiStore";
import type { SessionUser } from "@/features/auth/types";
import { CLIENT_NAV_ITEMS, SETTINGS_NAV_ITEM } from "./navConfig";
import { SidebarItem } from "./SidebarItem";
import { AccountMenu } from "./AccountMenu";

export interface SidebarProps {
  user: SessionUser;
  avatarUrl: string | null;
  collapsed: boolean;
  onToggleCollapsed: () => void;
  onLogout: () => void;
}

const OPEN_WIDTH = 248;
const COLLAPSED_WIDTH = 76;

function displayName(user: SessionUser) {
  return user.firstName && user.lastName ? `${user.firstName} ${user.lastName}` : user.email.split("@")[0];
}

/**
 * DS-02's floating client sidebar (D-W0.20): a 12px-inset panel, the nav
 * list, role-gated trainer/superadmin jump links (preserved from the old
 * `components/layout/Sidebar.tsx`, not itself in the DS-02 canvas), and the
 * user chip opening `AccountMenu`. Below 768px this renders as the same
 * full-height overlay drawer the old sidebar used — the bottom nav that
 * properly replaces it on mobile is W0.22, not yet built.
 */
export function Sidebar({ user, avatarUrl, collapsed, onToggleCollapsed, onLogout }: SidebarProps) {
  const t = useTranslations("nav");
  const common = useTranslations("common");
  const pathname = usePathname();
  const isMobile = useMediaQuery("(max-width: 767px)");
  const { drawerOpen, closeDrawer } = useUiStore();
  const chipRef = useRef<HTMLButtonElement>(null);
  const [menuOpen, setMenuOpen] = useState(false);

  const effectiveCollapsed = collapsed && !isMobile;
  const width = isMobile ? OPEN_WIDTH : effectiveCollapsed ? COLLAPSED_WIDTH : OPEN_WIDTH;

  const panel = (
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
      <div className="flex items-center gap-3 mb-4" style={{ height: 36 }}>
        <span
          className="inline-flex items-center justify-center shrink-0"
          style={{ width: 36, height: 36, borderRadius: "var(--r-control)", background: "var(--primary)" }}
        >
          <Icon name="eco" size={20} color="var(--on-primary)" fill={1} />
        </span>
        {!effectiveCollapsed && (
          <span style={{ fontSize: 20, fontWeight: 800, letterSpacing: "-0.01em" }}>Lifey</span>
        )}
        {!isMobile && !effectiveCollapsed && (
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
        {isMobile && (
          <button
            type="button"
            onClick={closeDrawer}
            aria-label={common("closeMenu")}
            className="lifey-button ml-auto inline-flex items-center justify-center rounded-[var(--r-control)]"
            style={{ width: 32, height: 32, color: "var(--text-2)" }}
          >
            <Icon name="close" size={20} />
          </button>
        )}
      </div>

      {effectiveCollapsed && (
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
      <nav className="flex-1 flex flex-col gap-1 overflow-y-auto" aria-label={t("mainNavigation")}>
        {CLIENT_NAV_ITEMS.map((item) => (
          <SidebarItem
            key={item.href}
            item={item}
            label={t(item.key)}
            active={pathname.startsWith(item.href)}
            collapsed={effectiveCollapsed}
            onClick={isMobile ? closeDrawer : undefined}
          />
        ))}

        {user.roles.includes("ROLE_TRAINER") && (
          <SidebarItem
            item={{ href: "/admin", key: "trainerView", icon: "storefront", shortcut: "T" }}
            label={t("trainerView")}
            active={pathname.startsWith("/admin")}
            collapsed={effectiveCollapsed}
            onClick={isMobile ? closeDrawer : undefined}
          />
        )}
        {user.roles.includes("ROLE_SUPER_ADMIN") && (
          <SidebarItem
            item={{ href: "/superadmin/users", key: "systemView", icon: "admin_panel_settings", shortcut: "Y" }}
            label={t("systemView")}
            active={pathname.startsWith("/superadmin")}
            collapsed={effectiveCollapsed}
            onClick={isMobile ? closeDrawer : undefined}
          />
        )}
      </nav>

      <div className="my-2" style={{ borderTop: "1px solid var(--hairline)" }} />

      <SidebarItem
        item={SETTINGS_NAV_ITEM}
        label={t("settings")}
        active={pathname.startsWith("/settings")}
        collapsed={effectiveCollapsed}
        onClick={isMobile ? closeDrawer : undefined}
      />

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
          padding: effectiveCollapsed ? 0 : "0 8px",
          justifyContent: effectiveCollapsed ? "center" : "flex-start",
          background: "var(--nested)",
        }}
      >
        <span
          className="inline-flex items-center justify-center rounded-full shrink-0 overflow-hidden"
          style={{ width: 36, height: 36, background: "var(--primary)", color: "var(--on-primary)", fontSize: 14, fontWeight: 700 }}
        >
          {avatarUrl ? (
            // Blob object URLs aren't compatible with next/image's optimizer.
            // eslint-disable-next-line @next/next/no-img-element
            <img src={avatarUrl} alt="" className="w-full h-full object-cover" />
          ) : (
            user.email.charAt(0).toUpperCase()
          )}
        </span>
        {!effectiveCollapsed && (
          <>
            <span className="flex-1 min-w-0 text-left">
              <span className="block truncate" style={{ fontSize: 14, fontWeight: 700 }}>
                {displayName(user)}
              </span>
              <span className="block truncate" style={{ fontSize: 12, fontWeight: 500, color: "var(--text-3)" }}>
                {user.email}
              </span>
            </span>
            <Icon name="unfold_more" size={18} color="var(--text-3)" />
          </>
        )}
      </button>

      <AccountMenu open={menuOpen} onClose={() => setMenuOpen(false)} anchorRef={chipRef} onLogout={onLogout} />
    </div>
  );

  if (isMobile) {
    return (
      <>
        {drawerOpen && (
          <div
            className="fixed inset-0 z-30"
            style={{ background: "rgba(0,0,0,.5)" }}
            onClick={closeDrawer}
            aria-hidden
          />
        )}
        <aside
          className="fixed top-0 left-0 z-40 h-screen transition-transform"
          style={{
            transitionDuration: "var(--dur-base)",
            transform: drawerOpen ? "translateX(0)" : "translateX(-100%)",
            padding: 12,
          }}
          // Off-canvas but still in the DOM for the slide transition — hidden
          // from the accessibility tree and unreachable by Tab/name queries
          // while closed, not just visually offset.
          aria-hidden={!drawerOpen}
          inert={!drawerOpen ? true : undefined}
        >
          {panel}
        </aside>
      </>
    );
  }

  return (
    <aside className="sticky top-0 self-stretch shrink-0" style={{ padding: 12, width: width + 24 }}>
      {panel}
    </aside>
  );
}
