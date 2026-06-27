import { describe, it, expect } from "vitest";
import { queryKeys } from "./queryKeys";

describe("queryKeys", () => {
  it("produces stable, namespaced keys", () => {
    expect(queryKeys.foods.all()).toEqual(["foods"]);
    expect(queryKeys.meals.byDate("2026-06-28")).toEqual(["meals", "date", "2026-06-28"]);
    expect(queryKeys.statistics.daily("2026-06-28")).toEqual(["statistics", "daily", "2026-06-28"]);
    expect(queryKeys.foods.detail(5)).toEqual(["foods", 5]);
  });

  it("varies the key by argument", () => {
    expect(queryKeys.statistics.daily("a")).not.toEqual(queryKeys.statistics.daily("b"));
  });
});
