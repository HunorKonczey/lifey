"use client";

import { useTranslations } from "next-intl";
import { Switch, TimeField } from "@/components/ds";
import { SettingsRow, SettingsSection } from "../SettingsSection";
import { useSettings } from "../../useSettings";

const DEFAULT_QUIET_HOURS = { start: "22:00:00", end: "07:00:00" };

/** A backend `LocalTime` is "HH:mm:ss"; the field speaks "HH:mm" — the seconds never reach the screen. */
const toFieldTime = (value: string | null) => (value ? value.slice(0, 5) : "");
const fromFieldTime = (value: string) => (value ? `${value}:00` : null);

/** Notifications (W6-G): the push flags this client models — chat messages and the chat quiet-hours window. */
export function NotificationsSection() {
  const t = useTranslations("settings");
  const { settings, save } = useSettings();
  if (!settings) return null;
  const quiet = !!settings.chatQuietHoursStart && !!settings.chatQuietHoursEnd;

  return (
    <SettingsSection id="settings-notifications" title={t("notifications")}>
      <SettingsRow label={t("chatPushLabel")} hint={t("chatPushHint")}>
        <Switch aria-label={t("chatPushLabel")} checked={settings.chatPushEnabled ?? true} onChange={(checked) => save({ chatPushEnabled: checked })} />
      </SettingsRow>
      <div className="h-px" style={{ background: "var(--hairline)" }} />
      <SettingsRow label={t("quietHoursLabel")} hint={t("quietHoursHint")}>
        <Switch
          aria-label={t("quietHoursLabel")}
          checked={quiet}
          // Turning the window off has to be said explicitly, or the server cannot tell it from a client that
          // knows nothing about quiet hours at all — hence chatQuietHoursSet.
          onChange={(checked) =>
            save({
              chatQuietHoursStart: checked ? DEFAULT_QUIET_HOURS.start : null,
              chatQuietHoursEnd: checked ? DEFAULT_QUIET_HOURS.end : null,
              chatQuietHoursSet: true,
            })
          }
        />
      </SettingsRow>
      {quiet && (
        <div className="grid grid-cols-2 gap-3 max-w-[360px]">
          <TimeField label={t("quietHoursFrom")} value={toFieldTime(settings.chatQuietHoursStart)} onChange={(v) => save({ chatQuietHoursStart: fromFieldTime(v), chatQuietHoursSet: true })} />
          <TimeField label={t("quietHoursTo")} value={toFieldTime(settings.chatQuietHoursEnd)} onChange={(v) => save({ chatQuietHoursEnd: fromFieldTime(v), chatQuietHoursSet: true })} />
        </div>
      )}
    </SettingsSection>
  );
}
