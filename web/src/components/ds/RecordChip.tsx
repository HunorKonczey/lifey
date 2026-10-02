import { TintedChip, type TintedChipSize } from "./TintedChip";

/** 🏆 in carbs gold (`--record`) — a personal record (D-W0.7). */
export function RecordChip({ label, size, className }: { label: string; size?: TintedChipSize; className?: string }) {
  return <TintedChip label={label} color="var(--record)" icon="trophy" size={size} className={className} />;
}
