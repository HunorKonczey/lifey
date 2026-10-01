import { describe, it, expect } from "vitest";
import { copyMealPayload, mealTypeForClock, suggestCopy } from "./copyMeal";
import type { MealResponse } from "./types";

function meal(overrides: Partial<MealResponse> = {}): MealResponse {
  return {
    id: 1,
    dateTime: "2026-07-05T13:30:00.000Z",
    mealType: "LUNCH",
    name: "Lunch out",
    entries: [
      { foodId: 10, foodName: "Rice", quantityInGrams: 200, calories: 260, protein: 5, carbs: 56, fat: 1 },
    ],
    ...overrides,
  };
}

describe("copyMealPayload", () => {
  it("lands on the target date's calendar day, preserving the source time-of-day", () => {
    const source = meal();
    const target = new Date("2026-07-10T00:00:00.000Z");

    const payload = copyMealPayload(source, target);
    const result = new Date(payload.dateTime);
    const original = new Date(source.dateTime);

    expect(result.getHours()).toBe(original.getHours());
    expect(result.getMinutes()).toBe(original.getMinutes());
    expect(result.getDate()).toBe(target.getDate());
    expect(result.getMonth()).toBe(target.getMonth());
    expect(result.getFullYear()).toBe(target.getFullYear());
  });

  it("carries over meal type, name and entries unchanged", () => {
    const payload = copyMealPayload(meal(), new Date());

    expect(payload.mealType).toBe("LUNCH");
    expect(payload.name).toBe("Lunch out");
    expect(payload.entries).toEqual([{ foodId: 10, quantityInGrams: 200 }]);
  });

  it("preserves a null name (unnamed meal)", () => {
    const payload = copyMealPayload(meal({ name: null }), new Date());
    expect(payload.name).toBeNull();
  });
});

describe("mealTypeForClock", () => {
  const at = (h: number, m: number) => new Date(2026, 8, 30, h, m);

  it("switches exactly at 10:30, 15:00 and 17:30", () => {
    expect(mealTypeForClock(at(10, 29))).toBe("BREAKFAST");
    expect(mealTypeForClock(at(10, 30))).toBe("LUNCH");
    expect(mealTypeForClock(at(14, 59))).toBe("LUNCH");
    expect(mealTypeForClock(at(15, 0))).toBe("SNACK");
    expect(mealTypeForClock(at(17, 29))).toBe("SNACK");
    expect(mealTypeForClock(at(17, 30))).toBe("DINNER");
  });

  it("night and early morning: dinner after 17:30, breakfast from midnight", () => {
    expect(mealTypeForClock(at(23, 59))).toBe("DINNER");
    expect(mealTypeForClock(at(0, 0))).toBe("BREAKFAST");
  });
});

describe("suggestCopy", () => {
  const now = new Date(2026, 8, 30, 19, 0); // dinner time
  const at = (day: number, h: number, type: MealResponse["mealType"], id: number) =>
    meal({ id, mealType: type, dateTime: new Date(2026, 8, day, h, 0).toISOString() });

  it("offers yesterday's dinner when today has none", () => {
    const yesterdayDinner = at(29, 19, "DINNER", 1);
    expect(suggestCopy([yesterdayDinner, at(29, 8, "BREAKFAST", 2)], now)).toEqual({ mealType: "DINNER", source: yesterdayDinner });
  });

  it("stays hidden once today already has that meal type", () => {
    expect(suggestCopy([at(29, 19, "DINNER", 1), at(30, 18, "DINNER", 2)], now)).toBeNull();
  });

  it("stays hidden when yesterday had no meal of that type", () => {
    expect(suggestCopy([at(29, 8, "BREAKFAST", 1), at(29, 13, "LUNCH", 2)], now)).toBeNull();
  });

  it("today's other meal types don't hide it — only the clock's type counts", () => {
    const yesterdayDinner = at(29, 19, "DINNER", 1);
    expect(suggestCopy([yesterdayDinner, at(30, 8, "BREAKFAST", 2), at(30, 13, "LUNCH", 3)], now)?.source).toBe(yesterdayDinner);
  });

  it("copies the latest when yesterday had several of that type", () => {
    const early = at(29, 18, "DINNER", 1);
    const late = at(29, 21, "DINNER", 2);
    expect(suggestCopy([early, late], now)?.source).toBe(late);
  });

  it("ignores days other than yesterday", () => {
    expect(suggestCopy([at(28, 19, "DINNER", 1)], now)).toBeNull();
  });

  it("follows the clock: at 9:00 it is yesterday's breakfast", () => {
    const breakfast = at(29, 8, "BREAKFAST", 1);
    expect(suggestCopy([breakfast, at(29, 19, "DINNER", 2)], new Date(2026, 8, 30, 9, 0))).toEqual({ mealType: "BREAKFAST", source: breakfast });
  });
});
