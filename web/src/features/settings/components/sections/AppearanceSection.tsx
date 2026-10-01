"use client";

import { useTranslations } from "next-intl";
import { SegmentedControl } from "@/components/ds";
import { useTheme } from "@/lib/hooks/useTheme";
import { useLocale } from "@/lib/hooks/useLocale";
import { SettingsRow, SettingsSection } from "../SettingsSection";
import { useSettings } from "../../useSettings";
import type { LanguagePreference, ThemePreference, UnitSystem } from "../../types";

/** Appearance and units (W6-G): theme, language and the one unit-system control; each applies at once and persists. */
export function AppearanceSection() {
  const t = useTranslations("settings");
  const { setTheme } = useTheme();
  const { setLanguage } = useLocale();
  const { settings, save } = useSettings();
  if (!settings) return null;

  return (
    <SettingsSection id="settings-appearance" title={t("appearance")}>
      <SettingsRow label={t("theme")} hint={t("appliedImmediately")}>
        <SegmentedControl<ThemePreference>
          aria-label={t("theme")}
          options={[
            { value: "SYSTEM", label: t("system") },
            { value: "LIGHT", label: t("light") },
            { value: "DARK", label: t("dark") },
          ]}
          value={settings.theme}
          onChange={(v) => {
            setTheme(v.toLowerCase() as "light" | "dark" | "system");
            save({ theme: v });
          }}
        />
      </SettingsRow>
      <SettingsRow label={t("language")}>
        <SegmentedControl<LanguagePreference>
          aria-label={t("language")}
          options={[
            { value: "SYSTEM", label: t("system") },
            { value: "HUNGARIAN", label: t("hungarian") },
            { value: "ENGLISH", label: t("english") },
          ]}
          value={settings.language}
          onChange={(v) => {
            setLanguage(v);
            save({ language: v });
          }}
        />
      </SettingsRow>
      <SettingsRow label={t("units")}>
        <SegmentedControl<UnitSystem>
          aria-label={t("units")}
          options={[
            { value: "METRIC", label: t("metric") },
            { value: "IMPERIAL", label: t("imperial") },
          ]}
          value={settings.unitSystem}
          onChange={(v) => save({ unitSystem: v })}
        />
      </SettingsRow>
    </SettingsSection>
  );
}
