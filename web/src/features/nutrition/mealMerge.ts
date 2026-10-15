import { logTimestampFor } from "@/lib/utils/logTime";
import { entryRequestOf } from "./mealEntry";
import type { MealEntryRequest, MealRequest, MealResponse, MealType } from "./types";

/** What an add to the day's meals boils down to: start a meal, or rewrite an existing one with more entries. */
export type MealWrite =
  | { kind: "create"; body: MealRequest }
  | { kind: "update"; id: number; body: MealRequest };

/**
 * Where new entries go when something is added to a meal type of one day (docs/87 §2.7): into the day's latest
 * *plain* meal of that type (the one with no name — a recipe logged as its own meal is named and never extended),
 * else a new meal. The caller does the request; this only decides it, so the rule is testable without a network.
 */
export function planMealWrite(
  dayMeals: MealResponse[],
  mealType: MealType,
  entries: MealEntryRequest[],
  date: Date,
): MealWrite {
  const target = dayMeals
    .filter((m) => m.mealType === mealType && m.name == null)
    .sort((a, b) => new Date(b.dateTime).getTime() - new Date(a.dateTime).getTime())[0];
  if (!target) {
    return { kind: "create", body: { dateTime: logTimestampFor(date), mealType, name: null, entries } };
  }
  return {
    kind: "update",
    id: target.id,
    body: {
      dateTime: target.dateTime,
      mealType,
      name: null,
      entries: [...target.entries.map((e) => entryRequestOf(e)), ...entries],
    },
  };
}
