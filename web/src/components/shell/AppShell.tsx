"use client";

import { useEffect, useState } from "react";
import { useQuery } from "@tanstack/react-query";
import { avatarApi } from "@/features/settings/api";
import { queryKeys } from "@/lib/api/queryKeys";
import { useSidebarState } from "@/lib/hooks/useSidebarState";
import { useMediaQuery } from "@/lib/hooks/useMediaQuery";
import type { SessionUser } from "@/features/auth/types";
import { Sidebar } from "./Sidebar";
import { TopBar } from "./TopBar";
import { MobileHeader } from "./MobileHeader";
import { BottomNav } from "./BottomNav";
import { MoreSheet } from "./MoreSheet";
import { CLIENT_BOTTOM_NAV_ITEMS, CLIENT_MORE_SHEET_ITEMS } from "./navConfig";

export interface AppShellProps {
  user: SessionUser;
  onLogout: () => void;
  children: React.ReactNode;
}

/**
 * The client chrome, route-driven per role (D-W0.14): `Sidebar` + `TopBar`
 * at >=768px, `MobileHeader` + `BottomNav` + `MoreSheet` below that
 * (D-W0.22) — not both at once, unlike W0.20/21's interim overlay drawer.
 */
export function AppShell({ user, onLogout, children }: AppShellProps) {
  const { collapsed, toggle } = useSidebarState();
  const isMobile = useMediaQuery("(max-width: 767px)");
  const [moreOpen, setMoreOpen] = useState(false);

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

  if (isMobile) {
    return (
      <div className="flex flex-col min-h-screen bg-bg">
        <MobileHeader user={user} avatarUrl={avatarUrl} onLogout={onLogout} />
        <main className="flex-1 p-4" style={{ paddingBottom: "calc(env(safe-area-inset-bottom) + 96px)" }}>
          {children}
        </main>
        <BottomNav items={CLIENT_BOTTOM_NAV_ITEMS} moreOpen={moreOpen} onMoreClick={() => setMoreOpen((v) => !v)} />
        <MoreSheet open={moreOpen} onClose={() => setMoreOpen(false)} items={CLIENT_MORE_SHEET_ITEMS} />
      </div>
    );
  }

  return (
    <div className="flex min-h-screen bg-bg">
      <Sidebar user={user} avatarUrl={avatarUrl} collapsed={collapsed} onToggleCollapsed={toggle} onLogout={onLogout} />
      <div className="flex flex-col flex-1 min-w-0">
        <TopBar />
        <main className="flex-1 p-6 overflow-auto">{children}</main>
      </div>
    </div>
  );
}
