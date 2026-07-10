import { describe, it, expect } from "vitest";
import { copyMealPayload } from "./copyMeal";
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
