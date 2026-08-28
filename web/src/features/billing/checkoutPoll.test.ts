import { describe, expect, it } from "vitest";
import { CHECKOUT_POLL_CEILING_MS, nextCheckoutPollDelayMs } from "./checkoutPoll";

describe("nextCheckoutPollDelayMs", () => {
  it("starts at 1s (D-T3: '1 s, backing off, 30 s ceiling')", () => {
    expect(nextCheckoutPollDelayMs(0)).toBe(1000);
  });

  it("backs off — each delay is at least as long as the previous one", () => {
    let attempt = 0;
    let previous = 0;
    let delay = nextCheckoutPollDelayMs(attempt);
    while (delay !== false) {
      expect(delay).toBeGreaterThanOrEqual(previous);
      previous = delay;
      attempt += 1;
      delay = nextCheckoutPollDelayMs(attempt);
    }
  });

  it("the cumulative schedule lands exactly on the 30 s ceiling, then stops", () => {
    let total = 0;
    let attempt = 0;
    let delay = nextCheckoutPollDelayMs(attempt);
    while (delay !== false) {
      total += delay;
      attempt += 1;
      delay = nextCheckoutPollDelayMs(attempt);
    }
    expect(total).toBe(CHECKOUT_POLL_CEILING_MS);
  });

  it("returns false past the end of the schedule, not an ever-shrinking or negative delay", () => {
    expect(nextCheckoutPollDelayMs(100)).toBe(false);
    expect(nextCheckoutPollDelayMs(-1)).toBe(false);
  });
});
