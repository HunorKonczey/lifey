"use client";

import { useState } from "react";

const DURATIONS = [
  { label: "hover", varName: "--dur-hover" },
  { label: "menu", varName: "--dur-menu" },
  { label: "modal", varName: "--dur-modal" },
  { label: "toast", varName: "--dur-toast" },
  { label: "drawer", varName: "--dur-drawer" },
  { label: "sheet", varName: "--dur-sheet" },
  { label: "count", varName: "--dur-count" },
  { label: "fill", varName: "--dur-fill" },
  { label: "celebrate", varName: "--dur-celebrate" },
];

/** D-W0.13 — one durations demo per row, replayable, so reduced motion
 *  (the toolbar's toggle, or the OS setting) can be checked by eye: every
 *  bar should jump straight to its end state instead of easing into it. */
export function MotionSection() {
  const [run, setRun] = useState(0);

  return (
    <div className="flex flex-col gap-3">
      <button
        type="button"
        onClick={() => setRun((n) => n + 1)}
        className="self-start px-4 h-9 type-button-dense rounded-[var(--r-control)]"
        style={{ background: "var(--primary)", color: "var(--on-primary)" }}
      >
        Replay
      </button>
      {DURATIONS.map((d) => (
        <div key={d.label} className="flex items-center gap-4">
          <code className="type-label w-24 shrink-0" style={{ color: "var(--text-3)" }}>{d.label}</code>
          <div className="flex-1 h-3 rounded-[var(--r-pill)]" style={{ background: "var(--control)" }}>
            <div
              key={run}
              className="h-full rounded-[var(--r-pill)] w-0"
              style={{
                background: "var(--primary)",
                animation: `lifey-gallery-fill var(${d.varName}) var(--ease-standard) forwards`,
              }}
            />
          </div>
        </div>
      ))}
      <style>{`
        @keyframes lifey-gallery-fill {
          from { width: 0%; }
          to { width: 100%; }
        }
      `}</style>
    </div>
  );
}
