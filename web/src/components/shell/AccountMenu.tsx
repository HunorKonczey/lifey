"use client";

import { useState, type RefObject } from "react";
import Link from "next/link";
import { useTranslations } from "next-intl";
import { useQuery, useMutation, useQueryClient } from "@tanstack/react-query";
import { Popover } from "@/components/ds/Popover";
import { Icon } from "@/components/ds/Icon";
import { SegmentedControl } from "@/components/ds/SegmentedControl";
import { Switch } from "@/components/ds/Switch";
import { settingsApi } from "@/features/settings/api";
import { trainerApi } from "@/features/trainer/api";
import { queryKeys } from "@/lib/api/queryKeys";
import { useTheme } from "@/lib/hooks/useTheme";
import { useLocale } from "@/lib/hooks/useLocale";
import { useToast } from "@/lib/hooks/useToast";
import type { ThemePreference, LanguagePreference } from "@/features/settings/types";
import { LogoutDialog } from "./LogoutDialog";

export interface AccountMenuProps {
  open: boolean;
  onClose: () => void;
  anchorRef: RefObject<HTMLElement | null>;
  onLogout: () => void;
  /** Adds the weekly-report-email switch (D-W0.23, `trainer-004`) — only the trainer shell passes this. */
  trainerPrefs?: boolean;
}

/**
 * DS-02's account menu (D-W0.20/23): Beállítások, a 3-way Téma / Nyelv quick
 * switch (mirroring Settings' own theme/language controls — same dual write
 * of the local store + the persisted setting, so the two entry points never
 * disagree), the trainer's weekly-report switch when `trainerPrefs`, and
 * Kijelentkezés behind `LogoutDialog`.
 */
export function AccountMenu({ open, onClose, anchorRef, onLogout, trainerPrefs }: AccountMenuProps) {
  const t = useTranslations("nav");
  const s = useTranslations("settings");
  const common = useTranslations("common");
  const prefs = useTranslations("admin.preferences");
  const { setTheme } = useTheme();
  const { setLanguage } = useLocale();
  const { show } = useToast();
  const queryClient = useQueryClient();
  const [confirmingLogout, setConfirmingLogout] = useState(false);

  const { data: settings } = useQuery({
    queryKey: queryKeys.settings.all(),
    queryFn: settingsApi.get,
  });

  const saveMutation = useMutation({
    mutationFn: (patch: { theme?: ThemePreference; language?: LanguagePreference }) =>
      settingsApi.update({ ...settings!, ...patch }),
    onSuccess: () => queryClient.invalidateQueries({ queryKey: queryKeys.settings.all() }),
  });

  const { data: trainerPreferences } = useQuery({
    queryKey: queryKeys.trainerPreferences.all(),
    queryFn: trainerApi.preferences,
    staleTime: 5 * 60 * 1000,
    enabled: !!trainerPrefs,
  });

  const updateTrainerPreferences = useMutation({
    mutationFn: (weeklyReportEmailEnabled: boolean) => trainerApi.updatePreferences({ weeklyReportEmailEnabled }),
    onSuccess: (data) => {
      queryClient.setQueryData(queryKeys.trainerPreferences.all(), data);
      show(prefs("updated"), "success");
    },
    onError: () => show(prefs("updateFailed"), "error"),
  });

  return (
    <>
      <Popover open={open} onClose={onClose} anchorRef={anchorRef} width={260} className="py-2">
        <Link
          href="/settings"
          onClick={onClose}
          className="lifey-button flex items-center gap-2.5 px-3 h-10 type-body-s mx-1 rounded-[var(--r-control)]"
          style={{ color: "var(--text)" }}
        >
          <Icon name="settings" size={18} color="var(--text-2)" />
          {t("settings")}
        </Link>

        <div className="my-2 mx-3" style={{ borderTop: "1px solid var(--hairline)" }} />

        {settings && (
          <div className="px-3 flex flex-col gap-3 mb-2">
            <div>
              <p className="type-label mb-1.5" style={{ color: "var(--text-3)" }}>{s("theme")}</p>
              <SegmentedControl<ThemePreference>
                aria-label={s("theme")}
                size="sm"
                options={[
                  { value: "SYSTEM", label: s("system") },
                  { value: "LIGHT", label: s("light") },
                  { value: "DARK", label: s("dark") },
                ]}
                value={settings.theme}
                onChange={(v) => {
                  setTheme(v.toLowerCase() as "light" | "dark" | "system");
                  saveMutation.mutate({ theme: v });
                }}
              />
            </div>
            <div>
              <p className="type-label mb-1.5" style={{ color: "var(--text-3)" }}>{s("language")}</p>
              <SegmentedControl<LanguagePreference>
                aria-label={s("language")}
                size="sm"
                options={[
                  { value: "SYSTEM", label: s("system") },
                  { value: "ENGLISH", label: s("english") },
                  { value: "HUNGARIAN", label: s("hungarian") },
                ]}
                value={settings.language}
                onChange={(v) => {
                  setLanguage(v);
                  saveMutation.mutate({ language: v });
                }}
              />
            </div>
          </div>
        )}

        {trainerPrefs && trainerPreferences && (
          <>
            <div className="my-2 mx-3" style={{ borderTop: "1px solid var(--hairline)" }} />
            <div className="px-3 py-1 mb-1">
              <Switch
                checked={trainerPreferences.weeklyReportEmailEnabled}
                onChange={(checked) => updateTrainerPreferences.mutate(checked)}
                label={prefs("weeklyReportEmailLabel")}
              />
            </div>
          </>
        )}

        <div className="my-2 mx-3" style={{ borderTop: "1px solid var(--hairline)" }} />

        <button
          type="button"
          onClick={() => {
            onClose();
            setConfirmingLogout(true);
          }}
          className="lifey-button flex w-full items-center gap-2.5 px-3 h-10 type-body-s mx-0 rounded-[var(--r-control)] text-left"
          style={{ color: "var(--heart)" }}
        >
          <Icon name="logout" size={18} color="var(--heart)" />
          {common("signOut")}…
        </button>
      </Popover>

      <LogoutDialog
        open={confirmingLogout}
        onClose={() => setConfirmingLogout(false)}
        onConfirm={() => {
          setConfirmingLogout(false);
          onLogout();
        }}
      />
    </>
  );
}
