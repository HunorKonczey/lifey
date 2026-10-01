"use client";

import { contrastRatio, parseCssColor } from "@/lib/theme/contrast";
import { useCssVar } from "../useCssVar";

const AA = 4.5;

interface SwatchDef {
  label: string;
  bg: string;
  fg?: string;
}

const SURFACES: SwatchDef[] = [
  { label: "bg", bg: "--bg", fg: "--text" },
  { label: "card", bg: "--card", fg: "--text" },
  { label: "nested", bg: "--nested", fg: "--text" },
  { label: "control", bg: "--control", fg: "--text" },
  { label: "raised", bg: "--raised", fg: "--text" },
];

const TEXT_TIERS: SwatchDef[] = [
  { label: "text on bg", bg: "--bg", fg: "--text" },
  { label: "text-2 on bg", bg: "--bg", fg: "--text-2" },
  { label: "text-3 on bg", bg: "--bg", fg: "--text-3" },
];

const BRAND: SwatchDef[] = [
  { label: "primary / on-primary", bg: "--primary", fg: "--on-primary" },
  { label: "role (clay) / on-primary", bg: "--role", fg: "--on-primary" },
];

const METRICS: SwatchDef[] = [
  { label: "kcal", bg: "--m-kcal" },
  { label: "protein", bg: "--m-protein" },
  { label: "carbs", bg: "--m-carbs" },
  { label: "fat", bg: "--m-fat" },
  { label: "water", bg: "--m-water" },
  { label: "steps", bg: "--m-steps" },
  { label: "weight", bg: "--m-weight" },
  { label: "heart", bg: "--m-heart" },
];

function Swatch({ label, bg, fg }: SwatchDef) {
  const bgValue = useCssVar(bg);
  const fgValue = useCssVar(fg ?? "--text");
  let ratio: number | null = null;
  try {
    if (bgValue && fgValue) ratio = contrastRatio(parseCssColor(fgValue), parseCssColor(bgValue));
  } catch {
    ratio = null;
  }
  const pass = ratio !== null && ratio >= AA;

  return (
    <div
      className="flex items-center justify-between rounded-[var(--r-control)] px-3 h-14 min-w-[220px]"
      style={{ background: `var(${bg})`, color: fg ? `var(${fg})` : undefined, border: "1px solid var(--hairline)" }}
    >
      <span className="type-body-s">{label}</span>
      {fg && (
        <span className="type-label" aria-label={`contrast ratio ${ratio?.toFixed(2) ?? "unknown"} to 1`}>
          {ratio !== null ? `${pass ? "✓" : "✗"} ${ratio.toFixed(2)}:1` : "—"}
        </span>
      )}
    </div>
  );
}

export function ColorSection() {
  return (
    <div className="flex flex-col gap-6">
      <div>
        <h3 className="type-section mb-2">Surfaces</h3>
        <div className="flex flex-wrap gap-2">
          {SURFACES.map((s) => <Swatch key={s.label} {...s} />)}
        </div>
      </div>
      <div>
        <h3 className="type-section mb-2">Text tiers (AA ≥ 4.5:1)</h3>
        <div className="flex flex-wrap gap-2">
          {TEXT_TIERS.map((s) => <Swatch key={s.label} {...s} />)}
        </div>
      </div>
      <div>
        <h3 className="type-section mb-2">Brand</h3>
        <div className="flex flex-wrap gap-2">
          {BRAND.map((s) => <Swatch key={s.label} {...s} />)}
        </div>
      </div>
      <div>
        <h3 className="type-section mb-2">Metrics (on card)</h3>
        <div className="flex flex-wrap gap-2">
          {METRICS.map((s) => <Swatch key={s.label} label={s.label} bg="--card" fg={s.bg} />)}
        </div>
      </div>
    </div>
  );
}
