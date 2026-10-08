"use client";

import { useCallback, useEffect, useMemo, useState, type ReactNode } from "react";
import { usePathname } from "next/navigation";
import { useQuery } from "@tanstack/react-query";
import { useTranslations } from "next-intl";
import { avatarApi } from "@/features/settings/api";
import { billingApi } from "@/features/billing/api";
import { queryKeys } from "@/lib/api/queryKeys";
import { useSidebarState } from "@/lib/hooks/useSidebarState";
import { useMediaQuery } from "@/lib/hooks/useMediaQuery";
import { useHotkeys } from "@/lib/hooks/useHotkeys";
import type { SessionUser } from "@/features/auth/types";
import type { TrainerPlan } from "@/features/billing/types";
import { Sidebar } from "./Sidebar";
import { TopBar } from "./TopBar";
import { MobileHeader } from "./MobileHeader";
import { BottomNav } from "./BottomNav";
import { MoreSheet } from "./MoreSheet";
import { ShortcutHelp } from "./ShortcutHelp";
import { routeChrome } from "./routeChrome";
import {
  clientGroupsFor,
  CLIENT_BOTTOM_NAV_ITEMS,
  CLIENT_MORE_SHEET_ITEMS,
  type NavGroup,
  type NavItemDef,
} from "./navConfig";

export interface AppShellProps {
  user: SessionUser;
  onLogout: () => void;
  children: ReactNode;
  /** Defaults to the client's own nav (D-W0.14: one shell, three roles). */
  groups?: NavGroup[];
  bottomNavItems?: NavItemDef[];
  moreSheetItems?: NavItemDef[];
  roleBadge?: { icon: string; label: string };
  roleRing?: "trainer" | "superadmin";
  showSettingsRow?: boolean;
  /** Adds the weekly-report-email switch to the account menu (D-W0.23). */
  trainerPrefs?: boolean;
  /** Rendered above `children` inside `<main>` — the trainer shell's `AdminBillingBanner` (D-W0.23). */
  extraContent?: ReactNode;
}

function planLabel(t: ReturnType<typeof useTranslations>, plan: TrainerPlan | null | undefined) {
  if (plan === "STARTER") return t("planStarter");
  if (plan === "PRO") return t("planPro");
  if (plan === "STUDIO") return t("planStudio");
  return null;
}

/**
 * The chrome, route-driven per role (D-W0.14): `Sidebar` + `TopBar` at
 * >=768px, `MobileHeader` + `BottomNav` + `MoreSheet` below that (D-W0.22).
 * The nav content and a handful of per-role trims (badge, avatar ring,
 * chip subtitle, the client's own dedicated Settings row, the trainer's
 * account-menu switch) are the only differences between the three route
 * groups (D-W0.23/24) — everything else is this one component.
 */
