"use client";

import { forwardRef, type ReactNode } from "react";
import { Icon } from "../Icon";
import { SegmentedControl } from "../SegmentedControl";
import type { TableDensity } from "./DataTable";

export interface TableToolbarProps {
  searchValue?: string;
  onSearchChange?: (value: string) => void;
  searchPlaceholder?: string;
  density: TableDensity;
  onDensityChange: (density: TableDensity) => void;
  /** Filter chips — whatever shape the caller's own filters take (D-W0.15). */
  filters?: ReactNode;
  /** The toolbar's primary action (e.g. "Add food"). */
  action?: ReactNode;
}

/**
 * DS-03's table toolbar (D-W0.15): a 320×40 search field (the table's own
 * `/` shortcut focuses it via the forwarded ref), filter chips, the
 * comfortable/compact density switch, and a primary action.
 */
export const TableToolbar = forwardRef<HTMLInputElement, TableToolbarProps>(function TableToolbar(
  { searchValue, onSearchChange, searchPlaceholder, density, onDensityChange, filters, action },
  searchRef,
) {
  return (
    <div className="flex flex-wrap items-center gap-3 p-4" style={{ borderBottom: "1px solid var(--hairline)" }}>
      {onSearchChange && (
        <div className="relative shrink-0" style={{ width: 320, maxWidth: "100%" }}>
          <Icon
            name="search"
            size={18}
            color="var(--text-3)"
            className="absolute left-3 top-1/2 -translate-y-1/2 pointer-events-none"
          />
          <input
            ref={searchRef}
            type="text"
            value={searchValue}
            onChange={(e) => onSearchChange(e.target.value)}
            placeholder={searchPlaceholder}
            className="lifey-field w-full type-body-s"
            style={{ height: 40, paddingLeft: 36, paddingRight: 12, borderRadius: "var(--r-control)" }}
          />
        </div>
      )}
      {filters}
      <div className="flex-1 min-w-0" />
      <SegmentedControl
        aria-label="Row density"
        size="sm"
        options={[
          { value: "comfortable", label: "Comfortable" },
          { value: "compact", label: "Compact" },
        ]}
        value={density}
        onChange={onDensityChange}
      />
      {action}
    </div>
  );
});
