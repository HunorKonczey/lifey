"use client";

import { useTranslations } from "next-intl";
import { Icon } from "../Icon";

export interface TablePaginationProps {
  page: number;
  totalPages: number;
  onPageChange: (page: number) => void;
  /** e.g. "18 foods" — the caller's own pluralized entity-count copy. */
  totalLabel?: string;
  from: number;
  to: number;
}

/** DS-03's table footer (D-W0.15): "18 foods · 1–5" plus page buttons. */
export function TablePagination({ page, totalPages, onPageChange, totalLabel, from, to }: TablePaginationProps) {
  const t = useTranslations("common");

  return (
    <div className="flex flex-wrap items-center justify-between gap-3 px-4 py-3" style={{ borderTop: "1px solid var(--hairline)" }}>
      <span className="type-body-s tabular" style={{ color: "var(--text-3)" }}>
        {totalLabel ? `${totalLabel} · ` : ""}
        {t("rowRange", { from, to })}
      </span>
      {totalPages > 1 && (
        <div className="flex items-center gap-1">
          <button
            type="button"
            onClick={() => onPageChange(Math.max(0, page - 1))}
            disabled={page === 0}
            aria-label={t("previousPage")}
            className="lifey-button inline-flex items-center justify-center rounded-[var(--r-control)] disabled:opacity-40"
            style={{ width: 32, height: 32, background: "transparent", color: "var(--text)" }}
          >
            <Icon name="chevron_left" size={20} />
          </button>
          <span className="type-body-s tabular px-1">
            {page + 1} / {totalPages}
          </span>
          <button
            type="button"
            onClick={() => onPageChange(Math.min(totalPages - 1, page + 1))}
            disabled={page >= totalPages - 1}
            aria-label={t("nextPage")}
            className="lifey-button inline-flex items-center justify-center rounded-[var(--r-control)] disabled:opacity-40"
            style={{ width: 32, height: 32, background: "transparent", color: "var(--text)" }}
          >
            <Icon name="chevron_right" size={20} />
          </button>
        </div>
      )}
    </div>
  );
}
