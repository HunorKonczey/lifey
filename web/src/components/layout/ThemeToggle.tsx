"use client";

import { useTranslations } from "next-intl";
import { useTheme } from "@/lib/hooks/useTheme";

export function ThemeToggle() {
  const t = useTranslations("common");
  const { preference, setTheme } = useTheme();

  const next = preference === "dark" ? "light" : "dark";
  const icon = preference === "light" ? "light_mode" : "dark_mode";
  const label = next === "light" ? t("switchToLightTheme") : t("switchToDarkTheme");

  return (
    <button
      onClick={() => setTheme(next)}
      className="p-1.5 rounded-[var(--r-sm)] transition-colors hover:bg-surface-container"
      style={{ color: "var(--on-surface-variant)" }}
      aria-label={label}
      title={label}
    >
      <span className="material-symbols-rounded text-xl">{icon}</span>
    </button>
  );
}
