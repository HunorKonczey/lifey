"use client";

import { useState, type ReactNode } from "react";
import { useQuery } from "@tanstack/react-query";
import { useTranslations } from "next-intl";
import { Avatar, Button, Icon, Modal } from "@/components/ds";
import { LogoutDialog } from "@/components/shell/LogoutDialog";
import { userDetailsApi } from "@/features/onboarding/api";
import { useSessionStore } from "@/features/auth/store";
import { queryKeys } from "@/lib/api/queryKeys";
import { useFormat } from "@/lib/format/useFormat";
import { ChangePasswordDrawer } from "./ChangePasswordDrawer";
import { GoalsDrawer } from "./GoalsDrawer";
import { ProfileDrawer } from "./ProfileDrawer";
import { SettingsBareContext } from "./SettingsSection";
import { AppearanceSection } from "./sections/AppearanceSection";
import { useGoalDefs } from "./sections/GoalsSection";
import { NotificationsSection } from "./sections/NotificationsSection";
import { LogoutAllConfirm } from "./sections/SecuritySection";
import { useSettings } from "../useSettings";
import type { SettingsResponse } from "../types";

type Open = "profile" | "goals" | "theme" | "language" | "units" | "notifications" | "password" | "logoutAll" | "logout" | null;

/**
 * Settings on a phone (W6-H, `client-084`: never two columns): the profile row, then one list row per area — icon,
 * label, the current value, a chevron — and "Kijelentkezés…" at the bottom. A tap opens that area as a bottom sheet
 * (the DS `Modal` is a sheet under 768 px); the three that already are drawers — profile, goals, password — open as
 * the full-height sheet directly instead of nesting a sheet in a sheet.
 */
export function SettingsMobileList({ settings }: { settings: SettingsResponse }) {
  const t = useTranslations("settings");
  const fmt = useFormat();
  const { user, logout } = useSessionStore();
  const { save, saving } = useSettings();
  const goals = useGoalDefs();
  const [open, setOpen] = useState<Open>(null);
  const close = () => setOpen(null);

  const { data: details } = useQuery({ queryKey: queryKeys.userDetails.all(), queryFn: userDetailsApi.get, retry: false });

  const name = user?.firstName && user?.lastName ? `${user.firstName} ${user.lastName}` : (user?.email ?? "—");
  const quietOn = !!settings.chatQuietHoursStart && !!settings.chatQuietHoursEnd;
  const notificationsOn = (settings.chatPushEnabled ?? true ? 1 : 0) + (quietOn ? 1 : 0);
  const calorie = settings.dailyCalorieGoal;

  const rows: { key: Exclude<Open, null>; icon: string; label: string; value?: string }[] = [
    { key: "goals", icon: "target", label: t("dailyGoals"), value: calorie == null ? undefined : `${fmt.number(calorie, 0)} kcal` },
    { key: "theme", icon: "palette", label: t("theme"), value: t(settings.theme === "DARK" ? "dark" : settings.theme === "LIGHT" ? "light" : "system") },
    { key: "language", icon: "translate", label: t("language"), value: t(settings.language === "HUNGARIAN" ? "hungarian" : settings.language === "ENGLISH" ? "english" : "system") },
    { key: "units", icon: "straighten", label: t("units"), value: settings.unitSystem === "METRIC" ? "kg · L" : "lb · fl oz" },
    { key: "notifications", icon: "notifications", label: t("notifications"), value: t("notificationsOn", { n: notificationsOn }) },
    { key: "password", icon: "shield", label: t("security") },
    { key: "logoutAll", icon: "devices", label: t("logoutAll") },
  ];

  const sheet = (node: ReactNode, label: string) => (
    <Modal open onClose={close} aria-label={label}>
      <SettingsBareContext.Provider value>
        <div className="flex flex-col gap-5 p-5">{node}</div>
      </SettingsBareContext.Provider>
    </Modal>
  );

  return (
    <div className="flex flex-col gap-4">
      <button
        type="button"
        onClick={() => setOpen("profile")}
        disabled={!details}
        className="lifey-button flex items-center gap-3.5 p-4 text-left w-full"
        style={{ borderRadius: "var(--r-card)", background: "var(--card)", boxShadow: "var(--e1), var(--edge-card)" }}
      >
        <Avatar name={name} size={48} />
        <span className="flex flex-col min-w-0 flex-1">
          <span className="truncate" style={{ fontSize: 17, fontWeight: 800 }}>{name}</span>
          <span className="truncate type-body-s" style={{ color: "var(--text-2)" }}>{user?.email}</span>
        </span>
        <Icon name="chevron_right" size={22} color="var(--text-3)" />
      </button>

      <ul className="flex flex-col overflow-hidden" style={{ borderRadius: "var(--r-card)", background: "var(--card)", boxShadow: "var(--e1), var(--edge-card)" }}>
        {rows.map((r, i) => (
          <li key={r.key} style={{ borderTop: i ? "1px solid var(--hairline)" : undefined }}>
            <button type="button" onClick={() => setOpen(r.key)} className="lifey-button flex items-center gap-3.5 px-4 min-h-[56px] w-full text-left">
              <Icon name={r.icon} size={22} color="var(--text-2)" />
              <span className="flex-1 min-w-0 truncate" style={{ fontSize: 16, fontWeight: 700 }}>{r.label}</span>
              {r.value && <span className="type-body-s shrink-0" style={{ color: "var(--text-2)" }}>{r.value}</span>}
              <Icon name="chevron_right" size={20} color="var(--text-3)" />
            </button>
          </li>
        ))}
      </ul>

      <Button variant="secondary" fullWidth onClick={() => setOpen("logout")}>
        {t("logoutButton")}
      </Button>

      {open === "profile" && details && <ProfileDrawer details={details} unitSystem={settings.unitSystem} onClose={close} />}
      {open === "goals" && (
        <GoalsDrawer goals={goals} settings={settings} saving={saving} onSave={(values) => save(values, { onSuccess: close })} onClose={close} />
      )}
      {open === "password" && <ChangePasswordDrawer onClose={close} />}
      {open === "theme" && sheet(<AppearanceSection only="theme" />, t("theme"))}
      {open === "language" && sheet(<AppearanceSection only="language" />, t("language"))}
      {open === "units" && sheet(<AppearanceSection only="units" />, t("units"))}
      {open === "notifications" && sheet(<NotificationsSection />, t("notifications"))}
      <LogoutAllConfirm open={open === "logoutAll"} onClose={close} />
      <LogoutDialog open={open === "logout"} onClose={close} onConfirm={() => { close(); void logout(); }} />
    </div>
  );
}
