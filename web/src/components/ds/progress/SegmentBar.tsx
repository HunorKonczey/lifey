export interface SegmentBarProps {
  /** Total number of segments — 10 for the water tile (D-W0.16). */
  segments?: number;
  /** Overall value / goal, 0–1+; extra progress past 1 fills nothing further
   *  (every segment is already full). */
  progress: number;
  color: string;
  height?: number;
  gap?: number;
}

/**
 * A discrete step bar — the water tile's 10 segments (D-W0.16). Each segment
 * is full, a fixed 45%-filled "partial" (the one segment straddling the
 * boundary, shown at a constant fill rather than its exact fractional
 * remainder — a full/near-empty sliver reads worse than a consistent partial
 * mark), or empty (`--control`). No mobile precedent to port — this is a
 * fresh web design for W1's water tile.
 */
export function SegmentBar({ segments = 10, progress, color, height = 16, gap = 4 }: SegmentBarProps) {
  const p = Number.isNaN(progress) ? 0 : Math.max(0, progress);
  const filled = Math.min(segments, Math.floor(p * segments));
  const hasPartial = filled < segments && p * segments > filled;
  const radius = height / 3;

  return (
    <div className="flex" style={{ gap }}>
      {Array.from({ length: segments }, (_, i) => {
        const state = i < filled ? "full" : i === filled && hasPartial ? "partial" : "empty";
        return (
          <div key={i} className="flex-1 overflow-hidden" style={{ height, borderRadius: radius, background: "var(--control)" }}>
            {state !== "empty" && (
              <div
                style={{
                  height: "100%",
                  width: state === "full" ? "100%" : "45%",
                  background: color,
                  borderRadius: radius,
                }}
              />
            )}
          </div>
        );
      })}
    </div>
  );
}
