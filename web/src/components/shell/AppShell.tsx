"use client";

import { useEffect, useState } from "react";
import { useQuery } from "@tanstack/react-query";
import { avatarApi } from "@/features/settings/api";
import { queryKeys } from "@/lib/api/queryKeys";
import { TopBar } from "@/components/layout/TopBar";
import { useSidebarState } from "@/lib/hooks/useSidebarState";
import type { SessionUser } from "@/features/auth/types";
import { Sidebar } from "./Sidebar";

export interface AppShellProps {
  user: SessionUser;
  onLogout: () => void;
  children: React.ReactNode;
}

/**
 * The client chrome (D-W0.20): the new floating `Sidebar` + the still-old
 * `TopBar` (its own redesign is W0.21) around the page content. Reserves
 * room for the sidebar's fixed floating panel via the content wrapper's own
 * left padding, matching whatever width the rail currently has.
 */
export function AppShell({ user, onLogout, children }: AppShellProps) {
  const { collapsed, toggle } = useSidebarState();

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
