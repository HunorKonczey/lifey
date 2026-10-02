"use client";

import { useState } from "react";
import { useTheme } from "@/lib/hooks/useTheme";
import { useLocale } from "@/lib/hooks/useLocale";
import { setForcedReducedMotion } from "@/lib/hooks/useReducedMotion";

export const GALLERY_WIDTHS = [1440, 1024, 390] as const;
export type GalleryWidth = (typeof GALLERY_WIDTHS)[number];

interface GalleryToolbarProps {
  width: GalleryWidth;
  onWidthChange: (width: GalleryWidth) => void;
}

/** Theme / locale / reduced-motion / width controls for `/dev/design`
 *  (D-W0.12) — not exported from the `ds` barrel, dev-tool only. */
export function GalleryToolbar({ width, onWidthChange }: GalleryToolbarProps) {
  const { preference, setTheme } = useTheme();
  const { locale, setLanguage } = useLocale();
  const [reducedMotion, setReducedMotion] = useState(false);

  return (
    <div
      className="sticky top-0 z-10 flex flex-wrap items-center gap-4 px-5 py-3 type-body-s"
      style={{ background: "var(--float)", backdropFilter: `blur(var(--blur-float))`, borderBottom: "1px solid var(--hairline)" }}
    >
      <span className="type-title-s">Lifey design gallery</span>

      <fieldset className="flex items-center gap-1" aria-label="Theme">
        {(["dark", "light", "system"] as const).map((t) => (
          <button
            key={t}
            type="button"
            onClick={() => setTheme(t)}
            aria-pressed={preference === t}
            className="px-3 h-8 rounded-[var(--r-control)] type-button-dense"
            style={{
              background: preference === t ? "var(--primary)" : "var(--control)",
              color: preference === t ? "var(--on-primary)" : "var(--text)",
            }}
          >
            {t}
          </button>
        ))}
      </fieldset>

      <fieldset className="flex items-center gap-1" aria-label="Locale">
        {(
          [
            { pref: "ENGLISH", label: "EN" },
            { pref: "HUNGARIAN", label: "HU" },
          ] as const
        ).map(({ pref, label }) => (
          <button
            key={pref}
            type="button"
            onClick={() => setLanguage(pref)}
            aria-pressed={(pref === "HUNGARIAN") === (locale === "hu")}
            className="px-3 h-8 rounded-[var(--r-control)] type-button-dense"
            style={{
              background: (pref === "HUNGARIAN") === (locale === "hu") ? "var(--primary)" : "var(--control)",
              color: (pref === "HUNGARIAN") === (locale === "hu") ? "var(--on-primary)" : "var(--text)",
            }}
          >
            {label}
          </button>
        ))}
      </fieldset>

      <label className="flex items-center gap-2">
        <input
          type="checkbox"
          checked={reducedMotion}
          onChange={(e) => {
            setReducedMotion(e.target.checked);
            setForcedReducedMotion(e.target.checked);
          }}
        />
        Reduced motion
      </label>

      <fieldset className="flex items-center gap-1" aria-label="Width">
        {GALLERY_WIDTHS.map((w) => (
          <button
            key={w}
            type="button"
            onClick={() => onWidthChange(w)}
            aria-pressed={width === w}
            className="px-3 h-8 rounded-[var(--r-control)] type-button-dense"
            style={{
              background: width === w ? "var(--primary)" : "var(--control)",
              color: width === w ? "var(--on-primary)" : "var(--text)",
            }}
          >
            {w}
          </button>
        ))}
      </fieldset>
    </div>
  );
}
