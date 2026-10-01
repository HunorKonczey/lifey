"use client";

import { useTranslations } from "next-intl";
import { Card, Icon } from "@/components/ds";
import { RowMenuButton } from "@/components/ds/RowMenuButton";
import { useFormat } from "@/lib/format/useFormat";
import type { WaterEntryResponse } from "../types";

/** A drink's icon: hot drinks get a cup, everything else a drop. */
export function drinkIcon(name: string | null): string {
  return name && /\b(tea|tee|t[eé]a|coffee|k[aá]v[eé]|espresso|latte)\b/i.test(name) ? "coffee" : "water_drop";
}

/**
 * "Mai bejegyzések" (W4.5, W4-B, client-022): the day's drinks, newest first — an icon per source, "Tea · 14:10", the
 * amount ("0,3 L") and a "⋯" whose "Törlés…" asks first and is undoable. `title` names the day when it is not today.
 */
export function WaterEntriesList({
  entries,
  title,
  onDelete,
}: {
  entries: WaterEntryResponse[];
  title: string;
  onDelete: (entry: WaterEntryResponse) => void;
}) {
  const t = useTranslations("water");
  const fmt = useFormat();
  const sorted = [...entries].sort((a, b) => new Date(b.consumedAt).getTime() - new Date(a.consumedAt).getTime());

  return (
    <Card className="flex flex-col gap-2" data-testid="water-entries">
      <h2 className="type-title-s">{title}</h2>
      {sorted.length === 0 ? (
        <p className="type-body-s py-6 text-center" style={{ color: "var(--text-3)" }}>
          {t("noEntriesToday")}
        </p>
      ) : (
        <ul className="flex flex-col">
          {sorted.map((e) => {
            const label = e.sourceName ?? t("entryLabel");
            return (
              <li key={e.id} className="flex items-center gap-3 py-2" data-testid="water-entry" style={{ borderTop: "1px solid var(--hairline)" }}>
                <span
                  className="flex flex-none items-center justify-center"
                  style={{ width: 36, height: 36, borderRadius: 12, background: "color-mix(in srgb, var(--m-water) var(--chip-tint), transparent)", color: "var(--m-water)" }}
                >
                  <Icon name={drinkIcon(e.sourceName)} size={20} />
                </span>
                <span className="type-body-s min-w-0 flex-1 truncate">
                  <span style={{ fontWeight: 700 }}>{label}</span>
                  <span style={{ color: "var(--text-3)" }}> · {fmt.time(new Date(e.consumedAt))}</span>
                </span>
                <span className="type-body tabular" style={{ fontWeight: 700 }}>
                  {fmt.litres(e.volumeLiters)}
                </span>
                <RowMenuButton
                  label={t("entryMenuLabel", { name: label })}
                  items={[{ label: t("menuDelete"), icon: "delete", destructive: true, onSelect: () => onDelete(e) }]}
                />
              </li>
            );
          })}
        </ul>
      )}
    </Card>
  );
}
