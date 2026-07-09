"use client";

import { useEffect, useState } from "react";
import { createPortal } from "react-dom";
import { useTranslations } from "next-intl";
import type { WorkoutProgressResult } from "../progress";

const DARK_CONFETTI = ["#9DAE6B", "#4CAF50", "#C49A6C", "#D8B35A"];
const LIGHT_CONFETTI = ["#586E38", "#4CAF50", "#8A6A42", "#B8933A"];

const MAX_ROWS = 5;

// [angleDeg, distance, size, shape(0 dot / 1 square / 2 strip), colorIdx, delaySeconds]
const CONFETTI_PIECES: [number, number, number, number, number, number][] = [
  [-90, 96, 9, 0, 0, 0.00],
  [-55, 110, 7, 1, 1, 0.05],
  [-120, 104, 8, 1, 2, 0.08],
  [-20, 88, 6, 0, 3, 0.12],
  [-160, 92, 7, 0, 1, 0.10],
  [15, 76, 8, 2, 0, 0.16],
  [165, 80, 6, 2, 1, 0.14],
  [-75, 128, 6, 2, 3, 0.04],
  [-105, 122, 6, 0, 1, 0.18],
  [40, 66, 7, 1, 2, 0.20],
  [140, 70, 7, 1, 0, 0.22],
  [-40, 118, 5, 0, 0, 0.24],
];

interface WorkoutSuccessDialogProps {
  open: boolean;
  result: WorkoutProgressResult;
  onClose: () => void;
}

/**
 * Celebration modal shown when the user improved in at least 2 metrics
 * (weight/reps, net of regressions) versus their previous session.
 * See "Lifey Workout Success.dc.html".
 */
export function WorkoutSuccessDialog({ open, result, onClose }: WorkoutSuccessDialogProps) {
  const t = useTranslations("workouts");
  // Lazy — read once per mount. This component only ever mounts client-side
  // (after a mutation success), so `window`/`document` are always available;
  // no effect needed since these never change for the dialog's lifetime.
  const [reduceMotion] = useState(() => window.matchMedia("(prefers-reduced-motion: reduce)").matches);
  const [confettiColors] = useState(() =>
    document.documentElement.getAttribute("data-theme") === "light" ? LIGHT_CONFETTI : DARK_CONFETTI,
  );

  useEffect(() => {
    if (!open) return;
    const onKeyDown = (e: KeyboardEvent) => {
      if (e.key === "Escape") onClose();
    };
    window.addEventListener("keydown", onKeyDown);
    return () => window.removeEventListener("keydown", onKeyDown);
  }, [open, onClose]);

  if (!open) return null;

  const rows = result.improvements.slice(0, MAX_ROWS);
  const remaining = result.improvements.length - rows.length;

  return createPortal(
    <div
      className="fixed inset-0 z-50 overflow-y-auto flex items-center justify-center p-4"
      style={{ background: "var(--scrim-celebration)", backdropFilter: "blur(3px)" }}
      onClick={onClose}
    >
      <div
        role="dialog"
        aria-modal="true"
        aria-label={t("workoutSuccessTitle")}
        onClick={(e) => e.stopPropagation()}
        className="w-full max-w-[420px] rounded-[var(--r-card)] px-[26px] pt-7 pb-6 workout-success-card"
        style={{ background: "var(--surface-container)", boxShadow: "0 30px 70px rgba(0,0,0,.5)" }}
      >
        <div className="relative w-[108px] h-[108px] mx-auto mb-3.5">
          <div
            className="absolute inset-0 rounded-full flex items-center justify-center"
            style={{
              background: "color-mix(in srgb, var(--primary) var(--success-icon-tint), transparent)",
              color: "var(--primary)",
            }}
          >
            <span className="material-symbols-rounded" style={{ fontSize: 64, fontVariationSettings: "'FILL' 1" }}>
              celebration
            </span>
          </div>
          {!reduceMotion && (
            <div className="absolute inset-0 pointer-events-none">
              {CONFETTI_PIECES.map(([angle, dist, size, shape, colorIdx, delay], i) => {
                const rad = (angle * Math.PI) / 180;
                const dx = Math.cos(rad) * dist;
                const dy = Math.sin(rad) * dist;
                const width = shape === 2 ? size * 0.5 : size;
                const height = shape === 2 ? size * 1.9 : size;
                return (
                  <div
                    key={i}
                    className="absolute confetti-piece"
                    style={{
                      left: "50%",
                      top: "50%",
                      width,
                      height,
                      marginLeft: -width / 2,
                      marginTop: -height / 2,
                      borderRadius: shape === 0 ? "50%" : 2,
                      background: confettiColors[colorIdx % confettiColors.length],
                      // @ts-expect-error -- custom properties read by the .confetti-piece keyframes
                      "--dx": `${dx.toFixed(1)}px`,
                      "--dy": `${dy.toFixed(1)}px`,
                      "--rot": `${angle * 3}deg`,
                      animationDelay: `${delay}s`,
                    }}
                  />
                );
              })}
            </div>
          )}
        </div>

        <p className="text-center font-extrabold text-[22px] tracking-[-0.3px] mb-[7px]" style={{ color: "var(--on-surface)" }}>
          {t("workoutSuccessTitle")}
        </p>
        <p className="text-center text-[13.5px] font-medium mb-5" style={{ color: "var(--on-surface-variant)", lineHeight: 1.5 }}>
          {t("workoutSuccessSubtitle", { count: result.improvements.length })}
        </p>

        <div className="flex flex-col gap-[7px] mb-2">
          {rows.map((row, i) => (
            <div
              key={i}
              className="rounded-[13px] px-[13px] py-2.5 flex items-center gap-2.5"
              style={{ background: "var(--surface)" }}
            >
              <span className="flex-1 min-w-0 text-[13px] font-bold truncate" style={{ color: "var(--on-surface)" }}>
                {row.exerciseName}
              </span>
              <div className="flex gap-1.5 flex-none">
                {row.chips.map((chip, ci) => (
                  <span
                    key={ci}
                    className="inline-flex items-center gap-[3px] rounded-[var(--r-pill)] px-2 py-1 text-[11.5px] font-extrabold"
                    style={{ background: "var(--success-chip-bg)", color: "var(--success-chip-text)" }}
                  >
                    <span className="material-symbols-rounded" style={{ fontSize: 13 }}>arrow_upward</span>
                    {chip}
                  </span>
                ))}
              </div>
            </div>
          ))}
        </div>

        {remaining > 0 ? (
          <p className="text-center text-xs font-bold mb-4" style={{ color: "var(--muted)" }}>
            {t("workoutSuccessMoreCount", { count: remaining })}
          </p>
        ) : (
          <div className="mb-2.5" />
        )}

        <button
          onClick={onClose}
          className="w-full h-12 rounded-[var(--r-md)] font-extrabold text-[14.5px]"
          style={{ background: "var(--primary)", color: "#1E1F18" }}
        >
          {t("workoutSuccessContinueButton")}
        </button>
      </div>
    </div>,
    document.body,
  );
}
