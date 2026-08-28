"use client";

import Link from "next/link";
import { usePathname } from "next/navigation";
import { useTranslations } from "next-intl";
import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";
import { useSessionStore } from "@/features/auth/store";
import { useUiStore } from "@/lib/hooks/useUiStore";
import { useEffect, useState } from "react";
import { avatarApi } from "@/features/settings/api";
import { trainerApi } from "@/features/trainer/api";
import { queryKeys } from "@/lib/api/queryKeys";
import { useToast } from "@/lib/hooks/useToast";
import { Switch } from "@/components/ui/Switch";
import { useUnreadTotal } from "@/features/chat/hooks";
import { unreadBadgeLabel } from "@/features/chat/thread";

const NAV_ITEMS = [
  { href: "/admin", icon: "group", key: "clients" },
  { href: "/admin/calendar", icon: "calendar_month", key: "calendar" },
  { href: "/admin/chat", icon: "chat_bubble", key: "chat" },
  { href: "/admin/invites", icon: "mail", key: "invites" },
  { href: "/admin/billing", icon: "credit_card", key: "billing" },
  { href: "/admin/workouts", icon: "fitness_center", key: "workouts" },
  { href: "/admin/programs", icon: "event_repeat", key: "programs" },
  { href: "/admin/nutrition", icon: "restaurant", key: "nutrition" },
  { href: "/admin/assignments", icon: "assignment", key: "assignments" },
] as const;

