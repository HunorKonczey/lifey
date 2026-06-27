"use client";

import { useTheme } from "@/lib/hooks/useTheme";

export function ThemeToggle() {
  const { preference, setTheme } = useTheme();

  const next = preference === "dark" ? "light" : "dark";
  const icon = preference === "light" ? "light_mode" : "dark_mode";

  return (
    <button
      onClick={() => setTheme(next)}
      className="p-1.5 rounded-[var(--r-sm)] transition-colors hover:bg-surface-container"
      style={{ color: "var(--on-surface-variant)" }}
      aria-label={`Switch to ${next} theme`}
      title={`Switch to ${next} theme`}
    >
      <span className="material-symbols-rounded text-xl">{icon}</span>
    </button>
  );
}
