"use client";

import { useTranslations } from "next-intl";
import { Icon } from "@/components/ds";
import type { RailExercise } from "../../liveSession";

/**
 * The exercise list at the left of the live logger (W3.6, W3-B): a state dot per exercise — done ✓ in the
 * protein tint, current ▶ in primary, next ○ — and how many of its sets are done. On a narrow window it lies
 * down as a horizontally scrolling strip above the card.
 */
export function ExerciseRail({ items, onSelect }: { items: RailExercise[]; onSelect: (exerciseId: number) => void }) {
  const t = useTranslations("workouts");

  return (
    <nav aria-label={t("railAria")}>
      <ul className="flex gap-2 overflow-x-auto pb-1 lg:flex-col lg:overflow-visible lg:pb-0">
        {items.map((item) => {
          const current = item.state === "current";
          const done = item.state === "done";
          return (
            <li key={item.exerciseId} className="flex-none lg:flex-auto">
              <button
                type="button"
                onClick={() => onSelect(item.exerciseId)}
                aria-current={current ? "step" : undefined}
                className="lifey-button flex w-full items-center gap-3 px-3 py-2.5 text-left"
                style={{
                  borderRadius: "var(--r-card)",
                  background: current ? "var(--primary-tint)" : "var(--nested)",
                  boxShadow: current ? "inset 0 0 0 2px var(--primary)" : undefined,
                }}
              >
                <span
                  className="flex flex-none items-center justify-center"
                  aria-label={t(done ? "railDone" : current ? "railCurrent" : "railNext")}
                  style={{
                    width: 26,
                    height: 26,
                    borderRadius: "var(--r-pill)",
                    color: done ? "var(--m-protein)" : current ? "var(--primary)" : "var(--text-3)",
                    background: done ? "color-mix(in srgb, var(--m-protein) var(--chip-tint), transparent)" : "transparent",
                  }}
                >
                  <Icon name={done ? "check" : current ? "play_arrow" : "radio_button_unchecked"} size={18} fill={current ? 1 : 0} />
                </span>
                <span className="min-w-0">
                  <span className="type-body-s block truncate" style={{ fontWeight: 700 }}>
                    {item.exerciseName}
                  </span>
                  {item.totalSets > 0 && (
                    <span className="type-label tabular block" style={{ color: "var(--text-3)" }}>
                      {item.doneSets} / {item.totalSets}
                    </span>
                  )}
                </span>
              </button>
            </li>
          );
        })}
      </ul>
    </nav>
  );
}
