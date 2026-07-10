interface MacroRingProps {
  label: string;
  value: number;
  /** Daily goal for this metric. Omit/null when the user hasn't set one —
   * the ring then shows an empty track and no "/ goal" caption (no invented
   * default goal). */
  goal?: number | null;
  color: string;
  unit?: string;
}

export function MacroRing({ label, value, goal, color, unit = "g" }: MacroRingProps) {
  const hasGoal = goal != null && goal > 0;
  const ratio = hasGoal ? Math.min(value / goal, 1) : 0;
  const size = 52;
  const stroke = 5;
  const r = (size - stroke) / 2;
  const circ = 2 * Math.PI * r;
  const dash = circ * ratio;

  return (
    <div className="flex flex-col items-center gap-2">
      <div className="relative" style={{ width: size, height: size }}>
        <svg width={size} height={size} style={{ transform: "rotate(-90deg)" }}>
          {/* track */}
          <circle
            cx={size / 2} cy={size / 2} r={r}
            fill="none"
            stroke="var(--surface-highest)"
            strokeWidth={stroke}
          />
          {/* progress */}
          <circle
            cx={size / 2} cy={size / 2} r={r}
            fill="none"
            stroke={color}
            strokeWidth={stroke}
            strokeLinecap="round"
            strokeDasharray={`${dash} ${circ}`}
            style={{ transition: "stroke-dasharray var(--dur-slow) var(--ease)" }}
          />
        </svg>
        <div className="absolute inset-0 flex items-center justify-center">
          <span className="text-xs font-bold tabular" style={{ color }}>
            {Math.round(value)}
          </span>
        </div>
      </div>
      <div className="text-center">
        <p className="text-xs font-semibold" style={{ color: "var(--on-surface-variant)" }}>
          {label}
        </p>
        <p className="text-xs tabular" style={{ color: "var(--muted)" }}>
          {hasGoal ? `/ ${goal}${unit}` : " "}
        </p>
      </div>
    </div>
  );
}
