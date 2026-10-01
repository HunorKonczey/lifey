import { afterEach, describe, expect, it, vi } from "vitest";
import { prefersReducedMotion, REDUCED_MOTION_QUERY } from "./useReducedMotion";

describe("prefersReducedMotion", () => {
  afterEach(() => {
    // @ts-expect-error -- test-only global, not present in the node environment
    delete globalThis.window;
  });

  it("is false when there is no window (SSR)", () => {
    expect(prefersReducedMotion()).toBe(false);
  });

  it("reads the OS preference through matchMedia", () => {
    const matchMedia = vi.fn((query: string) => ({ matches: query === REDUCED_MOTION_QUERY }));
    // @ts-expect-error -- minimal window stand-in for a node test environment
    globalThis.window = { matchMedia };

    expect(prefersReducedMotion()).toBe(true);
    expect(matchMedia).toHaveBeenCalledWith(REDUCED_MOTION_QUERY);
  });

  it("is false when the OS has no preference", () => {
    // @ts-expect-error -- minimal window stand-in for a node test environment
    globalThis.window = { matchMedia: () => ({ matches: false }) };

    expect(prefersReducedMotion()).toBe(false);
  });
});
