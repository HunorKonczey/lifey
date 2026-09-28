"use client";

import { useState, type RefObject } from "react";
import Link from "next/link";
import { useTranslations } from "next-intl";
import { useQuery, useMutation, useQueryClient } from "@tanstack/react-query";
import { Popover } from "@/components/ds/Popover";
import { Icon } from "@/components/ds/Icon";
import { SegmentedControl } from "@/components/ds/SegmentedControl";
import { settingsApi } from "@/features/settings/api";
import { queryKeys } from "@/lib/api/queryKeys";
import { useTheme } from "@/lib/hooks/useTheme";
import { useLocale } from "@/lib/hooks/useLocale";
import type { ThemePreference, LanguagePreference } from "@/features/settings/types";
import { LogoutDialog } from "./LogoutDialog";

export interface AccountMenuProps {
  open: boolean;
  onClose: () => void;
  anchorRef: RefObject<HTMLElement | null>;
  onLogout: () => void;
}

/**
 * DS-02's account menu (D-W0.20): Beállítások, a 3-way Téma / Nyelv quick
 * switch (mirroring Settings' own theme/language controls — same dual write
 * of the local store + the persisted setting, so the two entry points never
 * disagree), and Kijelentkezés behind `LogoutDialog`.
 */
export function AccountMenu({ open, onClose, anchorRef, onLogout }: AccountMenuProps) {
  const t = useTranslations("nav");
  const s = useTranslations("settings");
  const common = useTranslations("common");
  const { setTheme } = useTheme();
  const { setLanguage } = useLocale();
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
