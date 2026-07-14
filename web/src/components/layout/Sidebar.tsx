"use client";

import Link from "next/link";
import { usePathname } from "next/navigation";
import { useTranslations } from "next-intl";
import { useQuery } from "@tanstack/react-query";
import { useSessionStore } from "@/features/auth/store";
import { useUiStore } from "@/lib/hooks/useUiStore";
import { useEffect, useState } from "react";
import { avatarApi } from "@/features/settings/api";
import { queryKeys } from "@/lib/api/queryKeys";

const NAV_ITEMS = [
  { href: "/dashboard", icon: "dashboard", key: "dashboard" },
  { href: "/nutrition", icon: "restaurant", key: "nutrition" },
  { href: "/workouts", icon: "fitness_center", key: "workouts" },
  { href: "/weight", icon: "monitor_weight", key: "weight" },
  { href: "/water", icon: "water_drop", key: "water" },
  { href: "/steps", icon: "directions_walk", key: "steps" },
  { href: "/statistics", icon: "bar_chart", key: "statistics" },
] as const;

export function Sidebar() {
  const t = useTranslations("nav");
  const common = useTranslations("common");
  const pathname = usePathname();
  const { user, logout } = useSessionStore();
  const { drawerOpen, closeDrawer } = useUiStore();
  const [collapsed, setCollapsed] = useState(false);

  const { data: avatarBlob } = useQuery({
    queryKey: queryKeys.settings.avatar(),
    queryFn: avatarApi.get,
    staleTime: 5 * 60 * 1000,
    enabled: !!user,
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

  // On mobile the rail-collapse is irrelevant — drawer is always full width.
  const width = collapsed ? 74 : 248;

  return (
    <>
      {/* Mobile backdrop */}
      {drawerOpen && (
        <div
          className="fixed inset-0 z-30 md:hidden"
          style={{ background: "rgba(0,0,0,.5)" }}
          onClick={closeDrawer}
          aria-hidden
        />
      )}

      <aside
        className={`fixed md:sticky top-0 z-40 flex flex-col shrink-0 h-screen transition-transform md:transition-all duration-[var(--dur-base)] ${
          drawerOpen ? "translate-x-0" : "-translate-x-full md:translate-x-0"
        }`}
        style={{
          width,
          background: "var(--surface-high)",
          borderRight: "1px solid var(--outline)",
          borderRadius: `0 var(--r-nav) var(--r-nav) 0`,
        }}
      >
        {/* Logo */}
        <div className="flex items-center gap-3 px-4 py-5">
          <span
            className="material-symbols-rounded text-2xl shrink-0"
            style={{ color: "var(--primary)", fontVariationSettings: "'FILL' 1" }}
          >
            eco
          </span>
          {!collapsed && <span className="font-bold text-lg tracking-tight">Lifey</span>}
          {/* Collapse toggle — desktop only */}
          <button
            onClick={() => setCollapsed((c) => !c)}
            className="ml-auto p-1 rounded-[var(--r-sm)] transition-colors hover:bg-surface-highest hidden md:block"
            style={{ color: "var(--on-surface-variant)" }}
            aria-label={collapsed ? common("expandSidebar") : common("collapseSidebar")}
          >
            <span className="material-symbols-rounded text-xl">
              {collapsed ? "chevron_right" : "chevron_left"}
            </span>
          </button>
          {/* Close drawer — mobile only */}
          <button
            onClick={closeDrawer}
            className="ml-auto p-1 rounded-[var(--r-sm)] transition-colors hover:bg-surface-highest md:hidden"
            style={{ color: "var(--on-surface-variant)" }}
            aria-label={common("closeMenu")}
          >
            <span className="material-symbols-rounded text-xl">close</span>
          </button>
        </div>

        {/* Nav */}
        <nav className="flex-1 flex flex-col gap-1 px-2">
          {NAV_ITEMS.map(({ href, icon, key }) => {
            const active = pathname.startsWith(href);
            const label = t(key);
            return (
              <Link
                key={href}
                href={href}
                onClick={closeDrawer}
                className="flex items-center gap-3 px-3 py-2.5 rounded-[var(--r-card)] transition-colors"
                style={{
                  background: active ? "var(--primary)" : "transparent",
                  color: active ? "#1E1F18" : "var(--on-surface-variant)",
                }}
                title={collapsed ? label : undefined}
              >
                <span
                  className="material-symbols-rounded text-xl shrink-0"
                  style={{ fontVariationSettings: active ? "'FILL' 1" : "'FILL' 0" }}
                >
                  {icon}
                </span>
                {!collapsed && <span className="text-sm font-semibold truncate">{label}</span>}
              </Link>
            );
          })}
        </nav>

        {/* Bottom: settings + user */}
        <div className="flex flex-col gap-1 px-2 pb-4">
          <Link
            href="/settings"
            onClick={closeDrawer}
            className="flex items-center gap-3 px-3 py-2.5 rounded-[var(--r-card)] transition-colors"
            style={{
              background: pathname.startsWith("/settings") ? "var(--primary)" : "transparent",
              color: pathname.startsWith("/settings") ? "#1E1F18" : "var(--on-surface-variant)",
            }}
            title={collapsed ? t("settings") : undefined}
          >
            <span
              className="material-symbols-rounded text-xl shrink-0"
              style={{ fontVariationSettings: pathname.startsWith("/settings") ? "'FILL' 1" : "'FILL' 0" }}
            >
              settings
            </span>
            {!collapsed && <span className="text-sm font-semibold">{t("settings")}</span>}
          </Link>

          {user?.roles.includes("ROLE_TRAINER") && (
            <Link
              href="/admin"
              onClick={closeDrawer}
              className="flex items-center gap-3 px-3 py-2.5 rounded-[var(--r-card)] transition-colors"
              style={{ color: "var(--tertiary)" }}
              title={collapsed ? t("trainerView") : undefined}
            >
              <span className="material-symbols-rounded text-xl shrink-0">fitness_center</span>
              {!collapsed && <span className="text-sm font-semibold">{t("trainerView")}</span>}
            </Link>
          )}

          {user?.roles.includes("ROLE_SUPER_ADMIN") && (
            <Link
              href="/superadmin/users"
              onClick={closeDrawer}
              className="flex items-center gap-3 px-3 py-2.5 rounded-[var(--r-card)] transition-colors"
              style={{ color: "var(--on-surface-variant)" }}
              title={collapsed ? t("systemView") : undefined}
            >
              <span className="material-symbols-rounded text-xl shrink-0">admin_panel_settings</span>
              {!collapsed && <span className="text-sm font-semibold">{t("systemView")}</span>}
            </Link>
          )}

          {!collapsed && user && (
            <div
              className="mt-2 flex items-center gap-3 px-3 py-2 rounded-[var(--r-card)]"
              style={{ background: "var(--surface-container)" }}
            >
              <div
                className="w-8 h-8 rounded-full flex items-center justify-center text-sm font-bold shrink-0 overflow-hidden"
                style={{ background: "var(--primary)", color: "#1E1F18" }}
              >
                {avatarUrl ? (
                  // Blob object URLs aren't compatible with next/image's optimizer.
                  // eslint-disable-next-line @next/next/no-img-element
                  <img src={avatarUrl} alt="" className="w-full h-full object-cover" />
                ) : (
                  user.email.charAt(0).toUpperCase()
                )}
              </div>
              <div className="flex-1 min-w-0">
                <p className="text-sm font-semibold truncate">
                  {user.firstName && user.lastName
                    ? `${user.firstName} ${user.lastName}`
                    : user.email.split("@")[0]}
                </p>
                <p className="text-xs truncate" style={{ color: "var(--muted)" }}>{user.email}</p>
              </div>
              <button
                onClick={logout}
                className="p-1 rounded-[var(--r-sm)] transition-colors"
                style={{ color: "var(--on-surface-variant)" }}
                aria-label={common("signOut")}
                title={common("signOut")}
              >
                <span className="material-symbols-rounded text-xl">logout</span>
              </button>
            </div>
          )}
        </div>
      </aside>
    </>
  );
}
