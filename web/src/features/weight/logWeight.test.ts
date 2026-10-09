import { describe, expect, it } from "vitest";
import { clampWeight, initialWeight, planWeightSave, stepWeight } from "./logWeight";
import { WEIGHT_NOTE_MAX } from "./types";
import type { WeightResponse } from "./types";

const w = (id: number, date: string, weight: number): WeightResponse => ({ id, date, weight });

describe("stepWeight / clampWeight", () => {
  it("↑/↓ move 0,1 kg without floating-point tails", () => {
    expect(stepWeight(69.6, 1, false)).toBe(69.7);
    expect(stepWeight(69.6, -1, false)).toBe(69.5);
    expect(stepWeight(0.3 + 69.6, 1, false)).toBe(70);
  });

  it("Shift moves a whole kilogram", () => {
    expect(stepWeight(69.6, 1, true)).toBe(70.6);
    expect(stepWeight(69.6, -1, true)).toBe(68.6);
  });

  it("stays inside 20 … 500 kg", () => {
    expect(stepWeight(20, -1, true)).toBe(20);
    expect(stepWeight(500, 1, true)).toBe(500);
    expect(clampWeight(0)).toBe(20);
    expect(clampWeight(69.64)).toBe(69.6);
  });
});

describe("initialWeight", () => {
  it("the edited entry, else the last weigh-in (by date), else 70", () => {
    const list = [w(1, "2026-09-25", 69.8), w(3, "2026-09-27", 69.6), w(2, "2026-09-26", 70)];
    expect(initialWeight(list, list[0])).toBe(69.8);
    expect(initialWeight(list, null)).toBe(69.6);
    expect(initialWeight([], null)).toBe(70);
  });
});

describe("planWeightSave", () => {
  const list = [w(1, "2026-09-26", 69.8), w(2, "2026-09-27", 69.6)];

  it("a new entry on a free day is just a create", () => {
    const plan = planWeightSave(list, null, "2026-09-28", 69.4);
    expect(plan).toEqual({ create: { date: "2026-09-28", weight: 69.4 }, deleteIds: [], conflicts: [] });
  });

  it("a new entry on a day that already has one replaces it, after a confirm", () => {
    const plan = planWeightSave(list, null, "2026-09-27", 69.3);
    expect(plan.conflicts.map((c) => c.id)).toEqual([2]);
    expect(plan.deleteIds).toEqual([2]);
    expect(plan.create.weight).toBe(69.3);
  });

  it("editing keeps its date: create the new one, delete the old, nothing to confirm", () => {
    const plan = planWeightSave(list, list[1], "2026-09-27", 69.5);
    expect(plan.conflicts).toEqual([]);
    expect(plan.deleteIds).toEqual([2]);
  });

  it("editing onto another day with an entry: both the edited one and that day's are removed, with a confirm", () => {
    const plan = planWeightSave(list, list[1], "2026-09-26", 69.5);
    expect(plan.conflicts.map((c) => c.id)).toEqual([1]);
    expect(plan.deleteIds).toEqual([2, 1]);
  });

  it("several entries on the chosen day are all replaced", () => {
    const many = [w(1, "2026-09-27", 70), w(2, "2026-09-27", 69.8)];
    expect(planWeightSave(many, null, "2026-09-27", 69.5).deleteIds).toEqual([1, 2]);
  });

  it("the weight is rounded to a tenth", () => {
    expect(planWeightSave([], null, "2026-09-27", 69.449).create.weight).toBe(69.4);
  });
});

describe("planWeightSave — the note and the time (LIF-115)", () => {
  it("carries a trimmed note, and none when it is blank", () => {
    expect(planWeightSave([], null, "2026-09-27", 69.6, "  fasted  ").create.note).toBe("fasted");
    expect(planWeightSave([], null, "2026-09-27", 69.6, "   ").create).not.toHaveProperty("note");
    expect(planWeightSave([], null, "2026-09-27", 69.6).create).not.toHaveProperty("note");
  });

  it("caps the note at what the API accepts", () => {
    expect(planWeightSave([], null, "2026-09-27", 69.6, "x".repeat(WEIGHT_NOTE_MAX + 40)).create.note).toHaveLength(WEIGHT_NOTE_MAX);
  });

  it("an edit on the same day keeps the time it was taken; moving it to another day does not", () => {
    const editing: WeightResponse = { id: 3, date: "2026-09-27", weight: 69.6, recordedAt: "2026-09-27T05:02:00Z" };
    expect(planWeightSave([editing], editing, "2026-09-27", 69.8).create.recordedAt).toBe("2026-09-27T05:02:00Z");
    expect(planWeightSave([editing], editing, "2026-09-25", 69.8).create).not.toHaveProperty("recordedAt");
  });

  it("a new entry sends no time of its own: the server stamps it", () => {
    expect(planWeightSave([], null, "2026-09-27", 69.6).create).not.toHaveProperty("recordedAt");
  });
});
