"use client";

import { useTranslations } from "next-intl";
import { Skeleton } from "@/components/status/Skeleton";
import { ErrorState } from "@/components/status/ErrorState";
import { SettingsAnchorNav, type AnchorItem } from "@/features/settings/components/SettingsAnchorNav";
import { ProfileSection } from "@/features/settings/components/sections/ProfileSection";
import { GoalsSection } from "@/features/settings/components/sections/GoalsSection";
import { AppearanceSection } from "@/features/settings/components/sections/AppearanceSection";
import { NotificationsSection } from "@/features/settings/components/sections/NotificationsSection";
import { SecuritySection } from "@/features/settings/components/sections/SecuritySection";
import { LogoutSection } from "@/features/settings/components/sections/LogoutSection";
import { useSettings } from "@/features/settings/useSettings";

/**
 * Settings on one page (W6-G): a sticky anchor list on the left, the six sections stacked on the right. Each section
 * owns its data and its drawer; the page only frames them.
 */
export default function SettingsPage() {
  const t = useTranslations("settings");
  const common = useTranslations("common");
  const { settings, isLoading, isError, refetch } = useSettings();

  if (isError) return <ErrorState onRetry={refetch} />;
  if (isLoading || !settings) return <Skeleton variant="card" className="h-96" />;

  const items: AnchorItem[] = [
    { id: "settings-profile", label: t("profile"), icon: "person" },
    { id: "settings-goals", label: t("dailyGoals"), icon: "target" },
    { id: "settings-appearance", label: t("appearance"), icon: "palette" },
    { id: "settings-notifications", label: t("notifications"), icon: "notifications" },
    { id: "settings-security", label: t("security"), icon: "shield" },
    { id: "settings-logout", label: common("signOut"), icon: "logout" },
  ];

  return (
    <div className="grid grid-cols-1 md:grid-cols-[220px_minmax(0,760px)] gap-6 md:gap-10">
      <SettingsAnchorNav items={items} />
      <div className="flex flex-col gap-5 min-w-0">
        <ProfileSection unitSystem={settings.unitSystem} />
        <GoalsSection />
        <AppearanceSection />
        <NotificationsSection />
        <SecuritySection />
        <LogoutSection />
      </div>
    </div>
  );
}
