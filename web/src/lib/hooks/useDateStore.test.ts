import { describe, it, expect, beforeEach, afterEach, vi } from "vitest";
import { useDateStore } from "./useDateStore";

describe("useDateStore", () => {
  beforeEach(() => {
    vi.setSystemTime(new Date("2026-07-15T09:00:00"));
    useDateStore.setState({ date: new Date(), isPinned: false });
  });

  afterEach(() => {
    vi.useRealTimers();
  });

  it("syncToday rolls the date forward overnight when unpinned", () => {
    // Tab left open overnight: system clock moves to the next day, but the
    // store still holds yesterday's "today".
    vi.setSystemTime(new Date("2026-07-16T08:00:00"));

    useDateStore.getState().syncToday();

    expect(useDateStore.getState().dateStr()).toBe("2026-07-16");
  });

  it("syncToday leaves a manually picked day alone", () => {
    useDateStore.getState().setDate(new Date("2026-07-10T00:00:00"));
    expect(useDateStore.getState().isPinned).toBe(true);

    vi.setSystemTime(new Date("2026-07-16T08:00:00"));
    useDateStore.getState().syncToday();

    expect(useDateStore.getState().dateStr()).toBe("2026-07-10");
  });

  it("setDate unpins when the user navigates back to today", () => {
    useDateStore.getState().setDate(new Date("2026-07-10T00:00:00"));
    useDateStore.getState().setDate(new Date("2026-07-15T00:00:00"));

    expect(useDateStore.getState().isPinned).toBe(false);
  });
});
