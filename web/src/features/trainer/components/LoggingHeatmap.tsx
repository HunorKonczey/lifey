"use client";

import { useLocale, useTranslations } from "next-intl";
import { Card } from "@/components/ds";
import { useFormat } from "@/lib/format/useFormat";
import type { ActivityKind, HeatCell, HeatWeek } from "../clientActivity";

const COLOR: Record<ActivityKind, string> = {
  meal: "var(--metric-kcal)",
  workout: "var(--primary)",
  weight: "var(--metric-weight)",
};

const KINDS: ActivityKind[] = ["meal", "workout", "weight"];

/**
 * "Naplózás · elmúlt 4 hét" (W7-B): four weeks by seven days, a dot per kind logged that day — meal, workout, weigh-in —
 * today ringed. A real table, and each cell names its day and what happened ("szept. 21., hétfő: étkezés, edzés"), so
 * it reads without the colours.
 */
export function LoggingHeatmap({ weeks }: { weeks: HeatWeek[] }) {
  const t = useTranslations("admin.clientDetail.overview");
  const locale = useLocale();
  const fmt = useFormat();
  const weekday = new Intl.DateTimeFormat(locale, { weekday: "long" });
  const kindLabel = (k: ActivityKind) => t(`kind_${k}`);

  const cellLabel = (c: HeatCell) => {
    const d = new Date(c.date + "T00:00:00");
    const base = `${fmt.shortDate(d)}, ${weekday.format(d)}`;
    if (c.isFuture) return base;
    return c.kinds.length ? `${base}: ${c.kinds.map(kindLabel).join(", ")}` : `${base}: ${t("nothingLogged")}`;
  };

  return (
    <Card variant="card" className="flex flex-col gap-4" data-testid="logging-heatmap">
      <div className="flex flex-wrap items-center justify-between gap-3">
        <h3 style={{ fontSize: 18, fontWeight: 800 }}>{t("heatmapTitle")}</h3>
        <ul className="flex items-center gap-4 type-body-s" style={{ color: "var(--text-2)" }} aria-label={t("legendAria")}>
          {KINDS.map((k) => (
            <li key={k} className="inline-flex items-center gap-1.5">
              <span style={{ width: 8, height: 8, borderRadius: 999, background: COLOR[k] }} />
              {kindLabel(k)}
            </li>
          ))}
        </ul>
      </div>
      <table className="w-full" style={{ borderCollapse: "separate", borderSpacing: 6 }}>
        <thead>
          <tr>
            <th scope="col" className="sr-only">{t("weekColumn")}</th>
            {weeks[0]?.cells.map((c) => (
              <th key={c.date} scope="col" className="type-body-s" style={{ color: "var(--text-3)", fontWeight: 600 }}>
                {fmt.weekdayShort(new Date(c.date + "T00:00:00"))}
              </th>
            ))}
          </tr>
        </thead>
        <tbody>
          {weeks.map((w) => (
            <tr key={w.weekStart}>
              <th scope="row" className="type-body-s text-left whitespace-nowrap pr-2" style={{ color: "var(--text-3)", fontWeight: 600 }}>
                {fmt.shortDate(new Date(w.weekStart + "T00:00:00"))}
              </th>
              {w.cells.map((c) => (
                <td key={c.date} className="p-0">
                  <div
                    role="img"
                    aria-label={cellLabel(c)}
                    className="flex items-center justify-center gap-[3px] mx-auto"
                    style={{
                      height: 40,
                      borderRadius: 10,
                      background: c.isFuture ? "transparent" : "var(--nested)",
                      boxShadow: c.isToday ? "inset 0 0 0 2px var(--primary)" : c.isFuture ? "inset 0 0 0 1px var(--hairline)" : undefined,
                    }}
                  >
                    {c.kinds.map((k) => (
                      <span key={k} style={{ width: 7, height: 7, borderRadius: 999, background: COLOR[k] }} />
                    ))}
                  </div>
                </td>
              ))}
            </tr>
          ))}
        </tbody>
      </table>
    </Card>
  );
}
