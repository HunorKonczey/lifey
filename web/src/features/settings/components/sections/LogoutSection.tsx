"use client";

import { useState } from "react";
import { useTranslations } from "next-intl";
import { Button } from "@/components/ds";
import { LogoutDialog } from "@/components/shell/LogoutDialog";
import { useSessionStore } from "@/features/auth/store";
import { SettingsRow, SettingsSection } from "../SettingsSection";

/** Sign out (W6-G): one honest line and the same `LogoutDialog` the account menu opens. */
export function LogoutSection() {
  const t = useTranslations("settings");
  const common = useTranslations("common");
  const { logout } = useSessionStore();
  const [confirming, setConfirming] = useState(false);

  return (
    <SettingsSection id="settings-logout" title={common("signOut")}>
      <SettingsRow label={t("logoutBody")}>
        <Button variant="secondary" onClick={() => setConfirming(true)}>{t("logoutButton")}</Button>
      </SettingsRow>
      <LogoutDialog open={confirming} onClose={() => setConfirming(false)} onConfirm={() => { setConfirming(false); void logout(); }} />
    </SettingsSection>
  );
}
