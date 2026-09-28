import { describe, expect, it } from "vitest";
import { useDateStore } from "@/lib/hooks/useDateStore";
import { createFormat } from "@/lib/format/lifeyFormat";

describe("date stepper", () => {
  it("setDate clamps a future day to today instead of accepting it", () => {
    const inFiveDays = new Date();
    inFiveDays.setDate(inFiveDays.getDate() + 5);
    useDateStore.getState().setDate(inFiveDays);

    const today = new Date();
    expect(useDateStore.getState().date.toDateString()).toBe(today.toDateString());
    expect(useDateStore.getState().isPinned).toBe(false);
  });

  it("still accepts a past day and pins it", () => {
    const yesterday = new Date();
    yesterday.setDate(yesterday.getDate() - 1);
    useDateStore.getState().setDate(yesterday);

    expect(useDateStore.getState().date.toDateString()).toBe(yesterday.toDateString());
    expect(useDateStore.getState().isPinned).toBe(true);
  });

  it("today's label is prefixed per locale; any other day is bare", () => {
    const today = new Date(2026, 8, 27);
    const yesterday = new Date(2026, 8, 26);

    expect(createFormat("hu").dayLabel(today, today)).toMatch(/^Ma · /);
    expect(createFormat("en").dayLabel(today, today)).toMatch(/^Today · /);
    expect(createFormat("hu").dayLabel(yesterday, today)).not.toMatch(/^Ma/);
    expect(createFormat("en").dayLabel(yesterday, today)).not.toMatch(/^Today/);
  });
});
