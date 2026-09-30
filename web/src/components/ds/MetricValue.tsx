/**
 * A hero/tile number with its unit (D-W0.7): tabular, 800 weight, −3 %
 * tracking, the unit smaller and in `--text-2` beside it. The one place this
 * shape gets built, so a number is never a bare `<span>{value} kg</span>`
 * with an ad-hoc size for the unit.
 *
 * Pass `label` with a full sentence ("859 kilocalories left") whenever the
 * value and unit are visually split — screen readers get the sentence
 * instead of two separately-announced fragments. `role="text"` is a
 * long-standing (non-standard, WebKit-originated but broadly honoured)
 * pattern for telling VoiceOver to read a group of nodes as one phrase.
 */
export interface MetricValueProps {
  value: string | number;
  unit?: string;
  /** Number font-size in px (56 hero ring, 26–34 KPI, 28 tile…). Default 32. */
  size?: number;
  /** Unit size as a fraction of `size`, in px (`size` is px too). Default 0.42 (D-W0.7); tiles use 0.5. */
  unitRatio?: number;
  label?: string;
  className?: string;
}

export function MetricValue({ value, unit, size = 32, unitRatio = 0.42, label, className }: MetricValueProps) {
  const hidden = label ? true : undefined;
  return (
    <span
      className={["inline-flex items-baseline gap-1", className].filter(Boolean).join(" ")}
      aria-label={label}
      role={label ? "text" : undefined}
    >
      <span className="num text-fg" style={{ fontSize: size }} aria-hidden={hidden}>
        {value}
      </span>
      {unit && (
        <span className="text-fg-2 font-medium" style={{ fontSize: Math.round(size * unitRatio) }} aria-hidden={hidden}>
          {unit}
        </span>
      )}
    </span>
  );
}
