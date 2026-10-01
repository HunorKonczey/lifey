"use client";

import { useState } from "react";
import { useTranslations } from "next-intl";
import { Button, DataTable, Icon } from "@/components/ds";
import type { DataTableColumn } from "@/components/ds";
import type { MenuItemDef } from "@/components/ds/Menu";
import { EmptyState } from "@/components/status/EmptyState";
import { useFormat } from "@/lib/format/useFormat";
import { useFormat as useNumberFormat } from "@/lib/i18n/format";
import { matchesFoodSearch } from "../foodsTable";
import type { FoodUsage } from "../usage";
import type { FoodResponse } from "../types";

export interface FoodsTableProps {
  foods: FoodResponse[];
  /** Per-food meal history, for "Utoljára". */
  usage: Map<number, FoodUsage>;
  /** "Today" for the relative day — passed in so the table stays pure. */
  now: Date;
  selectedId: number | null;
  onOpen: (food: FoodResponse) => void;
  onNew: () => void;
  onDuplicate: (food: FoodResponse) => void;
  onLogToday: (food: FoodResponse) => void;
  onDelete: (food: FoodResponse) => void;
}

/**
 * The foods table (W2.10, extra-004): the DS `DataTable` with every column sortable — name, kcal per
 * 100 g, the three macros (each headed by its metric dot) and when the food was last logged — a search
 * box (focused by `/`), "＋ Új étel", and one "⋯" per row: Edit, Duplicate, Log today, Delete….
 */
export function FoodsTable({ foods, usage, now, selectedId, onOpen, onNew, onDuplicate, onLogToday, onDelete }: FoodsTableProps) {
  const t = useTranslations("nutrition.foodsView");
  const fmt = useFormat();
  const nf = useNumberFormat();
  const [search, setSearch] = useState("");

  const rows = search.trim() === "" ? foods : foods.filter((f) => matchesFoodSearch(f.name, search));
  const gramValue = (v: number | null) => (v == null ? "—" : `${nf.number(v)} g`);

  const columns: DataTableColumn<FoodResponse>[] = [
    {
      key: "name",
      header: t("colName"),
      sort: (f) => f.name.toLocaleLowerCase(),
      render: (f) => <span style={{ fontWeight: 700 }}>{f.name}</span>,
    },
    {
      key: "kcal",
      header: t("colKcal"),
      align: "right",
      metricDot: "var(--m-kcal)",
      sort: (f) => f.caloriesPer100g,
      render: (f) => fmt.integer(f.caloriesPer100g),
    },
    {
      key: "protein",
      header: t("colProtein"),
      align: "right",
      metricDot: "var(--m-protein)",
      sort: (f) => f.proteinPer100g,
      render: (f) => gramValue(f.proteinPer100g),
    },
    {
      key: "carbs",
      header: t("colCarbs"),
      align: "right",
      metricDot: "var(--m-carbs)",
      sort: (f) => f.carbsPer100g ?? 0,
      render: (f) => gramValue(f.carbsPer100g),
    },
    {
      key: "fat",
      header: t("colFat"),
      align: "right",
      metricDot: "var(--m-fat)",
      sort: (f) => f.fatPer100g ?? 0,
      render: (f) => gramValue(f.fatPer100g),
    },
    {
      key: "last",
      header: t("colLast"),
      align: "right",
      // Never-logged foods are the oldest: they sort below every dated one when descending.
      sort: (f) => usage.get(f.id)?.lastUsedAt ?? -1,
      render: (f) => {
        const u = usage.get(f.id);
        return u ? <span style={{ color: "var(--text-2)" }}>{fmt.relativeDay(new Date(u.lastUsedAt), now)}</span> : <span style={{ color: "var(--text-3)" }}>{t("lastNever")}</span>;
      },
    },
  ];

  const rowMenu = (f: FoodResponse): MenuItemDef[] => [
    { label: t("menuEdit"), icon: "edit", onSelect: () => onOpen(f) },
    { label: t("menuDuplicate"), icon: "content_copy", onSelect: () => onDuplicate(f) },
    { label: t("menuLogToday"), icon: "add_circle", onSelect: () => onLogToday(f) },
    { label: t("menuDelete"), icon: "delete", destructive: true, onSelect: () => onDelete(f) },
  ];

  return (
    <div className="flex flex-col gap-4" data-testid="foods-table">
      <DataTable
        aria-label={t("tableAria")}
        columns={columns}
        rows={rows}
        rowKey={(f) => f.id}
        selectedKey={selectedId}
        onRowOpen={onOpen}
        rowMenu={rowMenu}
        rowMenuLabel={(f) => t("rowMenuLabel", { food: f.name })}
        pageSize={15}
        search={{ value: search, onChange: setSearch, placeholder: t("searchPlaceholder") }}
        totalLabel={(n) => t("totalFoods", { count: n })}
        action={
          <Button onClick={onNew}>
            <Icon name="add" size={20} />
            {t("newFood")}
          </Button>
        }
        renderCardRow={(f) => ({
          title: f.name,
          meta: t("cardMacros", { protein: nf.number(f.proteinPer100g), carbs: nf.number(f.carbsPer100g ?? 0), fat: nf.number(f.fatPer100g ?? 0) }),
          value: `${fmt.integer(f.caloriesPer100g)} kcal`,
        })}
      />
      {rows.length === 0 && (
        <EmptyState compact icon="nutrition" title={t("noMatch")} body={t("tryDifferentSearch")} />
      )}
    </div>
  );
}
