import { describe, it, expect } from "vitest";
import { invalidationMap, queryKeys } from "./queryKeys";

describe("queryKeys", () => {
  it("produces stable, namespaced keys", () => {
    expect(queryKeys.foods.all()).toEqual(["foods"]);
    expect(queryKeys.meals.byDate("2026-06-28")).toEqual(["meals", "date", "2026-06-28"]);
    expect(queryKeys.statistics.daily("2026-06-28")).toEqual(["statistics", "daily", "2026-06-28"]);
    expect(queryKeys.foods.detail(5)).toEqual(["foods", 5]);
    expect(queryKeys.trainerPreferences.all()).toEqual(["trainer-preferences"]);
  });

  it("varies the key by argument", () => {
    expect(queryKeys.statistics.daily("a")).not.toEqual(queryKeys.statistics.daily("b"));
  });

  it("billing.entitlements() is a stable, argument-free key (64 §3.1 — one row per caller)", () => {
    expect(queryKeys.billing.entitlements()).toEqual(["billing", "entitlements"]);
  });
});

describe("invalidationMap", () => {
  it("every seat-changing mutation invalidates entitlements too (66 §6, §9.1)", () => {
    // A missing entry here is a stale seat meter that nothing reports — the
    // exact failure mode 66 §9.1 calls out by name.
    expect(invalidationMap.trainerInvite).toContainEqual(queryKeys.billing.entitlements());
    expect(invalidationMap.trainerClient).toContainEqual(queryKeys.billing.entitlements());
  });

  it("still invalidates its own original resource alongside entitlements", () => {
    expect(invalidationMap.trainerInvite).toContainEqual(queryKeys.trainerInvites.all());
    expect(invalidationMap.trainerClient).toContainEqual(queryKeys.trainerClients.all());
  });
});
