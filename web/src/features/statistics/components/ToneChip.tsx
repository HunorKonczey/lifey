import { TintedChip } from "@/components/ds";
import type { DeltaTone } from "../periodStats";

/** Green = better toward the goal, orange = worse, grey = neutral (W5 note "A delta színe a jelentést követi"). */
const TONE_COLOR: Record<DeltaTone, string> = {
  good: "var(--improvement)",
  bad: "var(--m-kcal)",
  neutral: "var(--text-2)",
};

export function ToneChip({ label, tone }: { label: string; tone: DeltaTone }) {
  return <TintedChip label={label} color={TONE_COLOR[tone]} />;
}