export function AdminSidebar() {
  const admin = useTranslations("admin");
  const t = useTranslations("admin.nav");
  const prefs = useTranslations("admin.preferences");
  const chat = useTranslations("chat");
  const common = useTranslations("common");
  const pathname = usePathname();
  const { user, logout } = useSessionStore();
  const { drawerOpen, closeDrawer } = useUiStore();
  const [collapsed, setCollapsed] = useState(false);
  const queryClient = useQueryClient();
  const { show } = useToast();
  const unread = useUnreadTotal();

  const { data: preferences } = useQuery({
    queryKey: queryKeys.trainerPreferences.all(),
    queryFn: trainerApi.preferences,
    staleTime: 5 * 60 * 1000,
    enabled: !!user,
  });

  const updatePreferences = useMutation({
    mutationFn: (weeklyReportEmailEnabled: boolean) =>
      trainerApi.updatePreferences({ weeklyReportEmailEnabled }),
    onSuccess: (data) => {
      queryClient.setQueryData(queryKeys.trainerPreferences.all(), data);
      show(prefs("updated"), "success");
    },
    onError: () => show(prefs("updateFailed"), "error"),
  });

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

  const width = collapsed ? 78 : 248;

  return (
    <>
      {drawerOpen && (
        <div
          className="fixed inset-0 z-30 md:hidden"
          style={{ background: "rgba(8,9,6,.6)" }}
          onClick={closeDrawer}
          aria-hidden
        />
      )}

      <aside
        className={`fixed md:sticky top-0 z-40 flex flex-col shrink-0 h-screen md:h-[calc(100vh-28px)] md:my-[14px] md:ml-[14px] transition-transform md:transition-all duration-[var(--dur-base)] ${
          drawerOpen ? "translate-x-0" : "-translate-x-full md:translate-x-0"
        }`}
        style={{ width, background: "var(--surface-high)", borderRadius: "var(--r-lg)", padding: "20px 14px" }}
      >
        {/* Logo + EDZŐ chip */}
        <div className="flex items-center gap-2.5 px-2 pb-[22px]">
          <div
            className="w-[38px] h-[38px] rounded-xl flex items-center justify-center shrink-0"
            style={{ background: "var(--primary)", color: "#161611" }}
          >
            <span className="material-symbols-rounded text-2xl" style={{ fontVariationSettings: "'FILL' 1" }}>
              eco
            </span>
          </div>
          {!collapsed && (
            <>
              <span className="font-extrabold text-lg tracking-tight" style={{ color: "var(--on-surface)" }}>
                Lifey
              </span>
              <span
                className="flex items-center gap-1 rounded-[var(--r-pill)] text-[10px] font-extrabold tracking-wide px-2.5 py-1"
                style={{ background: "var(--tertiary)", color: "#161611" }}
              >
                <span className="material-symbols-rounded text-[13px]" style={{ fontVariationSettings: "'FILL' 1" }}>
                  fitness_center
                </span>
                {admin("chip")}
              </span>
            </>
          )}
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
          <button
            onClick={closeDrawer}
            className="ml-auto p-1 rounded-[var(--r-sm)] transition-colors hover:bg-surface-highest md:hidden"
            style={{ color: "var(--on-surface-variant)" }}
            aria-label={common("closeMenu")}
          >
            <span className="material-symbols-rounded text-xl">close</span>
          </button>
        </div>

        <nav className="flex flex-col gap-[3px]">
          {NAV_ITEMS.map(({ href, icon, key }) => {
            const active = href === "/admin" ? pathname === href : pathname.startsWith(href);
            const label = t(key);
            // Web push is out of the first chat release, so this badge and the
            // tab title are the trainer's only ambient unread signal (§6.2).
            const badge = key === "chat" && unread > 0 ? unreadBadgeLabel(unread) : null;
            return (
              <Link
                key={href}
                href={href}
                onClick={closeDrawer}
                className="flex items-center gap-[13px] px-3.5 py-[11px] rounded-[14px] transition-colors relative"
                style={{
                  background: active ? "var(--tertiary)" : "transparent",
                  color: active ? "#161611" : "var(--on-surface-variant)",
                }}
                title={collapsed ? label : undefined}
              >
                <span
                  className="material-symbols-rounded text-[22px] shrink-0"
                  style={{ fontVariationSettings: active ? "'FILL' 1" : "'FILL' 0" }}
                >
                  {icon}
                </span>
                {!collapsed && <span className="text-sm font-semibold truncate">{label}</span>}
                {badge &&
                  (collapsed ? (
                    <span
                      className="absolute top-1.5 right-2 w-2 h-2 rounded-full"
                      style={{ background: active ? "#161611" : "var(--primary)" }}
                      aria-label={chat("unreadCount", { count: unread })}
                    />
                  ) : (
                    <span
                      className="ml-auto min-w-[20px] h-5 rounded-[10px] px-1.5 flex items-center justify-center text-[11px] font-extrabold"
                      style={{
                        background: active ? "#161611" : "var(--primary)",
                        color: active ? "var(--on-surface)" : "#161611",
                      }}
                      aria-label={chat("unreadCount", { count: unread })}
                    >
                      {badge}
                    </span>
                  ))}
              </Link>
            );
          })}
        </nav>

        <div className="mt-auto flex flex-col gap-[3px]">
          <div className="h-px mx-2 mb-2.5" style={{ background: "var(--outline)" }} />
          <Link
            href="/dashboard"
            onClick={closeDrawer}
            className="flex items-center gap-[13px] px-3.5 py-[11px] rounded-[14px] transition-colors"
            style={{ color: "var(--on-surface-variant)" }}
            title={collapsed ? t("backToOwnView") : undefined}
          >
            <span className="material-symbols-rounded text-[22px] shrink-0">undo</span>
            {!collapsed && <span className="text-sm font-semibold">{t("backToOwnView")}</span>}
          </Link>

          {!collapsed && user && preferences && (
            <div className="px-3 py-1.5">
              <Switch
                checked={preferences.weeklyReportEmailEnabled}
                onChange={(checked) => updatePreferences.mutate(checked)}
                label={prefs("weeklyReportEmailLabel")}
              />
            </div>
          )}

          {!collapsed && user && (
            <div
              className="mt-2 flex items-center gap-[11px] rounded-[14px] px-3 py-2.5"
              style={{ background: "var(--bg)" }}
            >
              <div
                className="w-[34px] h-[34px] rounded-full flex items-center justify-center text-sm font-extrabold shrink-0 overflow-hidden"
                style={{ background: "var(--tertiary)", color: "#161611" }}
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
                <p className="text-[13px] font-bold truncate" style={{ color: "var(--on-surface)" }}>
                  {user.email.split("@")[0]}
                </p>
                <p className="text-[11px]" style={{ color: "var(--on-surface-variant)" }}>
                  {admin("chip")}
                </p>
              </div>
              <button
                onClick={logout}
                className="p-1 rounded-[var(--r-sm)] transition-colors shrink-0"
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
