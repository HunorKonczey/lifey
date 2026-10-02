"use client";

import { Icon } from "@/components/ds";
import { useFormat } from "@/lib/format/useFormat";

/**
 * A client's weight change over the window as a plain neutral chip: arrow, signed kg. The trainer does not know the
 * client's goal weight, so the change is never coloured good or bad (a coloured chip would claim a direction we cannot
 * judge) — and the neutral text colour is the one that clears contrast on the chip in both themes.
 */
export function WeightDelta({ kg }: { kg: number }) {
  const fmt = useFormat();
  return (
    <span
      className="inline-flex items-center gap-1 px-2 tabular"
      style={{ height: 22, borderRadius: 999, background: "var(--control)", color: "var(--text)", fontSize: 12, fontWeight: 700 }}
    >
      <Icon name={kg < 0 ? "arrow_downward" : kg > 0 ? "arrow_upward" : "remove"} size={14} />
      {fmt.signedDelta(kg, { digits: 1, unit: "kg" })}
    </span>
  );
}
