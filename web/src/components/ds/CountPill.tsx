export interface CountPillProps {
  count: number;
  className?: string;
}

/** An unread-count badge — primary pill, hides itself at 0 (D-W0.7). */
export function CountPill({ count, className }: CountPillProps) {
  if (count <= 0) return null;
  return (
    <span
      className={["inline-flex items-center justify-center rounded-[var(--r-pill)] num", className]
        .filter(Boolean)
        .join(" ")}
      style={{ minWidth: 18, height: 18, padding: "0 5px", fontSize: 11, background: "var(--primary)", color: "var(--on-primary)" }}
    >
      {count > 99 ? "99+" : count}
    </span>
  );
}
