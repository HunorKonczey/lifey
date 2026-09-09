"use client";

import { useState } from "react";
import Link from "next/link";
import { useTranslations } from "next-intl";
import { useQuery } from "@tanstack/react-query";
import { trainerApi } from "@/features/trainer/api";
import { templateApi } from "@/features/workouts/api";
import { queryKeys } from "@/lib/api/queryKeys";
import { useConversations } from "@/features/chat/hooks";
import { useEntitlements } from "../hooks";
import {
  allStepsDone,
  dismissChecklist,
  isChecklistDismissed,
  isProfileMarkedDone,
  markProfileDone,
  onboardingStepsFor,
  type OnboardingStepId,
} from "../onboardingChecklist";

const STEP_META: Record<OnboardingStepId, { labelKey: string; icon: string; href: string }> = {
  profile: { labelKey: "stepProfile", icon: "person", href: "/settings" },
  inviteAccepted: { labelKey: "stepInvite", icon: "person_add", href: "/admin/invites" },
  templateCreated: { labelKey: "stepTemplate", icon: "fitness_center", href: "/admin/workouts" },
  contentAssigned: { labelKey: "stepAssign", icon: "assignment_turned_in", href: "/admin/workouts" },
  firstMessage: { labelKey: "stepMessage", icon: "chat_bubble", href: "/admin/chat" },
};

/**
 * docs/landing_page/66-trainer-billing-web-plan.md §5 — shown on `/admin` for
 * the trial's duration; the checklist itself lives in `onboardingChecklist.ts`
 * as a pure function over already-fetched data. Step 2 ticking on *accepted*,
 * never merely *sent* (§5's own stated point), falls out for free: `GET
 * /trainer/clients` is already ACTIVE-only server-side.
 *
 * Step 1 ("complete your trainer profile") is self-reported — no backend
 * concept of a trainer profile exists to check against (confirmed before
 * writing this), and building one is out of scope for a web-only prompt with
 * no backend annex in this doc. It's the one step a click marks done rather
 * than data proving it.
 *
 * Step 5 ("first message sent") is a best-effort read of `lastMessage` per
 * conversation, not full history — `ConversationResponse.lastMessage` is only
 * the *most recent* message, so a trainer whose first message was later
 * replied to would show as "not done" here until they send another. A
 * precise answer needs a new backend field; documented, not fixed, since this
 * is a nice-to-have nudge, not an entitlement gate.
 */
export function TrainerOnboardingChecklist() {
  const t = useTranslations("admin.onboarding");
  const { data: entitlement } = useEntitlements();
  const isTrialing = entitlement?.trainer?.status === "TRIALING";

  const [dismissed, setDismissed] = useState(() => isChecklistDismissed());
  const [profileDone, setProfileDone] = useState(() => isProfileMarkedDone());

  const clientsQ = useQuery({
    queryKey: queryKeys.trainerClients.all(),
    queryFn: trainerApi.clients,
    enabled: isTrialing,
  });
  const templatesQ = useQuery({
    queryKey: queryKeys.workoutTemplates.all(),
    queryFn: templateApi.list,
    enabled: isTrialing,
  });
  const conversationsQ = useConversations(isTrialing);

  if (!isTrialing || dismissed) return null;

  const activeClientCount = clientsQ.data?.length ?? 0;
  const anyContentAssigned = (clientsQ.data ?? []).some((c) => c.assignedPlanCount > 0);
  const anyMessageSent = (conversationsQ.data ?? []).some((c) => c.lastMessage && c.lastMessage.senderId !== c.peer.userId);

  const steps = onboardingStepsFor({
    profileMarkedDone: profileDone,
    activeClientCount,
    templateCount: templatesQ.data?.length ?? 0,
    anyContentAssigned,
    anyMessageSent,
  });
  const complete = allStepsDone(steps);

  return (
    <div
      data-testid="trainer-onboarding-checklist"
      className="rounded-[var(--r-lg)] p-4.5 mb-3.5"
      style={{ background: "var(--surface-container)" }}
    >
      <div className="flex items-center justify-between gap-2">
        <p className="text-sm font-extrabold" style={{ color: "var(--on-surface)" }}>
          {complete ? t("completeTitle") : t("title")}
        </p>
        {complete && (
          <button
            onClick={() => {
              dismissChecklist();
              setDismissed(true);
            }}
            aria-label={t("dismiss")}
            className="shrink-0 p-1 rounded-full hover:bg-black/10"
            style={{ color: "var(--on-surface-variant)" }}
          >
            <span className="material-symbols-rounded text-lg">close</span>
          </button>
        )}
      </div>

      <div className="flex flex-col gap-1.5 mt-2.5">
        {steps.map((step) => {
          const meta = STEP_META[step.id];
          const isProfileStep = step.id === "profile";
          return (
            <div
              key={step.id}
              data-testid={`onboarding-step-${step.id}`}
              data-step-done={step.done}
              className="flex items-center gap-2.5 rounded-xl px-2.5 py-2"
            >
              {isProfileStep ? (
                <button
                  onClick={() => {
                    markProfileDone();
                    setProfileDone(true);
                  }}
                  disabled={step.done}
                  aria-label={t("markDone")}
                  className="shrink-0 w-5 h-5 rounded-full flex items-center justify-center"
                  style={{
                    background: step.done ? "var(--tertiary)" : "transparent",
                    border: step.done ? "none" : "1.5px solid var(--outline)",
                  }}
                >
                  {step.done && (
                    <span className="material-symbols-rounded text-[13px]" style={{ color: "var(--bg)" }}>
                      check
                    </span>
                  )}
                </button>
              ) : (
                <span
                  className="shrink-0 w-5 h-5 rounded-full flex items-center justify-center"
                  style={{
                    background: step.done ? "var(--tertiary)" : "transparent",
                    border: step.done ? "none" : "1.5px solid var(--outline)",
                  }}
                >
                  {step.done && (
                    <span className="material-symbols-rounded text-[13px]" style={{ color: "var(--bg)" }}>
                      check
                    </span>
                  )}
                </span>
              )}
              <Link
                href={meta.href}
                className="flex-1 text-[13px] font-semibold"
                style={{
                  color: step.done ? "var(--on-surface-variant)" : "var(--on-surface)",
                  textDecoration: step.done ? "line-through" : "none",
                }}
              >
                {t(meta.labelKey)}
              </Link>
            </div>
          );
        })}
      </div>
    </div>
  );
}
