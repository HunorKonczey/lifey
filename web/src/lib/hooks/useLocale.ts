"use client";

import { create } from "zustand";
import type { LanguagePreference } from "@/features/settings/types";

export type Locale = "en" | "hu";

function resolveLocale(pref: LanguagePreference): Locale {
  if (pref === "HUNGARIAN") return "hu";
  if (pref === "ENGLISH") return "en";
  if (typeof navigator !== "undefined") {
    return navigator.language.toLowerCase().startsWith("hu") ? "hu" : "en";
  }
  return "en";
}

interface LocaleState {
  locale: Locale;
  setLanguage: (pref: LanguagePreference) => void;
}

export const useLocale = create<LocaleState>((set) => ({
  locale:
    typeof navigator !== "undefined" &&
    navigator.language.toLowerCase().startsWith("hu")
      ? "hu"
      : "en",
  setLanguage: (pref) => set({ locale: resolveLocale(pref) }),
}));
