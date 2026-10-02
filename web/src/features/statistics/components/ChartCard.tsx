import type { ReactNode } from "react";
import { Card } from "@/components/ds";

/**
 * The shell every statistics chart sits in (W5.4): the title at 16/700 on the left, a short figure or note on the
 * right, the chart, a legend row and a one-sentence footnote — "every chart has a legend" is a W5 requirement.
 */
export function ChartCard({
  title,
  subtitle,
  note,
  badge,
  footnote,
  children,
  testId,
}: {
  title: string;
  /** Under the title — "heti átlag · naplózás aug. 17-től". */
  subtitle?: string;
  /** Right of the title — "átlag 1 823 · a mai nap nélkül". */
  note?: ReactNode;
  /** A chip right of the header, e.g. "Nincs előző évi adat". */
  badge?: ReactNode;
  footnote?: string;
  children: ReactNode;
  testId?: string;
}) {
  return (
    <Card className="flex flex-col gap-3 min-w-0" data-testid={testId}>
      <div className="flex items-baseline justify-between gap-3 flex-wrap">
        <div className="flex flex-col gap-1 min-w-0">
          <h3 className="type-title-s">{title}</h3>
          {subtitle && (
            <span className="type-body-s" style={{ color: "var(--text-2)" }}>
              {subtitle}
            </span>
          )}
        </div>
        <div className="flex items-center gap-2 type-body-s" style={{ color: "var(--text-2)" }}>
          {note}
          {badge}
        </div>
      </div>
      {children}
      {footnote && (
        <p className="type-body-s" style={{ color: "var(--text-3)" }}>
          {footnote}
        </p>
      )}
    </Card>
  );
}

export interface LegendItem {
  kind: "dashed" | "dotted" | "outline" | "dot" | "bar";
  color: string;
  label: string;
}

/** "- - cél 1 900 · ··· átlag · ▢ ma, folyamatban" — the key to a chart's marks, drawn with the marks themselves. */
export function ChartLegend({ items }: { items: LegendItem[] }) {
  if (items.length === 0) return null;
  return (
    <ul className="flex flex-wrap gap-x-4 gap-y-1 type-body-s" style={{ color: "var(--text-2)" }}>
      {items.map((item) => (
        <li key={item.label} className="flex items-center gap-1.5">
          <Swatch item={item} />
          {item.label}
        </li>
      ))}
    </ul>
  );
}

function Swatch({ item }: { item: LegendItem }) {
  const { kind, color } = item;
  if (kind === "dashed" || kind === "dotted") {
    return <span aria-hidden style={{ width: 14, borderTop: `2px ${kind === "dashed" ? "dashed" : "dotted"} ${color}` }} />;
  }
  if (kind === "dot") return <span aria-hidden style={{ width: 8, height: 8, borderRadius: 999, background: color }} />;
  if (kind === "bar") return <span aria-hidden style={{ width: 12, height: 12, borderRadius: 4, background: color, opacity: 0.7 }} />;
  return <span aria-hidden style={{ width: 12, height: 12, borderRadius: 4, boxShadow: `inset 0 0 0 2px ${color}` }} />;
}
