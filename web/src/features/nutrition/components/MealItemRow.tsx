"use client";

import { useTranslations } from "next-intl";
import { RowMenuButton } from "@/components/ds/RowMenuButton";
import type { MenuItemDef } from "@/components/ds/Menu";
import { useFormat } from "@/lib/format/useFormat";

export interface MealItemRowData {
  name: string;
  grams: number;
  kcal: number;
  protein: number;
  carbs: number;
  fat: number;
}

const MACROS = [
  { key: "protein", color: "var(--metric-protein)" },
  { key: "carbs", color: "var(--metric-carbs)" },
  { key: "fat", color: "var(--metric-fat)" },
] as const;

/**
 * One food in a meal card (W2.3): the name — which wraps to a second line,
 * never truncates — with its quantity under it ("150 g" only), then P / C / F
 * each behind an 8 px dot in its metric colour (carbs and fat always visible),
 * the kcal, and a row "⋯" that appears on hover *and* on focus so it is
 * reachable from the keyboard. A 4-column grid from 768; on a phone the
 * macros and kcal drop under the name.
 */
export function MealItemRow({ item, menu }: { item: MealItemRowData; menu?: MenuItemDef[] }) {
  const t = useTranslations("nutrition");
  const d = useTranslations("dashboard");
  const fmt = useFormat();

  return (
    <div
      className="meal-item-row group grid items-center gap-x-3 gap-y-1 py-2.5 pl-[74px] pr-4 md:grid-cols-[minmax(0,1fr)_220px_80px_36px]"
      style={{ borderTop: "1px solid var(--hairline)" }}
    >
      <div className="min-w-0">
        <p style={{ fontSize: 15, fontWeight: 700, overflowWrap: "anywhere", hyphens: "auto" }}>{item.name}</p>
        <p className="type-body-s tabular" style={{ color: "var(--text-3)" }}>
          {fmt.grams(item.grams)}
        </p>
      </div>

      <dl className="flex items-center gap-4 tabular md:gap-0" style={{ fontSize: 13, fontWeight: 600 }}>
        {MACROS.map(({ key, color }) => (
          <div key={key} className="flex items-center gap-1.5 md:w-[72px]">
            <dt className="sr-only">{d(key)}</dt>
            <span aria-hidden className="shrink-0" style={{ width: 8, height: 8, borderRadius: 999, background: color }} />
            <dd style={{ color: "var(--text-2)" }}>{fmt.integer(item[key], "g")}</dd>
          </div>
        ))}
      </dl>

      <p className="tabular md:text-right" style={{ fontSize: 15, fontWeight: 700 }}>
        {fmt.integer(item.kcal)}{" "}
        <span className="md:sr-only type-body-s" style={{ color: "var(--text-3)", fontWeight: 600 }}>
          kcal
        </span>
      </p>

      <div className="flex justify-end opacity-0 transition-opacity focus-within:opacity-100 group-hover:opacity-100 max-md:opacity-100">
        {menu && menu.length > 0 && <RowMenuButton items={menu} label={t("itemMenuLabel")} />}
      </div>
    </div>
  );
}
