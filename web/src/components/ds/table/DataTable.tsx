"use client";

import { useEffect, useMemo, useRef, useState, type ReactNode } from "react";
import { useLocale } from "next-intl";
import { Icon } from "../Icon";
import type { MenuItemDef } from "../Menu";
import { RowMenuButton } from "../RowMenuButton";
import { useMediaQuery } from "@/lib/hooks/useMediaQuery";
import { TablePagination } from "./TablePagination";
import { TableToolbar } from "./TableToolbar";
import { useTableKeyboard } from "./useTableKeyboard";

export type TableDensity = "comfortable" | "compact";

export interface DataTableColumn<T> {
  key: string;
  header: string;
  align?: "left" | "right";
  width?: number | string;
  /** A small coloured dot before the header label — the macro columns (D-W0.15). */
  metricDot?: string;
  render: (row: T) => ReactNode;
  /** Enables sorting on this column; extracts the value to compare by. */
  sort?: (row: T) => string | number;
}

export interface DataTableCardRow {
  title: ReactNode;
  meta?: ReactNode;
  value?: ReactNode;
}

export interface DataTableProps<T> {
  columns: DataTableColumn<T>[];
  rows: T[];
  rowKey: (row: T) => string | number;
  selectedKey?: string | number | null;
  onRowOpen?: (row: T) => void;
  rowMenu?: (row: T) => MenuItemDef[];
  /** < 768 renders every row as a card instead of a table row (D-W0.15). */
  renderCardRow?: (row: T) => DataTableCardRow;
  pageSize?: number;
  search?: { value: string; onChange: (value: string) => void; placeholder?: string };
  filters?: ReactNode;
  action?: ReactNode;
  /** e.g. `(n) => \`${n} foods\`` — the caller's own pluralized copy. */
  totalLabel?: (total: number) => string;
  /** Distinguishes each row's "…" button by name (e.g. `(f) => \`More actions for ${f.name}\`\`)
   *  — every row shares `RowMenuButton`'s "More actions" default otherwise. */
  rowMenuLabel?: (row: T) => string;
  "aria-label"?: string;
}

const ROW_HEIGHT: Record<TableDensity, number> = { comfortable: 56, compact: 44 };

/**
 * DS-03's table (D-W0.15): sortable columns, a search+density toolbar, a
 * "…" row menu (never a row of icon buttons), roving-tabindex keyboard nav
 * (↑/↓ moves the active row, Enter opens it, Shift+F10 opens its menu), and
 * a card-row layout under 768px instead of a horizontally-scrolling table.
 */