export function AppShell({
  user,
  onLogout,
  children,
  groups,
  bottomNavItems = CLIENT_BOTTOM_NAV_ITEMS,
  moreSheetItems = CLIENT_MORE_SHEET_ITEMS,
  roleBadge,
  roleRing,
  showSettingsRow = true,
  trainerPrefs,
  extraContent,
}: AppShellProps) {
  const { collapsed, toggle } = useSidebarState();
  const isMobile = useMediaQuery("(max-width: 767px)");
  const [moreOpen, setMoreOpen] = useState(false);
  const admin = useTranslations("admin");
  const billing = useTranslations("admin.billing");

  // Same query key `AdminBillingBanner`'s own `useEntitlements()` uses, so
  // this shares its cache rather than double-fetching — only gated here
  // (`useEntitlements` has no `enabled` param) so the client/superadmin
  // shells don't pick up a billing request they have no use for.
  const { data: entitlements } = useQuery({
    queryKey: queryKeys.billing.entitlements(),
    queryFn: billingApi.entitlements,
    staleTime: 60_000,
    enabled: roleRing === "trainer",
  });
  const chipSubtitle =
    roleRing === "trainer"
      ? [admin("chip"), planLabel(billing, entitlements?.trainer?.plan)].filter(Boolean).join(" · ")
      : undefined;

  const resolvedGroups = useMemo(() => groups ?? clientGroupsFor(user), [groups, user]);
  const goToItems = useMemo(() => resolvedGroups.flatMap((g) => g.items), [resolvedGroups]);
  const [helpOpen, setHelpOpen] = useState(false);
  const openHelp = useCallback(() => setHelpOpen(true), []);
  const focus = routeChrome(usePathname()).chrome === "focus";
  useHotkeys({ goToItems, onHelp: openHelp, suppressed: helpOpen || focus });

  const { data: avatarBlob } = useQuery({
    queryKey: queryKeys.settings.avatar(),
    queryFn: avatarApi.get,
    staleTime: 5 * 60 * 1000,
  });
  // Create and revoke the object URL together in one effect (not a useMemo
  // paired with a separate revoke-on-cleanup effect) — under React StrictMode
  // in dev, effects run mount→cleanup→mount, and a cleanup that isn't paired
  // with its own re-creation revokes the URL a still-mounted <img> is using,
  // breaking it with net::ERR_FILE_NOT_FOUND.
  const [avatarUrl, setAvatarUrl] = useState<string | null>(null);
  useEffect(() => {
    if (!avatarBlob) {
      // eslint-disable-next-line react-hooks/set-state-in-effect
      setAvatarUrl(null);
      return;
    }
    const url = URL.createObjectURL(avatarBlob);
    setAvatarUrl(url);
    return () => URL.revokeObjectURL(url);
  }, [avatarBlob]);

  // Focus mode (W3.6): the page owns the whole window — no sidebar, top bar, bottom nav or shortcut help.
  if (focus) {
    return (
      <div className="min-h-screen bg-bg">
        <main className="min-h-screen min-w-0">{children}</main>
      </div>
    );
  }

  if (isMobile) {
    return (
      <div className="flex flex-col min-h-screen bg-bg">
        <MobileHeader user={user} avatarUrl={avatarUrl} onLogout={onLogout} roleRing={roleRing} trainerPrefs={trainerPrefs} />
        {/* `overflow-x-auto`: a page whose own layout is still wider than 390px (several trainer/superadmin pages until their iteration) scrolls inside <main> instead of dragging the whole page and header sideways. */}
        <main className="flex-1 min-w-0 overflow-x-auto p-4" style={{ paddingBottom: "var(--app-bottom-clearance)" }}>
          {extraContent}
          {children}
        </main>
        <BottomNav
          items={bottomNavItems}
          moreOpen={moreOpen}
          onMoreClick={() => setMoreOpen((v) => !v)}
          showMore={moreSheetItems.length > 0}
        />
        {moreSheetItems.length > 0 && (
          <MoreSheet open={moreOpen} onClose={() => setMoreOpen(false)} items={moreSheetItems} />
        )}
        <ShortcutHelp open={helpOpen} onClose={() => setHelpOpen(false)} />
      </div>
    );
  }

  return (
    <div className="flex min-h-screen bg-bg">
      {/* Pinned to the viewport (not stretched to the page height) so the account chip at the foot stays on screen on long pages. */}
      <div className="sticky top-0 h-screen shrink-0">
        <Sidebar
          user={user}
          avatarUrl={avatarUrl}
          collapsed={collapsed}
          onToggleCollapsed={toggle}
          onLogout={onLogout}
          groups={resolvedGroups}
          roleBadge={roleBadge}
          roleRing={roleRing}
          chipSubtitle={chipSubtitle}
          showSettingsRow={showSettingsRow}
          trainerPrefs={trainerPrefs}
        />
      </div>
      <div className="flex flex-col flex-1 min-w-0">
        <TopBar />
        <main className="flex-1 p-6 overflow-auto">
          {extraContent}
          {children}
        </main>
      </div>
      <ShortcutHelp open={helpOpen} onClose={() => setHelpOpen(false)} />
    </div>
  );
}
