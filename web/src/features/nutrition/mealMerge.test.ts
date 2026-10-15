import { describe, expect, it } from "vitest";
import { planMealWrite } from "./mealMerge";
import type { MealResponse } from "./types";

function meal(overrides: Partial<MealResponse> = {}): MealResponse {
  return {
    id: 1,
    dateTime: "2026-07-05T12:00:00.000Z",
    mealType: "LUNCH",
    name: null,
    entries: [{ foodId: 10, foodName: "Rice", quantityInGrams: 200, calories: 260, protein: 5, carbs: 56, fat: 1 }],
    ...overrides,
  };
}

const date = new Date("2026-07-05T00:00:00.000Z");
const added = [{ foodId: 20, quantityInGrams: 100 }];

describe("planMealWrite", () => {
  it("creates a meal when the day has none of that type", () => {
    const write = planMealWrite([], "LUNCH", added, date);

    expect(write.kind).toBe("create");
    if (write.kind !== "create") return;
    expect(write.body.mealType).toBe("LUNCH");
    expect(write.body.name).toBeNull();
    expect(write.body.entries).toEqual(added);
  });

  it("rewrites the day's plain meal with its old entries first, then the new ones", () => {
    const write = planMealWrite([meal()], "LUNCH", added, date);

    expect(write).toMatchObject({ kind: "update", id: 1 });
    if (write.kind !== "update") return;
    expect(write.body.dateTime).toBe("2026-07-05T12:00:00.000Z");
    expect(write.body.name).toBeNull();
    expect(write.body.entries).toEqual([
      { foodId: 10, quantityInGrams: 200 },
      { foodId: 20, quantityInGrams: 100 },
    ]);
  });

  it("keeps the recipe tags of the entries already in the meal (docs/88)", () => {
    const tagged = meal({
      entries: [{ foodId: 10, foodName: "Rice", quantityInGrams: 200, calories: 260, protein: 5, carbs: 56, fat: 1, recipeId: 7, recipeName: "Chilli" }],
    });

    const write = planMealWrite([tagged], "LUNCH", added, date);

    expect(write.kind === "update" && write.body.entries).toEqual([
      { foodId: 10, quantityInGrams: 200, recipeId: 7 },
      { foodId: 20, quantityInGrams: 100 },
    ]);
  });

  it("appends several entries at once", () => {
    const two = [
      { foodId: 20, quantityInGrams: 100 },
      { foodId: 21, quantityInGrams: 50 },
    ];
    const write = planMealWrite([meal()], "LUNCH", two, date);

    expect(write.kind === "update" && write.body.entries.map((e) => e.foodId)).toEqual([10, 20, 21]);
  });

  it("picks the latest of several plain meals of that type", () => {
    const morning = meal({ id: 1, dateTime: "2026-07-05T08:00:00.000Z" });
    const noon = meal({ id: 2, dateTime: "2026-07-05T12:30:00.000Z" });
    const early = meal({ id: 3, dateTime: "2026-07-05T07:00:00.000Z" });

    const write = planMealWrite([morning, noon, early], "LUNCH", added, date);

    expect(write).toMatchObject({ kind: "update", id: 2 });
  });

  it("never extends a named meal (a recipe logged as its own meal)", () => {
    const write = planMealWrite([meal({ name: "Chilli" })], "LUNCH", added, date);

    expect(write.kind).toBe("create");
  });

  it("never extends a meal of another type", () => {
    const write = planMealWrite([meal({ mealType: "DINNER" })], "LUNCH", added, date);

    expect(write.kind).toBe("create");
  });

  it("skips a named meal and uses the plain one next to it", () => {
    const named = meal({ id: 1, name: "Chilli", dateTime: "2026-07-05T13:00:00.000Z" });
    const plain = meal({ id: 2, dateTime: "2026-07-05T11:00:00.000Z" });

    const write = planMealWrite([named, plain], "LUNCH", added, date);

    expect(write).toMatchObject({ kind: "update", id: 2 });
  });

  it("does not reorder the caller's list", () => {
    const meals = [meal({ id: 1, dateTime: "2026-07-05T08:00:00.000Z" }), meal({ id: 2, dateTime: "2026-07-05T12:00:00.000Z" })];

    planMealWrite(meals, "LUNCH", added, date);

    expect(meals.map((m) => m.id)).toEqual([1, 2]);
  });
});
