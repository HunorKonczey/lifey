"use client";

import { useTranslations } from "next-intl";
import { Icon, IconButton, NumberField } from "@/components/ds";
import { formatNumber } from "@/lib/i18n/format";
import { useFormat } from "@/lib/i18n/format";
import type { DraftSet, RowMark } from "../../liveSession";

/** The grid every set row and the column header share: Szett · Előző · kg · Ismétlés · ✓ · remove. */
export const SET_GRID = "56px minmax(0, 1fr) 120px 120px 56px 32px";

// The −/+ steppers are hidden: the row is for typing, and ↑/↓ step the value from the keyboard.
const BIG_NUMBER = "[&_input]:!text-[18px] [&_input]:!font-extrabold [&_button]:hidden";

/**
 * One set of the live logger (W3.7, W3-B, live-001/002): the number chip, the previous session's "57,5 kg × 8",
 * kg and reps as 18/800 `NumberField`s (↑/↓ step the weight 2,5 kg, the reps 1), 🏆 or ↑ the moment the set is
 * done, and the check. A done row takes the protein tint (250 ms) and a ✓ on the check. Enter commits the row,
 * ticks it and hands focus to the next row — the keyboard path is Tab, type, Enter, type, Enter.
 */
export function SetRow({
  index,
  number,
  draft,
  previous,
  mark,
  onChange,
  onRemove,
  onEnter,
}: {
  /** Position within the exercise, 0-based — the row's focus key. */
  index: number;
  number: number;
  draft: DraftSet;
  previous: { weight: number; reps: number } | undefined;
  mark: RowMark;
  onChange: (patch: Partial<DraftSet>) => void;
  onRemove: () => void;
  onEnter: () => void;
}) {
  const t = useTranslations("workouts");
  const { locale } = useFormat();
  const done = draft.done;

  return (
    <div
      data-set-row={index}
      data-done={done || undefined}
      className="grid items-center gap-2 px-2 py-2"
      style={{
        gridTemplateColumns: SET_GRID,
        borderRadius: "var(--r-card)",
        background: done ? "color-mix(in srgb, var(--m-protein) var(--chip-tint), transparent)" : "transparent",
        transition: "background-color 250ms var(--ease-standard)",
      }}
    >
      <span
        className="tabular flex items-center justify-center"
        style={{ width: 32, height: 32, borderRadius: "var(--r-pill)", background: "var(--nested)", fontWeight: 800 }}
      >
        {number}
      </span>
      <span className="type-body-s tabular truncate" style={{ color: "var(--text-3)" }}>
        {previous ? `${formatNumber(previous.weight, locale, 2)} kg × ${previous.reps}` : "—"}
      </span>
      <NumberField
        aria-label={`${t("kg")} ${number}`}
        value={draft.weight}
        onChange={(weight) => onChange({ weight })}
        step={2.5}
        min={0}
        maxDecimals={2}
        size="dense"
        selectOnFocus
        onEnter={onEnter}
        className={BIG_NUMBER}
      />
      <NumberField
        aria-label={`${t("reps")} ${number}`}
        value={draft.reps}
        onChange={(reps) => onChange({ reps })}
        step={1}
        min={0}
        maxDecimals={0}
        size="dense"
        selectOnFocus
        onEnter={onEnter}
        className={BIG_NUMBER}
      />
      <span className="flex items-center justify-end gap-1">
        {mark.record && <Icon name="trophy" size={18} fill={1} color="var(--record)" label={t("recordAria")} />}
        {!mark.record && mark.better && <Icon name="arrow_upward" size={18} color="var(--improvement)" label={t("improvedAria")} />}
        <button
          type="button"
          onClick={() => onChange({ done: !done })}
          aria-pressed={done}
          aria-label={t("markSetDoneAria")}
          className="lifey-button flex items-center justify-center"
          style={{
            width: 36,
            height: 36,
            borderRadius: "var(--r-control)",
            background: done ? "var(--m-protein)" : "var(--nested)",
            color: done ? "var(--bg)" : "var(--text-3)",
          }}
        >
          <Icon name="check" size={20} />
        </button>
      </span>
      <IconButton icon="close" label={t("removeSetAria")} size={32} onClick={onRemove} />
    </div>
  );
}
