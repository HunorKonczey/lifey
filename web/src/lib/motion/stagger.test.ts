import { afterEach, describe, expect, it } from "vitest";
import { staggerDelay } from "./stagger";

describe("staggerDelay", () => {
  afterEach(() => {
    // @ts-expect-error -- test-only global, not present in the node environment
    delete globalThis.window;
  });

  it("delays each index by the step (60ms default) when there is no window (SSR-safe default)", () => {
    expect(staggerDelay(0)).toBe(0);
    expect(staggerDelay(1)).toBe(60);
    expect(staggerDelay(3)).toBe(180);
  });

  it("accepts a custom step", () => {
    expect(staggerDelay(2, 100)).toBe(200);
  });

  it("is always 0 under reduced motion", () => {
    // @ts-expect-error -- minimal window stand-in for a node test environment
    globalThis.window = { matchMedia: () => ({ matches: true }) };
    expect(staggerDelay(4)).toBe(0);
  });
});