export function DataTable<T>({
  columns,
  rows,
  rowKey,
  selectedKey,
  onRowOpen,
  rowMenu,
  renderCardRow,
  pageSize = 10,
  search,
  filters,
  action,
  totalLabel,
  rowMenuLabel,
  ...aria
}: DataTableProps<T>) {
  const [density, setDensity] = useState<TableDensity>("comfortable");
  const [sortKey, setSortKey] = useState<string | null>(null);
  const [sortDir, setSortDir] = useState<"asc" | "desc">("asc");
  const [page, setPage] = useState(0);
  const [openRowMenu, setOpenRowMenu] = useState<number | null>(null);
  const isMobile = useMediaQuery("(max-width: 767px)");
  const locale = useLocale();
  const searchRef = useRef<HTMLInputElement>(null);
  const rowRefs = useRef<(HTMLElement | null)[]>([]);
  const bodyRef = useRef<HTMLTableSectionElement>(null);

  useEffect(() => {
    function handleSlash(e: KeyboardEvent) {
      if (e.key !== "/" || !search) return;
      const target = e.target as HTMLElement;
      if (target.tagName === "INPUT" || target.tagName === "TEXTAREA" || target.isContentEditable) return;
      // With more than one table on a page (the design gallery), only the one whose search box is on screen answers.
      const box = searchRef.current?.getBoundingClientRect();
      if (!box || box.bottom < 0 || box.top > window.innerHeight) return;
      e.preventDefault();
      searchRef.current?.focus();
    }
    document.addEventListener("keydown", handleSlash);
    return () => document.removeEventListener("keydown", handleSlash);
  }, [search]);

  const sorted = useMemo(() => {
    if (!sortKey) return rows;
    const col = columns.find((c) => c.key === sortKey);
    if (!col?.sort) return rows;
    const extract = col.sort;
    // Text sorts by the locale's alphabet ("Édesburgonya" among the E's, not after "Zab…"), numbers numerically.
    const collator = new Intl.Collator(locale, { numeric: true });
    return [...rows].sort((a, b) => {
      const va = extract(a);
      const vb = extract(b);
      const cmp =
        typeof va === "string" && typeof vb === "string" ? collator.compare(va, vb) : va < vb ? -1 : va > vb ? 1 : 0;
      return sortDir === "asc" ? cmp : -cmp;
    });
  }, [rows, sortKey, sortDir, columns, locale]);

  const totalPages = Math.max(1, Math.ceil(sorted.length / pageSize));
  const safePage = Math.min(page, totalPages - 1);
  const pageRows = sorted.slice(safePage * pageSize, safePage * pageSize + pageSize);

  const { activeIndex, setActiveIndex, handleKeyDown } = useTableKeyboard(pageRows.length);

  useEffect(() => {
    setActiveIndex(0);
  }, [safePage, sortKey, sortDir, setActiveIndex]);

  // Roving focus follows the active row only while focus is already in the body — arrow keys moving through
  // rows. Never on mount or after a sort: that stole focus from the page and drew a focus ring on row one.
  useEffect(() => {
    const active = document.activeElement;
    if (active && bodyRef.current?.contains(active)) rowRefs.current[activeIndex]?.focus();
  }, [activeIndex]);

  function toggleSort(key: string) {
    if (sortKey === key) {
      setSortDir((d) => (d === "asc" ? "desc" : "asc"));
    } else {
      setSortKey(key);
      setSortDir("asc");
    }
  }

  return (
    <div
      className="flex flex-col overflow-hidden"
      style={{ borderRadius: "var(--r-card)", background: "var(--card)", boxShadow: "var(--e1), var(--edge-card)" }}
    >
      {(search || filters || action) && (
        <TableToolbar
          ref={searchRef}
          searchValue={search?.value}
          onSearchChange={search?.onChange}
          searchPlaceholder={search?.placeholder}
          density={density}
          onDensityChange={setDensity}
          filters={filters}
          action={action}
        />
      )}

      {isMobile ? (
        <div role="list" aria-label={aria["aria-label"]} className="flex flex-col">
          {pageRows.map((row) => {
            const key = rowKey(row);
            const card = renderCardRow?.(row) ?? { title: columns[0]?.render(row) };
            const menuItems = rowMenu?.(row);
            return (
              <div
                key={key}
                role="listitem"
                className="flex items-center gap-3 px-4 py-3"
                style={{ borderBottom: "1px solid var(--hairline)" }}
                onClick={() => onRowOpen?.(row)}
              >
                <div className="flex-1 min-w-0">
                  <div className="type-body truncate">{card.title}</div>
                  {card.meta && (
                    <div className="type-body-s truncate" style={{ color: "var(--text-3)" }}>
                      {card.meta}
                    </div>
                  )}
                </div>
                {card.value && <div className="type-body-s shrink-0 tabular">{card.value}</div>}
                {menuItems && (
                  <div onClick={(e) => e.stopPropagation()}>
                    <RowMenuButton items={menuItems} label={rowMenuLabel?.(row)} />
                  </div>
                )}
              </div>
            );
          })}
        </div>
      ) : (
        <div className="overflow-x-auto">
          <table className="w-full" aria-label={aria["aria-label"]}>
            <thead>
              <tr>
                {columns.map((col) => (
                  <th
                    key={col.key}
                    className="group type-table-head px-4 h-10 select-none whitespace-nowrap"
                    style={{
                      color: "var(--text-3)",
                      textAlign: col.align ?? "left",
                      width: col.width,
                      cursor: col.sort ? "pointer" : "default",
                      borderBottom: "1px solid var(--hairline)",
                    }}
                    onClick={() => col.sort && toggleSort(col.key)}
                  >
                    <span className="inline-flex items-center gap-1.5">
                      {col.metricDot && (
                        <span
                          className="inline-block rounded-full shrink-0"
                          style={{ width: 6, height: 6, background: col.metricDot }}
                        />
                      )}
                      {col.header}
                      {col.sort && (
                        <Icon
                          name={sortDir === "desc" && sortKey === col.key ? "arrow_downward" : "arrow_upward"}
                          size={14}
                          className={sortKey === col.key ? "opacity-100" : "opacity-0 group-hover:opacity-40"}
                        />
                      )}
                    </span>
                  </th>
                ))}
                {rowMenu && <th className="w-10" style={{ borderBottom: "1px solid var(--hairline)" }} />}
              </tr>
            </thead>
            <tbody ref={bodyRef} onKeyDown={(e) => handleKeyDown(e, () => onRowOpen?.(pageRows[activeIndex]), () => setOpenRowMenu(activeIndex))}>
              {pageRows.map((row, i) => {
                const key = rowKey(row);
                const selected = key === selectedKey;
                const active = i === activeIndex;
                const menuItems = rowMenu?.(row);
                return (
                  <tr
                    key={key}
                    ref={(el) => {
                      rowRefs.current[i] = el;
                    }}
                    tabIndex={active ? 0 : -1}
                    data-selected={selected || undefined}
                    onClick={() => {
                      setActiveIndex(i);
                      onRowOpen?.(row);
                    }}
                    onFocus={() => setActiveIndex(i)}
                    className="lifey-table-row transition-colors"
                    style={{
                      height: ROW_HEIGHT[density],
                      cursor: onRowOpen ? "pointer" : "default",
                      background: selected ? "color-mix(in srgb, var(--primary) 8%, transparent)" : undefined,
                      // Composed with --shadow-focus (globals.css) — an inline
                      // box-shadow always beats the :focus-visible stylesheet rule.
                      boxShadow: selected
                        ? "inset 3px 0 0 0 var(--primary), var(--shadow-focus)"
                        : "var(--shadow-focus)",
                    }}
                  >
                    {columns.map((col) => (
                      <td
                        key={col.key}
                        className="type-body-s px-4 tabular"
                        style={{ textAlign: col.align ?? "left" }}
                      >
                        {col.render(row)}
                      </td>
                    ))}
                    {rowMenu && (
                      <td className="px-2" onClick={(e) => e.stopPropagation()}>
                        {menuItems && (
                          <RowMenuButton
                            items={menuItems}
                            label={rowMenuLabel?.(row)}
                            open={openRowMenu === i}
                            onOpenChange={(v) => setOpenRowMenu(v ? i : null)}
                          />
                        )}
                      </td>
                    )}
                  </tr>
                );
              })}
            </tbody>
          </table>
        </div>
      )}

      <TablePagination
        page={safePage}
        totalPages={totalPages}
        onPageChange={setPage}
        totalLabel={totalLabel?.(sorted.length)}
        from={sorted.length === 0 ? 0 : safePage * pageSize + 1}
        to={Math.min(safePage * pageSize + pageRows.length, sorted.length)}
      />
    </div>
  );
}
