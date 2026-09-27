"use client";

import { useState } from "react";
import { AnimatedNumber } from "../../AnimatedNumber";
import { AnimatedFill } from "../../AnimatedFill";

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
  const [number, setNumber] = useState(1041);
  const [fill, setFill] = useState(0.3);

  return (
    <div className="flex flex-col gap-8">
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
      </div>

      <div className="flex flex-col gap-3">
        <h3 className="type-section">AnimatedNumber (counts from its previous value, D-W0.13)</h3>
        <div className="flex items-center gap-4">
          <span data-testid="animated-number">
            <AnimatedNumber value={number} className="text-4xl" />
          </span>
          <button
            type="button"
            data-testid="animated-number-change"
            onClick={() => setNumber((n) => n + 137)}
            className="px-3 h-8 type-button-dense rounded-[var(--r-control)]"
            style={{ background: "var(--control)", color: "var(--text)" }}
          >
            + 137 (animates)
          </button>
          <button
            type="button"
            data-testid="animated-number-same"
            onClick={() => setNumber((n) => n)}
            className="px-3 h-8 type-button-dense rounded-[var(--r-control)]"
            style={{ background: "var(--control)", color: "var(--text)" }}
          >
            Re-render, same value
          </button>
        </div>
      </div>

      <div className="flex flex-col gap-3">
        <h3 className="type-section">AnimatedFill (0 on first appearance, then only the difference)</h3>
        <div className="flex items-center gap-4">
          <div className="flex-1 h-3 rounded-[var(--r-pill)]" style={{ background: "var(--control)" }}>
            <AnimatedFill value={fill}>
              {(animated) => (
                <div
                  data-testid="animated-fill-bar"
                  className="h-full rounded-[var(--r-pill)]"
                  style={{ background: "var(--m-water)", width: `${animated * 100}%` }}
                />
              )}
            </AnimatedFill>
          </div>
          <button
            type="button"
            data-testid="animated-fill-change"
            onClick={() => setFill((f) => Math.min(1, f + 0.25))}
            className="px-3 h-8 type-button-dense rounded-[var(--r-control)]"
            style={{ background: "var(--control)", color: "var(--text)" }}
          >
            + 25%
          </button>
        </div>
      </div>

      <style>{`
        @keyframes lifey-gallery-fill {
          from { width: 0%; }
          to { width: 100%; }
        }
      `}</style>
    </div>
  );
}
