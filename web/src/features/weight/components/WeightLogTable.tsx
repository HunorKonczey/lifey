"use client";

import { useTranslations } from "next-intl";
import { DataTable, DeltaChip } from "@/components/ds";
import type { DataTableColumn } from "@/components/ds";
import type { MenuItemDef } from "@/components/ds/Menu";
import { useFormat } from "@/lib/format/useFormat";
import { logDateLabel, weightLogRows, type WeightLogRow } from "../logTable";
import { parseLocalDate } from "../trend";
import type { WeightResponse } from "../types";

/**
 * The weight log (W4.3, W4-A, client-018): below the chart, full width — Dátum ("Péntek, szept. 26."), Súly,
 * Változás (a `DeltaChip` against the previous entry; a move toward the goal is green, away from it the heart
 * colour, neutral without a goal) and one "⋯" per row: Szerkesztés, Törlés…. No note column (D-W0.19). Rows are cards
 * under 768 px.
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
  const rows = weightLogRows(weights);
  const latest = weights.length > 0 ? [...weights].sort((a, b) => a.date.localeCompare(b.date) || a.id - b.id).at(-1)! : null;
  const goalDirection = goalKg == null || latest == null ? undefined : goalKg < latest.weight ? "lower" : "higher";
  const dateText = (r: WeightLogRow) => logDateLabel(parseLocalDate(r.entry.date), fmt.locale, fmt.shortDate);

  const columns: DataTableColumn<WeightLogRow>[] = [
    { key: "date", header: t("colDate"), sort: (r) => r.entry.date + String(r.entry.id).padStart(10, "0"), render: (r) => <span style={{ fontWeight: 700 }}>{dateText(r)}</span> },
    { key: "weight", header: t("colWeight"), align: "right", sort: (r) => r.entry.weight, render: (r) => <span className="tabular">{fmt.weight(r.entry.weight)}</span> },
    {
      key: "change",
      header: t("colChange"),
      align: "right",
      sort: (r) => r.delta ?? 0,
      render: (r) => (r.delta == null ? <span style={{ color: "var(--text-3)" }}>—</span> : <DeltaChip value={r.delta} unit="kg" goalDirection={goalDirection} />),
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
        pageSize={10}
        totalLabel={(n) => t("totalEntries", { count: n })}
        renderCardRow={(r) => ({
          title: dateText(r),
          meta: r.delta == null ? undefined : fmt.signedDelta(r.delta, { unit: "kg" }),
          value: fmt.weight(r.entry.weight),
        })}
      />
    </div>
  );
}
