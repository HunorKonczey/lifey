"use client";

import { useTranslations } from "next-intl";
import { format } from "date-fns";
import { enUS, hu } from "date-fns/locale";
import { useLocale } from "@/lib/hooks/useLocale";
import type { DayOfWeek, Recurrence } from "../types";

const DATE_LOCALES = { en: enUS, hu } as const;

/** "Mon" / "Mon and Thu" / "Mon, Wed and Thu" (or the HU equivalent with "és"). */
function joinWithAnd(items: string[], and: string): string {
  if (items.length <= 1) return items.join("");
  if (items.length === 2) return `${items[0]} ${and} ${items[1]}`;
  return `${items.slice(0, -1).join(", ")} ${and} ${items[items.length - 1]}`;
}

interface RecurrenceLabelProps {
  recurrence: Recurrence;
  daysOfWeek: DayOfWeek[];
  timeOfDay: string | null;
  startDate: string;
  endDate: string;
}

/** Formats e.g. "Every Mon, Thu · 18:00 · Jul 7 – Oct 6" (design: A frame). */
export function RecurrenceLabel({ recurrence, daysOfWeek, timeOfDay, startDate, endDate }: RecurrenceLabelProps) {
  const t = useTranslations("admin.schedule");
  const dateLocale = DATE_LOCALES[useLocale((s) => s.locale)];

  const start = format(new Date(`${startDate}T00:00:00`), "MMM d.", { locale: dateLocale });
  const end = format(new Date(`${endDate}T00:00:00`), "MMM d.", { locale: dateLocale });
  const time = timeOfDay ? timeOfDay.slice(0, 5) : null;

  const parts: string[] = [];
  if (recurrence === "ONCE") {
    parts.push(start);
  } else {
    parts.push(
      recurrence === "DAILY"
        ? t("recurrence.daily")
        : `${t("recurrence.weeklyPrefix")} ${joinWithAnd(daysOfWeek.map((d) => t(`days.${d}`)), t("and"))}`,
    );
  }
  if (time) parts.push(time);
  if (recurrence !== "ONCE") parts.push(`${start} – ${end}`);

  return <>{parts.join(" · ")}</>;
}
