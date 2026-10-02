"use client";

import { useState } from "react";
import { useTranslations } from "next-intl";
import { Button, ConfirmModal } from "@/components/ds";
import { useSessionStore } from "@/features/auth/store";
import { ChangePasswordDrawer } from "../ChangePasswordDrawer";
import { SettingsRow, SettingsSection } from "../SettingsSection";

/** "Sign out of all devices" behind its confirmation — the section and the phone list both open it. */
export function LogoutAllConfirm({ open, onClose }: { open: boolean; onClose: () => void }) {
  const t = useTranslations("settings");
  const common = useTranslations("common");
  const { logoutAll } = useSessionStore();
  return (
    <ConfirmModal
      open={open}
      onClose={onClose}
      onConfirm={() => {
        onClose();
        void logoutAll();
      }}
      title={t("logoutAllConfirmTitle")}
      body={t("logoutAllConfirmBody")}
      icon="devices"
      tint="var(--primary)"
      cancelLabel={common("cancel")}
      confirmLabel={t("logoutAllButton")}
      destructive={false}
    />
  );
}

/** Security (W6-G): change password in a drawer, and "sign out of all devices" behind a confirmation. */
export function SecuritySection() {
  const t = useTranslations("settings");
  const [changing, setChanging] = useState(false);
  const [confirmingAll, setConfirmingAll] = useState(false);

  return (
    <SettingsSection id="settings-security" title={t("security")}>
      <SettingsRow label={t("passwordRow")} hint={t("passwordRowHint")}>
        <Button variant="secondary" onClick={() => setChanging(true)}>{t("changePassword")}</Button>
      </SettingsRow>
      <div className="h-px" style={{ background: "var(--hairline)" }} />
      <SettingsRow label={t("logoutAll")} hint={t("logoutAllHint")}>
        <Button variant="secondary" onClick={() => setConfirmingAll(true)}>{t("logoutAllButton")}</Button>
      </SettingsRow>
      {changing && <ChangePasswordDrawer onClose={() => setChanging(false)} />}
      <LogoutAllConfirm open={confirmingAll} onClose={() => setConfirmingAll(false)} />
    </SettingsSection>
  );
}
