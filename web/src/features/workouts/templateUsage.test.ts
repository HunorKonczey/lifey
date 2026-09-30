import { describe, expect, it } from "vitest";
import { templateUsage } from "./templateUsage";
import type { WorkoutSessionResponse, WorkoutTemplateResponse } from "./types";

// Wednesday 30 Sep 2026: this week is Mon 28 Sep, the window Mon 9 Sep … Sun 4 Oct (4 weeks).
const NOW = new Date(2026, 8, 30, 12);

const tpl = (id: number, name: string): WorkoutTemplateResponse => ({ id, name, exercises: [] });
const ses = (id: number, templateId: number | null, start: Date): WorkoutSessionResponse =>
  ({ id, templateId, startedAt: start.toISOString(), finishedAt: null, sessionKind: "STRENGTH" }) as unknown as WorkoutSessionResponse;

describe("templateUsage", () => {
  const templates = [tpl(1, "Push"), tpl(2, "Pull"), tpl(3, "Legs")];

  it("counts per week, oldest first, current week last", () => {
    const usage = templateUsage(
      templates,
      [
        ses(1, 1, new Date(2026, 8, 29, 18)), // this week
        ses(2, 1, new Date(2026, 8, 22, 18)), // last week
        ses(3, 1, new Date(2026, 8, 23, 18)), // last week
        ses(4, 1, new Date(2026, 8, 10, 18)), // 3 weeks ago (Mon 7 Sep week)
      ],
      NOW,
    );
    const push = usage.find((u) => u.templateId === 1)!;
    expect(push.perWeek).toEqual([1, 0, 2, 1]); // weeks of 7, 14, 21 and 28 Sep
    expect(push.total).toBe(4);
  });

  it("the window is exactly four calendar weeks: a Sunday before it is out, the Monday of its first week is in", () => {
    const usage = templateUsage(templates, [ses(1, 2, new Date(2026, 8, 6, 23, 59)), ses(2, 2, new Date(2026, 8, 7, 0, 5)), ses(3, 2, new Date(2026, 8, 13, 23, 59))], NOW);
    // weeks start Mon 7 Sep, 14 Sep, 21 Sep, 28 Sep — Sun 6 Sep is outside
    expect(usage.find((u) => u.templateId === 2)!.perWeek).toEqual([2, 0, 0, 0]);
  });

  it("most used first, ties in the templates' own order, unused ones listed with zeros", () => {
    const usage = templateUsage(templates, [ses(1, 2, new Date(2026, 8, 29)), ses(2, 2, new Date(2026, 8, 28)), ses(3, 1, new Date(2026, 8, 29))], NOW);
    expect(usage.map((u) => u.name)).toEqual(["Pull", "Push", "Legs"]);
    expect(usage[2]).toMatchObject({ total: 0, perWeek: [0, 0, 0, 0] });
  });

  it("sessions without a template, of an unknown template, or in the future are nobody's usage", () => {
    const usage = templateUsage(templates, [ses(1, null, new Date(2026, 8, 29)), ses(2, 99, new Date(2026, 8, 29)), ses(3, 1, new Date(2026, 9, 12))], NOW);
    expect(usage.every((u) => u.total === 0)).toBe(true);
  });

  it("no templates, no rows", () => {
    expect(templateUsage([], [ses(1, 1, new Date(2026, 8, 29))], NOW)).toEqual([]);
  });
});
