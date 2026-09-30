"use client";

import { useEffect, useRef } from "react";
import { useTranslations } from "next-intl";
import { Button, Card, Icon } from "@/components/ds";
import { formatNumber, useFormat } from "@/lib/i18n/format";
import type { DraftSet, RowMark } from "../../liveSession";
import { SET_GRID, SetRow } from "./SetRow";

/** The focusable inputs of one set row. */
const rowInput = (root: HTMLElement | null, row: number) => root?.querySelector<HTMLInputElement>(`[data-set-row="${row}"] input`) ?? null;

/**
 * The current exercise of the live logger (W3.7, W3-B): its name, "4 × 8 · legjobb eddig 60 kg × 8", the column
 * header and the set rows, "+ Szett". Enter in a row ticks it and moves to the next row's kg field; on the last
 * row it adds a set first, so a whole exercise can be logged without the mouse.
 */
export function ExerciseCard({
  name,
  rows,
  previous,
  marks,
  planned,
  best,
  onUpdate,
  onRemove,
  onAddSet,
}: {
  name: string;
  /** This exercise's drafts; `index` is the position in the whole session's draft list. */
  rows: { draft: DraftSet; index: number }[];
  previous: { weight: number; reps: number }[];
  marks: RowMark[];
  /** Planned sets (the template's target) — 0 when there is none. */
  planned: number;
  /** The exercise's best set before this workout. */
  best: { weight: number; reps: number } | null;
  onUpdate: (index: number, patch: Partial<DraftSet>) => void;
  onRemove: (index: number) => void;
  onAddSet: () => void;
}) {
  const t = useTranslations("workouts");
  const { locale } = useFormat();
  const root = useRef<HTMLDivElement>(null);
  // Set when Enter on the last row added a set: its kg field takes focus once it exists.
  const focusNew = useRef(false);

  useEffect(() => {
    if (!focusNew.current) return;
    focusNew.current = false;
    rowInput(root.current, rows.length - 1)?.focus();
  }, [rows.length]);

  const typicalReps = previous[0]?.reps;
  const target = planned > 0 ? `${planned}${typicalReps ? ` × ${typicalReps}` : ""}` : null;
  const bestText = best ? t("bestSoFar", { value: `${formatNumber(best.weight, locale, 2)} kg × ${best.reps}` }) : null;

  function enterOn(rowIndex: number, draftIndex: number) {
    onUpdate(draftIndex, { done: true });
    if (rowIndex + 1 < rows.length) {
      requestAnimationFrame(() => rowInput(root.current, rowIndex + 1)?.focus());
    } else {
      focusNew.current = true;
      onAddSet();
    }
  }

  return (
    <div ref={root}>
    <Card>
      <div className="mb-3">
        <h2 className="type-title">{name}</h2>
        {(target || bestText) && (
          <p className="type-body-s tabular" style={{ color: "var(--text-2)" }}>
            {[target, bestText].filter(Boolean).join(" · ")}
          </p>
        )}
      </div>

      <div
        className="type-label grid gap-2 px-2 pb-1"
        style={{ gridTemplateColumns: SET_GRID, color: "var(--text-3)" }}
        aria-hidden
      >
        <span className="text-center">{t("setColumn")}</span>
        <span>{t("previous")}</span>
        <span className="text-center">{t("kg")}</span>
        <span className="text-center">{t("reps")}</span>
        <span />
        <span />
      </div>

      <div className="flex flex-col gap-1">
        {rows.map(({ draft, index }, i) => (
          <SetRow
            key={index}
            index={i}
            number={i + 1}
            draft={draft}
            previous={previous[i]}
            mark={marks[i] ?? { record: false, better: false }}
            onChange={(patch) => onUpdate(index, patch)}
            onRemove={() => onRemove(index)}
            onEnter={() => enterOn(i, index)}
          />
        ))}
      </div>

      <Button variant="ghost" onClick={onAddSet} className="mt-2">
        <Icon name="add" size={20} />
        {t("addSet")}
      </Button>
    </Card>
    </div>
  );
}
