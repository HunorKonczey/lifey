"use client";

import { useState } from "react";
import { useTranslations } from "next-intl";
import { Button, DataTable, DeltaChip } from "@/components/ds";
import { useMediaQuery } from "@/lib/hooks/useMediaQuery";
import type { DataTableColumn } from "@/components/ds";
import type { MenuItemDef } from "@/components/ds/Menu";
import { useFormat } from "@/lib/format/useFormat";
import { logDateLabel, weightLogRows, weightTakenAt, type WeightLogRow } from "../logTable";
import { parseLocalDate } from "../trend";
import type { WeightResponse } from "../types";

/**
 * The weight log (W4.3, W4-A, client-018): below the chart, full width — Dátum ("Péntek, szept. 26."), Súly,
 * Változás (a `DeltaChip` against the previous entry; a move toward the goal is green, away from it the heart
 * colour, neutral without a goal), the note (LIF-115; D-W0.19 left it out until the API stored one) and one "⋯" per row:
 * Szerkesztés, Törlés…. The time the weigh-in was taken sits under the date (only when it was taken on that day). Rows are
 * cards under 768 px.
 */
export function WeightLogTable({
  weights,
  goalKg,
  onEdit,
  onDelete,
}: {
  weights: WeightResponse[];
  goalKg: number | null;
  onEdit?: (entry: WeightResponse) => void;
  onDelete: (entry: WeightResponse) => void;
}) {
  const t = useTranslations("weight");
  const fmt = useFormat();
  const phone = useMediaQuery("(max-width: 767px)");
  // On a phone (W4-D) the log is a short list — the last three weigh-ins — with "Mind" for the rest.
  const [showAll, setShowAll] = useState(false);
  const allRows = weightLogRows(weights);
  const short = phone && !showAll && allRows.length > 3;
  const rows = short ? allRows.slice(0, 3) : allRows;
  const latest = weights.length > 0 ? [...weights].sort((a, b) => a.date.localeCompare(b.date) || a.id - b.id).at(-1)! : null;
  const goalDirection = goalKg == null || latest == null ? undefined : goalKg < latest.weight ? "lower" : "higher";
  const dateText = (r: WeightLogRow) => logDateLabel(parseLocalDate(r.entry.date), fmt.locale, fmt.shortDate);
  const timeText = (r: WeightLogRow) => {
    const taken = weightTakenAt(r.entry);
    return taken ? fmt.time(taken) : null;
  };

  const columns: DataTableColumn<WeightLogRow>[] = [
    { key: "date", header: t("colDate"), sort: (r) => r.entry.date + String(r.entry.id).padStart(10, "0"), render: (r) => (
        <span className="flex flex-col">
          <span style={{ fontWeight: 700 }}>{dateText(r)}</span>
          {timeText(r) && (
            <span className="type-body-s tabular" data-testid="weight-time" style={{ color: "var(--text-3)" }}>
              {timeText(r)}
            </span>
          )}
        </span>
      ),
    },
    { key: "weight", header: t("colWeight"), align: "right", sort: (r) => r.entry.weight, render: (r) => <span className="tabular">{fmt.weight(r.entry.weight)}</span> },
    {
      key: "change",
      header: t("colChange"),
      align: "right",
      width: 150,
      sort: (r) => r.delta ?? 0,
      render: (r) => (r.delta == null ? <span style={{ color: "var(--text-3)" }}>—</span> : <span className="inline-block whitespace-nowrap"><DeltaChip value={r.delta} unit="kg" goalDirection={goalDirection} /></span>),
    },
    {
      key: "note",
      header: t("colNote"),
      render: (r) =>
        r.entry.note ? (
          <span data-testid="weight-note-cell" style={{ color: "var(--text-2)" }}>
            {r.entry.note}
          </span>
        ) : (
          <span style={{ color: "var(--text-3)" }}>—</span>
        ),
    },
  ];

  const rowMenu = (r: WeightLogRow): MenuItemDef[] => [
    ...(onEdit ? [{ label: t("menuEdit"), icon: "edit", onSelect: () => onEdit(r.entry) }] : []),
    { label: t("menuDelete"), icon: "delete", destructive: true, onSelect: () => onDelete(r.entry) },
  ];

  return (
    <div data-testid="weight-log">
      <DataTable
        aria-label={t("logAria")}
        columns={columns}
        rows={rows}
        rowKey={(r) => r.entry.id}
        rowMenu={rowMenu}
        rowMenuLabel={(r) => t("rowMenuLabel", { date: dateText(r) })}
        pageSize={short ? 3 : 10}
        totalLabel={(n) => t("totalEntries", { count: short ? allRows.length : n })}
        renderCardRow={(r) => ({
          title: timeText(r) ? `${dateText(r)} · ${timeText(r)}` : dateText(r),
          meta: [r.delta == null ? null : fmt.signedDelta(r.delta, { unit: "kg" }), r.entry.note].filter(Boolean).join(" · ") || undefined,
          value: fmt.weight(r.entry.weight),
        })}
      />
      {short && (
        <Button variant="ghost" className="mt-2 w-full" onClick={() => setShowAll(true)}>
          {t("showAllEntries", { count: allRows.length })}
        </Button>
      )}
    </div>
  );
}
