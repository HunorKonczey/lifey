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

/**
 * Drives pagination/sorting from the server instead of DataTable's own
 * client-side slicing/sort. Pass this when `rows` is already just the current
 * page (e.g. a Spring `Page<T>` response) — DataTable then renders `rows`
 * as-is and delegates page/sort changes to the caller.
 */
export interface ServerPagination {
  page: number;
  totalPages: number;
  onPageChange: (page: number) => void;
  totalElements?: number;
  sortKey?: string | null;
  sortDir?: "asc" | "desc";
  onSortChange?: (key: string) => void;
}

interface DataTableProps<T> {
  columns: Column<T>[];
  rows: T[];
  rowKey: (row: T) => string | number;
  selectedKey?: string | number | null;
  onRowClick?: (row: T) => void;
  pageSize?: number;
  serverPagination?: ServerPagination;
}

export function DataTable<T>({
  columns, rows, rowKey, selectedKey, onRowClick, pageSize = 25, serverPagination,
}: DataTableProps<T>) {
  const [localSortKey, setLocalSortKey] = useState<string | null>(null);
  const [localSortDir, setLocalSortDir] = useState<"asc" | "desc">("asc");
  const [localPage, setLocalPage] = useState(0);

  const sortKey = serverPagination ? (serverPagination.sortKey ?? null) : localSortKey;
  const sortDir = serverPagination ? (serverPagination.sortDir ?? "asc") : localSortDir;

  const sorted = useMemo(() => {
    if (serverPagination) return rows;
    if (!sortKey) return rows;
    const col = columns.find((c) => c.key === sortKey);
    if (!col?.sortValue) return rows;
    const sv = col.sortValue;
    return [...rows].sort((a, b) => {
      const va = sv(a), vb = sv(b);
      const cmp = va < vb ? -1 : va > vb ? 1 : 0;
      return sortDir === "asc" ? cmp : -cmp;
    });
  }, [rows, sortKey, sortDir, columns, serverPagination]);

  const totalPages = serverPagination ? serverPagination.totalPages : Math.max(1, Math.ceil(sorted.length / pageSize));
  const safePage = serverPagination ? serverPagination.page : Math.min(localPage, totalPages - 1);
  const pageRows = serverPagination ? sorted : sorted.slice(safePage * pageSize, safePage * pageSize + pageSize);
  const totalCount = serverPagination ? (serverPagination.totalElements ?? sorted.length) : sorted.length;

  const goToPage = (next: number) => {
    if (serverPagination) {
      serverPagination.onPageChange(next);
    } else {
      setLocalPage(next);
    }
  };

  const toggleSort = (key: string) => {
    if (serverPagination) {
      serverPagination.onSortChange?.(key);
      return;
    }
    if (sortKey === key) {
      setLocalSortDir((d) => (d === "asc" ? "desc" : "asc"));
    } else {
      setLocalSortKey(key);
      setLocalSortDir("asc");
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
      {totalPages > 1 && (
        <div className="flex items-center justify-between mt-3 text-sm" style={{ color: "var(--on-surface-variant)" }}>
          <span className="tabular">
            {safePage * pageSize + 1}–{Math.min(safePage * pageSize + pageRows.length, totalCount)} of {totalCount}
          </span>
          <div className="flex items-center gap-1">
            <button
              onClick={() => goToPage(Math.max(0, safePage - 1))}
              disabled={safePage === 0}
              className="p-1 rounded-[var(--r-sm)] disabled:opacity-40 transition-colors hover:bg-surface-container"
              aria-label="Previous page"
            >
              <span className="material-symbols-rounded text-xl">chevron_left</span>
            </button>
            <span className="tabular px-2">{safePage + 1} / {totalPages}</span>
            <button
              onClick={() => goToPage(Math.min(totalPages - 1, safePage + 1))}
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
