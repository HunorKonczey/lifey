"use client";

import { useTranslations } from "next-intl";
import { Card, Icon } from "@/components/ds";
import { useFormat } from "@/lib/format/useFormat";
import type { FeedEvent } from "../clientActivity";

const ICON: Record<FeedEvent["kind"], { icon: string; color: string }> = {
  record: { icon: "emoji_events", color: "var(--metric-carbs)" },
  workout: { icon: "fitness_center", color: "var(--primary)" },
  meal: { icon: "restaurant", color: "var(--metric-kcal)" },
  weight: { icon: "monitor_weight", color: "var(--metric-weight)" },
};

/** "Legutóbb" (W7-B): the latest few things the client did — a record, a workout, a meal, a weigh-in — with relative times. */
export function ActivityFeed({ events }: { events: FeedEvent[] }) {
  const t = useTranslations("admin.clientDetail.overview");
  const fmt = useFormat();
  const now = new Date();

  const text = (e: FeedEvent) => {
    switch (e.kind) {
      case "record":
        return t("feedRecord", { exercise: e.exerciseName, weight: fmt.number(e.weight, 1), reps: e.reps });
      case "workout":
        return e.name ? t("feedWorkoutNamed", { name: e.name }) : t("feedWorkout");
      case "meal":
        return e.name ? t("feedMealNamed", { name: e.name }) : t("feedMeal");
      case "weight":
        return t("feedWeight", { weight: fmt.number(e.weightKg, 1) });
    }
  };

  return (
    <Card variant="card" className="flex flex-col gap-3">
      <h3 style={{ fontSize: 18, fontWeight: 800 }}>{t("feedTitle")}</h3>
      {events.length === 0 ? (
        <p className="type-body-s" style={{ color: "var(--text-2)" }}>{t("feedEmpty")}</p>
      ) : (
        <ul className="flex flex-col gap-2.5">
          {events.map((e, i) => (
            <li key={i} className="flex items-center gap-3">
              <span
                className="inline-flex items-center justify-center shrink-0"
                style={{ width: 32, height: 32, borderRadius: 10, background: `color-mix(in srgb, ${ICON[e.kind].color} 16%, transparent)` }}
              >
                <Icon name={ICON[e.kind].icon} size={18} fill={1} color={ICON[e.kind].color} />
              </span>
              <span className="flex-1 min-w-0 truncate" style={{ fontWeight: 600 }}>{text(e)}</span>
              <span className="type-body-s shrink-0" style={{ color: "var(--text-3)" }}>{fmt.relative(e.at, now)}</span>
            </li>
          ))}
        </ul>
      )}
    </Card>
  );
}
