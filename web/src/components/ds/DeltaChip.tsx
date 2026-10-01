import { useFormat } from "@/lib/format/useFormat";
import { TintedChip, type TintedChipSize } from "./TintedChip";

export interface DeltaChipProps {
  /** The signed change, in the metric's own unit — e.g. `-0.4` for a 0.4kg loss. */
  value: number;
  unit?: string;
  digits?: number;
  /**
   * Which direction of change is *good* for this metric: `"lower"` (weight
   * loss toward a goal) makes a negative delta render as `--improvement`
   * green rather than the neutral `--decrease`, and a delta the wrong way
   * renders `--heart` (W4 note: a loss toward a lower goal is improvement,
   * not just "a decrease"). `"higher"` is the mirror (steps, workouts).
   * Omit for a metric with no goal direction — sign alone picks
   * `--increase`/`--decrease`.
   */
  goalDirection?: "lower" | "higher";
  size?: TintedChipSize;
  className?: string;
}

/** A signed metric change, coloured by what it *means* rather than only its
 *  sign (D-W0.7). */
export function DeltaChip({ value, unit, digits = 1, goalDirection, size, className }: DeltaChipProps) {
  const f = useFormat();
  const label = f.signedDelta(value, { digits, unit });
  const icon = value < 0 ? "arrow_downward" : value > 0 ? "arrow_upward" : "remove";

  let color: string;
  if (value === 0) {
    color = "var(--text-2)";
  } else if (goalDirection === undefined) {
    color = value < 0 ? "var(--decrease)" : "var(--increase)";
  } else {
    const towardGoal = goalDirection === "lower" ? value < 0 : value > 0;
    color = towardGoal ? "var(--improvement)" : "var(--heart)";
  }

  return <TintedChip label={label} color={color} icon={icon} size={size} className={className} />;
}
