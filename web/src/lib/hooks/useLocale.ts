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
  /** False until detectBrowserLocale has run once — lets effects that must
   *  not run twice (e.g. loading the Google Identity Services script) wait
   *  for the real locale instead of reacting to the transient "en" default. */
  hydrated: boolean;
  setLanguage: (pref: LanguagePreference) => void;
  detectBrowserLocale: () => void;
}

// Deliberately fixed for the initial render (server and first client pass
// must match, or React throws away the SSR tree and re-renders client-only —
// see detectBrowserLocale, which corrects this after mount instead).
export const useLocale = create<LocaleState>((set) => ({
  locale: "en",
  hydrated: false,
  setLanguage: (pref) => set({ locale: resolveLocale(pref) }),
  detectBrowserLocale: () =>
    set({ locale: navigator.language.toLowerCase().startsWith("hu") ? "hu" : "en", hydrated: true }),
}));
