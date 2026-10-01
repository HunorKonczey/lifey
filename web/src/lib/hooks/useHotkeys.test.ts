import { afterEach, beforeEach, describe, expect, it, vi } from "vitest";
import { createChordTracker, isTypingTarget, matchGoTo } from "./useHotkeys";

describe("isTypingTarget", () => {
  it("is true for inputs, textareas and contenteditable, false otherwise", () => {
    expect(isTypingTarget("INPUT", false)).toBe(true);
    expect(isTypingTarget("TEXTAREA", false)).toBe(true);
    expect(isTypingTarget("DIV", true)).toBe(true);
    expect(isTypingTarget("DIV", false)).toBe(false);
    expect(isTypingTarget("BUTTON", false)).toBe(false);
  });
});

describe("matchGoTo", () => {
  const items = [
    { shortcut: "D", href: "/dashboard" },
    { shortcut: "N", href: "/nutrition" },
  ];

  it("resolves a letter to its item's href, case-insensitively", () => {
    expect(matchGoTo("D", items)).toBe("/dashboard");
    expect(matchGoTo("d", items)).toBe("/dashboard");
    expect(matchGoTo("n", items)).toBe("/nutrition");
  });

  it("returns null when no item claims that letter", () => {
    expect(matchGoTo("Z", items)).toBeNull();
  });
});

describe("createChordTracker", () => {
  beforeEach(() => vi.useFakeTimers());
  afterEach(() => vi.useRealTimers());

  it("is active right after start, until consumed", () => {
    const chord = createChordTracker(1000);
    expect(chord.active).toBe(false);
    chord.start();
    expect(chord.active).toBe(true);
    chord.consume();
    expect(chord.active).toBe(false);
  });

  it("clears itself after the timeout elapses", () => {
    const chord = createChordTracker(1000);
    chord.start();
    vi.advanceTimersByTime(999);
    expect(chord.active).toBe(true);
    vi.advanceTimersByTime(1);
    expect(chord.active).toBe(false);
  });

  it("a second start resets the timeout window", () => {
    const chord = createChordTracker(1000);
    chord.start();
    vi.advanceTimersByTime(800);
    chord.start();
    vi.advanceTimersByTime(800);
    expect(chord.active).toBe(true);
    vi.advanceTimersByTime(200);
    expect(chord.active).toBe(false);
  });
});
