/**
 * docs/landing_page/66-trainer-billing-web-plan.md §5 — the first-week
 * checklist, as a pure function over already-fetched data (same "extract the
 * logic into a plain .ts function" pattern as `bannerState.ts`/`billingGate.ts`,
 * for the same reason: no component-rendering test infrastructure in this
 * project, so the pure function is what makes the checklist's own rule set
 * testable — most importantly, step 2 ticking on an *accepted* invite, never
 * a merely-*sent* one, which is the prompt's own stated Verify line).
 */
export type OnboardingStepId = "profile" | "inviteAccepted" | "templateCreated" | "contentAssigned" | "firstMessage";

export interface OnboardingStep {
  id: OnboardingStepId;
  done: boolean;
}

export interface OnboardingStepInput {
  /** No backend concept of a "trainer profile" exists (checked before writing
   *  this) — self-reported, via `markProfileDone()` below, not derived. */
  profileMarkedDone: boolean;
  /** `GET /trainer/clients` is already ACTIVE-only server-side (`TrainerAccessService
   *  .findActiveClientsForTrainer`) — a merely-sent, not-yet-accepted invite never
   *  appears in this count, so `> 0` here already means "accepted," not "sent." */
  activeClientCount: number;
  templateCount: number;
  anyContentAssigned: boolean;
  anyMessageSent: boolean;
}

export function onboardingStepsFor(input: OnboardingStepInput): OnboardingStep[] {
  return [
    { id: "profile", done: input.profileMarkedDone },
    { id: "inviteAccepted", done: input.activeClientCount > 0 },
    { id: "templateCreated", done: input.templateCount > 0 },
    { id: "contentAssigned", done: input.anyContentAssigned },
    { id: "firstMessage", done: input.anyMessageSent },
  ];
}

export function allStepsDone(steps: OnboardingStep[]): boolean {
  return steps.every((step) => step.done);
}

const PROFILE_DONE_KEY = "lifey-onboarding-profile-done";
const DISMISSED_KEY = "lifey-onboarding-dismissed";

export function isProfileMarkedDone(): boolean {
  try {
    return localStorage.getItem(PROFILE_DONE_KEY) === "1";
  } catch {
    return false;
  }
}

export function markProfileDone(): void {
  try {
    localStorage.setItem(PROFILE_DONE_KEY, "1");
  } catch {
    /* private browsing / storage disabled */
  }
}

/** `localStorage`, not `sessionStorage` — "dismissible *permanently*" (§5), unlike Prompt 7's session-only trial-info banner. */
export function isChecklistDismissed(): boolean {
  try {
    return localStorage.getItem(DISMISSED_KEY) === "1";
  } catch {
    return false;
  }
}

export function dismissChecklist(): void {
  try {
    localStorage.setItem(DISMISSED_KEY, "1");
  } catch {
    /* private browsing / storage disabled */
  }
}
