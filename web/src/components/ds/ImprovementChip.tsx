import { TintedChip, type TintedChipSize } from "./TintedChip";

/** ↑ in protein green (`--improvement`) — a metric moving the right way (D-W0.7). */
export function ImprovementChip({ label, size, className }: { label: string; size?: TintedChipSize; className?: string }) {
  return <TintedChip label={label} color="var(--improvement)" icon="arrow_upward" size={size} className={className} />;
}
