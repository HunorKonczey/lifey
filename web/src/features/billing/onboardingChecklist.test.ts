import { describe, expect, it } from "vitest";
import { allStepsDone, onboardingStepsFor, type OnboardingStepInput } from "./onboardingChecklist";

function input(overrides: Partial<OnboardingStepInput> = {}): OnboardingStepInput {
  return {
    profileMarkedDone: false,
    activeClientCount: 0,
    templateCount: 0,
    anyContentAssigned: false,
    anyMessageSent: false,
    ...overrides,
  };
}

function stepDone(steps: ReturnType<typeof onboardingStepsFor>, id: string) {
  return steps.find((s) => s.id === id)!.done;
}

describe("onboardingStepsFor", () => {
  it("§5's own point: step 2 ticks on an accepted invite, never a merely-sent one", () => {
    // GET /trainer/clients is already ACTIVE-only server-side, so a pending
    // (sent, not yet accepted) invite never contributes to activeClientCount —
    // there is nothing for this function to see until the client accepts.
    expect(stepDone(onboardingStepsFor(input({ activeClientCount: 0 })), "inviteAccepted")).toBe(false);
    expect(stepDone(onboardingStepsFor(input({ activeClientCount: 1 })), "inviteAccepted")).toBe(true);
  });

  it("step 1 (profile) is self-reported, not derived from any other input", () => {
    expect(stepDone(onboardingStepsFor(input({ profileMarkedDone: true })), "profile")).toBe(true);
    expect(stepDone(onboardingStepsFor(input({ profileMarkedDone: false })), "profile")).toBe(false);
  });

  it("step 3 ticks once a template exists", () => {
    expect(stepDone(onboardingStepsFor(input({ templateCount: 1 })), "templateCreated")).toBe(true);
    expect(stepDone(onboardingStepsFor(input({ templateCount: 0 })), "templateCreated")).toBe(false);
  });

  it("step 4 ticks on anyContentAssigned, independent of step 3's template count", () => {
    expect(stepDone(onboardingStepsFor(input({ templateCount: 0, anyContentAssigned: true })), "contentAssigned")).toBe(true);
  });

  it("step 5 ticks on anyMessageSent", () => {
    expect(stepDone(onboardingStepsFor(input({ anyMessageSent: true })), "firstMessage")).toBe(true);
    expect(stepDone(onboardingStepsFor(input({ anyMessageSent: false })), "firstMessage")).toBe(false);
  });

  it("returns all 5 steps in a fixed order", () => {
    const steps = onboardingStepsFor(input());
    expect(steps.map((s) => s.id)).toEqual(["profile", "inviteAccepted", "templateCreated", "contentAssigned", "firstMessage"]);
  });
});

describe("allStepsDone", () => {
  it("false unless every step is done", () => {
    const steps = onboardingStepsFor(input({ profileMarkedDone: true, activeClientCount: 1, templateCount: 1, anyContentAssigned: true }));
    expect(allStepsDone(steps)).toBe(false); // firstMessage still missing
  });

  it("true once every step is done", () => {
    const steps = onboardingStepsFor(
      input({ profileMarkedDone: true, activeClientCount: 1, templateCount: 1, anyContentAssigned: true, anyMessageSent: true }),
    );
    expect(allStepsDone(steps)).toBe(true);
  });
});
