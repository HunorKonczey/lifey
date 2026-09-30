"use client";

import { useTranslations } from "next-intl";
import { delta } from "../../progress";
import type { DraftSet } from "../../liveSession";
import type { ExerciseSetResponse } from "../../types";

/**
 * The current exercise's set table (W3.6 lifts it out of the old `SessionLogger` unchanged; W3.7 rebuilds the
 * rows — 18 px fields, PR marks, keyboard). `rows` carry each draft's index in the whole session's draft list.
 */
export function ExerciseCard({
  name,
  rows,
  previous,
  onUpdate,
  onRemove,
  onAddSet,
}: {
  name: string;
  rows: { draft: DraftSet; index: number }[];
  previous: ExerciseSetResponse[];
  onUpdate: (index: number, patch: Partial<DraftSet>) => void;
  onRemove: (index: number) => void;
  onAddSet: () => void;
}) {
  const t = useTranslations("workouts");

  return (
    <div className="rounded-[var(--r-card)] p-4" style={{ background: "var(--surface)" }}>
      <p className="font-bold text-sm mb-3">{name}</p>

      <div className="grid grid-cols-[40px_1fr_1fr_1fr_44px_32px] gap-2 px-1 mb-2 text-xs font-semibold" style={{ color: "var(--on-surface-variant)" }}>
        <span>{t("setColumn")}</span>
        <span>{t("previous")}</span>
        <span>{t("kg")}</span>
        <span>{t("reps")}</span>
        <span></span>
        <span></span>
      </div>

      {rows.map(({ draft: d, index: i }, localIdx) => {
        const prev = previous[localIdx];
        const weightDelta = d.done ? delta(d.weight, prev?.weight) : null;
        const repsDelta = d.done ? delta(d.reps, prev?.reps) : null;
        return (
          <div
            key={i}
            className="grid grid-cols-[40px_1fr_1fr_1fr_44px_32px] gap-2 items-center px-1 py-1 rounded-[var(--r-sm)]"
            style={{ outline: d.done ? "1px solid color-mix(in srgb, var(--primary) 40%, transparent)" : "none" }}
          >
            <span className="text-sm tabular font-semibold">{localIdx + 1}</span>
            <span className="text-xs tabular" style={{ color: "var(--muted)" }}>
              {prev ? `${prev.weight}kg × ${prev.reps}` : "—"}
            </span>
            <div className="relative">
              <input
                type="number"
                value={d.weight}
                min={0}
                step="0.5"
                onChange={(e) => onUpdate(i, { weight: Number(e.target.value) })}
                className="w-full px-2 h-8 rounded-[var(--r-sm)] outline-none text-sm tabular"
                style={{ background: "var(--surface-container)", border: "1px solid var(--outline)" }}
              />
              {weightDelta && (
                <span
                  className="material-symbols-rounded absolute right-1 top-1/2 -translate-y-1/2 text-xs pointer-events-none"
                  style={{ color: weightDelta === "up" ? "#4CAF50" : "#D66B5A" }}
                >
                  {weightDelta === "up" ? "arrow_upward" : "arrow_downward"}
                </span>
              )}
            </div>
            <div className="relative">
              <input
                type="number"
                value={d.reps === 0 ? "" : d.reps}
                min={0}
                placeholder="0"
                onChange={(e) => onUpdate(i, { reps: e.target.value === "" ? 0 : Number(e.target.value) })}
                className="w-full px-2 h-8 rounded-[var(--r-sm)] outline-none text-sm tabular"
                style={{ background: "var(--surface-container)", border: "1px solid var(--outline)" }}
              />
              {repsDelta && (
                <span
                  className="material-symbols-rounded absolute right-1 top-1/2 -translate-y-1/2 text-xs pointer-events-none"
                  style={{ color: repsDelta === "up" ? "#4CAF50" : "#D66B5A" }}
                >
                  {repsDelta === "up" ? "arrow_upward" : "arrow_downward"}
                </span>
              )}
            </div>
            <button
              onClick={() => onUpdate(i, { done: !d.done })}
              className="w-8 h-8 rounded-[var(--r-sm)] flex items-center justify-center transition-colors"
              style={{ background: d.done ? "var(--primary)" : "var(--surface-container)", color: d.done ? "var(--bg)" : "var(--muted)" }}
              aria-label={t("markSetDoneAria")}
            >
              <span className="material-symbols-rounded text-lg">check</span>
            </button>
            <button
              onClick={() => onRemove(i)}
              className="w-8 h-8 rounded-[var(--r-sm)] flex items-center justify-center"
              style={{ color: "var(--muted)" }}
              aria-label={t("removeSetAria")}
            >
              <span className="material-symbols-rounded text-lg">close</span>
            </button>
          </div>
        );
      })}

      <button
        onClick={onAddSet}
        className="w-full mt-2 py-1.5 rounded-[var(--r-sm)] text-xs font-semibold flex items-center justify-center gap-1"
        style={{ border: "1px dashed var(--outline)", color: "var(--on-surface-variant)" }}
      >
        <span className="material-symbols-rounded text-base">add</span> {t("addSet")}
      </button>
    </div>
  );
}
