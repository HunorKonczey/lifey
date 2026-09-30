import { describe, expect, it } from "vitest";
import { daysBetween, pickerTemplates } from "./templatePicker";
import type { WorkoutSessionResponse, WorkoutTemplateResponse } from "./types";

const NOW = new Date(2026, 8, 30, 12);

const tpl = (id: number, exercises: number): WorkoutTemplateResponse => ({
  id,
  name: `T${id}`,
  exercises: Array.from({ length: exercises }, (_, i) => ({ exerciseId: i + 1, targetSets: 3 })),
});

function done(templateId: number, start: Date, minutes: number): WorkoutSessionResponse {
  return {
    id: start.getTime(),
    startedAt: start.toISOString(),
    finishedAt: new Date(start.getTime() + minutes * 60_000).toISOString(),
    templateId,
    sets: [],
    exercises: [],
  } as unknown as WorkoutSessionResponse;
}

describe("daysBetween", () => {
  it("counts calendar days, not 24 h spans", () => {
    expect(daysBetween(new Date(2026, 8, 30, 6), new Date(2026, 8, 30, 23))).toBe(0);
    expect(daysBetween(new Date(2026, 8, 29, 23, 59), new Date(2026, 8, 30, 0, 1))).toBe(1);
    expect(daysBetween(new Date(2026, 8, 25, 18), NOW)).toBe(5);
  });

  it("across a month boundary and a DST change", () => {
    expect(daysBetween(new Date(2026, 8, 28), new Date(2026, 9, 2))).toBe(4);
    expect(daysBetween(new Date(2026, 9, 24), new Date(2026, 9, 26, 12))).toBe(2); // EU clocks go back 25 Oct
  });
});

describe("pickerTemplates", () => {
  const sessions = [done(2, new Date(2026, 8, 25, 18), 50), done(1, new Date(2026, 8, 20, 18), 40)];

  it("puts the recommended template first and keeps the rest in order", () => {
    const items = pickerTemplates([tpl(1, 4), tpl(2, 6), tpl(3, 2)], sessions, 2, NOW);
    expect(items.map((i) => i.template.id)).toEqual([2, 1, 3]);
    expect(items[0].recommended).toBe(true);
    expect(items[1].recommended).toBe(false);
  });

  it("no recommendation keeps the order", () => {
    expect(pickerTemplates([tpl(1, 4), tpl(2, 6)], sessions, null, NOW).map((i) => i.template.id)).toEqual([1, 2]);
  });

  it("exercise count, estimated minutes and days since last use", () => {
    const [two] = pickerTemplates([tpl(2, 6)], sessions, 2, NOW);
    expect(two.exerciseCount).toBe(6);
    expect(two.estimatedMinutes).toBe(50);
    expect(two.daysAgo).toBe(5);
  });

  it("a template never done has no last-used day and falls back to 8 minutes an exercise", () => {
    const [three] = pickerTemplates([tpl(3, 5)], sessions, null, NOW);
    expect(three.daysAgo).toBeNull();
    expect(three.estimatedMinutes).toBe(40);
  });

  it("no templates, no tiles", () => {
    expect(pickerTemplates([], sessions, null, NOW)).toEqual([]);
  });
});
