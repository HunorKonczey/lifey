"use client";

import { useMemo, useState } from "react";

export interface Column<T> {
  key: string;
  header: string;
  sortable?: boolean;
  align?: "left" | "right";
  color?: string;
  render: (row: T) => React.ReactNode;
  sortValue?: (row: T) => string | number;
}

interface DataTableProps<T> {
  columns: Column<T>[];
  rows: T[];
  rowKey: (row: T) => string | number;
  selectedKey?: string | number | null;
  onRowClick?: (row: T) => void;
  pageSize?: number;
}

export function DataTable<T>({
  columns, rows, rowKey, selectedKey, onRowClick, pageSize = 25,
}: DataTableProps<T>) {
  const [sortKey, setSortKey] = useState<string | null>(null);
  const [sortDir, setSortDir] = useState<"asc" | "desc">("asc");
  const [page, setPage] = useState(0);

  const sorted = useMemo(() => {
    if (!sortKey) return rows;
    const col = columns.find((c) => c.key === sortKey);
    if (!col?.sortValue) return rows;
    const sv = col.sortValue;
    return [...rows].sort((a, b) => {
      const va = sv(a), vb = sv(b);
      const cmp = va < vb ? -1 : va > vb ? 1 : 0;
      return sortDir === "asc" ? cmp : -cmp;
    });
  }, [rows, sortKey, sortDir, columns]);

  const totalPages = Math.max(1, Math.ceil(sorted.length / pageSize));
  const safePage = Math.min(page, totalPages - 1);
  const pageRows = sorted.slice(safePage * pageSize, safePage * pageSize + pageSize);

  const toggleSort = (key: string) => {
    if (sortKey === key) {
      setSortDir((d) => (d === "asc" ? "desc" : "asc"));
    } else {
      setSortKey(key);
      setSortDir("asc");
    }
  };

  return (
    <div className="flex flex-col">
      <div className="overflow-x-auto rounded-[var(--r-card)]" style={{ background: "var(--surface)" }}>
        <table className="w-full text-sm">
          <thead>
            <tr style={{ borderBottom: "1px solid var(--outline)" }}>
              {columns.map((col) => (
                <th
                  key={col.key}
                  className="px-4 py-3 font-semibold"
                  style={{
                    color: "var(--on-surface-variant)",
                    textAlign: col.align ?? "left",
                    cursor: col.sortable ? "pointer" : "default",
                  }}
                  onClick={() => col.sortable && toggleSort(col.key)}
                >
                  <span className="inline-flex items-center gap-1">
                    {col.header}
                    {col.sortable && sortKey === col.key && (
                      <span className="material-symbols-rounded text-sm">
                        {sortDir === "asc" ? "arrow_upward" : "arrow_downward"}
                      </span>
                    )}
                  </span>
                </th>
              ))}
            </tr>
          </thead>
          <tbody>
            {pageRows.map((row) => {
              const key = rowKey(row);
              const selected = key === selectedKey;
              return (
                <tr
                  key={key}
                  onClick={() => onRowClick?.(row)}
                  className="transition-colors"
                  style={{
                    borderBottom: "1px solid var(--outline)",
                    background: selected ? "color-mix(in srgb, var(--primary) 12%, transparent)" : "transparent",
                    cursor: onRowClick ? "pointer" : "default",
                  }}
                >
                  {columns.map((col) => (
                    <td
                      key={col.key}
                      className="px-4 py-3 tabular"
                      style={{ textAlign: col.align ?? "left", color: col.color }}
                    >
                      {col.render(row)}
                    </td>
                  ))}
                </tr>
              );
            })}
          </tbody>
        </table>
      </div>

      {/* Pagination */}
      {sorted.length > pageSize && (
        <div className="flex items-center justify-between mt-3 text-sm" style={{ color: "var(--on-surface-variant)" }}>
          <span className="tabular">
            {safePage * pageSize + 1}–{Math.min((safePage + 1) * pageSize, sorted.length)} of {sorted.length}
          </span>
          <div className="flex items-center gap-1">
            <button
              onClick={() => setPage((p) => Math.max(0, p - 1))}
              disabled={safePage === 0}
              className="p-1 rounded-[var(--r-sm)] disabled:opacity-40 transition-colors hover:bg-surface-container"
              aria-label="Previous page"
            >
              <span className="material-symbols-rounded text-xl">chevron_left</span>
            </button>
            <span className="tabular px-2">{safePage + 1} / {totalPages}</span>
            <button
              onClick={() => setPage((p) => Math.min(totalPages - 1, p + 1))}
              disabled={safePage >= totalPages - 1}
              className="p-1 rounded-[var(--r-sm)] disabled:opacity-40 transition-colors hover:bg-surface-container"
              aria-label="Next page"
            >
              <span className="material-symbols-rounded text-xl">chevron_right</span>
            </button>
          </div>
        </div>
      )}
    </div>
  );
}
