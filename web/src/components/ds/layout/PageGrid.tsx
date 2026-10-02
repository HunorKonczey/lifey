import type { CSSProperties, ElementType, ReactNode } from "react";

export type Breakpoint = "base" | "md" | "lg" | "xl" | "2xl";
/** A per-breakpoint value; each breakpoint inherits the one below it. */
export type Responsive<T> = Partial<Record<Breakpoint, T>>;

const BREAKPOINTS: Breakpoint[] = ["base", "md", "lg", "xl", "2xl"];

/** Custom properties `.grid-item` (globals.css) reads: `--span-md`, `--order-xl`, … */
export function gridItemVars(span?: Responsive<number>, order?: Responsive<number>): Record<string, number> {
  const vars: Record<string, number> = {};
  for (const bp of BREAKPOINTS) {
    const s = span?.[bp];
    if (s != null) vars[`--span-${bp}`] = s;
    const o = order?.[bp];
    if (o != null) vars[`--order-${bp}`] = o;
  }
  return vars;
}

export interface PageGridProps {
  as?: ElementType;
  className?: string;
  children: ReactNode;
}

/**
 * The page grid (D-W0.6): 4 columns at mobile, 8 from 768, 12 from 1280;
 * gap 12 / 20 / 24. Place children in `GridItem`s — never hand-write
 * `grid-template-columns` per page.
 */
export function PageGrid({ as: Tag = "div", className, children }: PageGridProps) {
  return <Tag className={["page-grid", className].filter(Boolean).join(" ")}>{children}</Tag>;
}

export interface GridItemProps {
  as?: ElementType;
  /** Columns to span: ≤4 at base, ≤8 at md/lg, ≤12 at xl/2xl. Unset = full row. */
  span?: Responsive<number>;
  /** Visual order per breakpoint — lets one DOM order serve every layout. */
  order?: Responsive<number>;
  className?: string;
  children: ReactNode;
}

export function GridItem({ as: Tag = "div", span, order, className, children }: GridItemProps) {
  return (
    <Tag className={["grid-item", className].filter(Boolean).join(" ")} style={gridItemVars(span, order) as CSSProperties}>
      {children}
    </Tag>
  );
}
