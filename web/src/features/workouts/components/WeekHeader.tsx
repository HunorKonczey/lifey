import { useTranslations } from "next-intl";
import type { SessionWeek } from "../sessionGroups";
import { weekRangeLabel, weekSummaryParts } from "../weekLabels";
import { useFormat } from "@/lib/i18n/format";

/**
 * The header over one week of the sessions list (W3.3, W3-A): "Ez a hét · szept. 22–27." on the left and
 * "4 edzés · 3 ó 12 p · 19 360 kg · 20 km" on the right. The current and previous week are named; older
 * weeks show just their dates.
 */
export function WeekHeader({ week }: { week: SessionWeek }) {
  const t = useTranslations("workouts");
  const { locale } = useFormat();
  const range = weekRangeLabel(week.weekStart, week.weekEnd, locale);
  const name = week.kind === "thisWeek" ? t("weekThis") : week.kind === "lastWeek" ? t("weekLast") : null;
  const summary = [t("weekCount", { count: week.summary.count }), ...weekSummaryParts(week.summary, locale)].join(" · ");

  return (
    <div className="flex flex-wrap items-baseline justify-between gap-x-4 gap-y-1 px-1">
      <h3 className="type-title-s">
        {name ? `${name} · ` : ""}
        <span style={name ? { color: "var(--text-3)", fontWeight: 600 } : undefined}>{range}</span>
      </h3>
      <p className="type-body-s tabular" style={{ color: "var(--text-2)" }}>
        {summary}
      </p>
    </div>
  );
}
