"use client";

import { create } from "zustand";

type ThemeValue = "dark" | "light" | "system";

function resolveTheme(pref: ThemeValue): "dark" | "light" {
  if (pref === "system") {
    return window.matchMedia("(prefers-color-scheme: light)").matches
      ? "light"
      : "dark";
  }
  return pref;
}

function applyTheme(theme: "dark" | "light") {
  document.documentElement.setAttribute("data-theme", theme);
  try {
    localStorage.setItem("lifey-theme", theme);
  } catch {
    // ignore storage errors
  }
}

function getInitialPreference(): ThemeValue {
  try {
    const stored = localStorage.getItem("lifey-theme");
    if (stored === "dark" || stored === "light") return stored;
  } catch { /* ignore */ }
  return "system";
}

interface ThemeState {
  preference: ThemeValue;
  setTheme: (pref: ThemeValue) => void;
}

export const useTheme = create<ThemeState>((set) => ({
  preference: getInitialPreference(),
  setTheme: (pref) => {
    set({ preference: pref });
    applyTheme(resolveTheme(pref));
  },
}));
