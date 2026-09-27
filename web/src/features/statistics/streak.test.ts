import { describe, it, expect } from "vitest";
import { loggingStreak } from "./streak";

const today = new Date(2026, 8, 27, 12, 0); // local noon, Sep 27
const at = (day: number, hour = 9) => new Date(2026, 8, day, hour, 0).toISOString();

describe("loggingStreak", () => {
  it("is 0 with no activity", () => {
    expect(loggingStreak([], today)).toBe(0);
  });

  it("counts consecutive days ending today", () => {
    expect(loggingStreak([at(27), at(26), at(25), at(23)], today)).toBe(3);
  });

  it("does not break just because today is not logged yet", () => {
    expect(loggingStreak([at(26), at(25)], today)).toBe(2);
  });

  it("is 0 when the last activity was two days ago", () => {
    expect(loggingStreak([at(25), at(24)], today)).toBe(0);
  });

  it("counts a day once however many entries it has, and is not capped at 5", () => {
    const entries = [at(27, 8), at(27, 13)];
    for (let d = 26; d >= 18; d--) entries.push(at(d));
    expect(loggingStreak(entries, today)).toBe(10);
  });
});
