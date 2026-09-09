"use client";

import { useState } from "react";
import Link from "next/link";
import { usePathname } from "next/navigation";
import { useTranslations } from "next-intl";
import { useEntitlements } from "../hooks";
import { bannerStateFor, dismissTrialInfo, isTrialInfoDismissed, type BannerState, type BannerTone } from "../bannerState";

const TONE_STYLES: Record<BannerTone, { background: string; color: string; icon: string }> = {
  error: { background: "color-mix(in srgb, var(--error) 15%, transparent)", color: "var(--error)", icon: "error" },
  warning: { background: "color-mix(in srgb, var(--error) 15%, transparent)", color: "var(--error)", icon: "warning" },
  info: { background: "var(--tertiary-container)", color: "var(--on-tertiary-container)", icon: "info" },
};

const COPY_KEYS: Record<BannerState["kind"], { title: string; body: string }> = {
  restricted: { title: "bannerRestrictedTitle", body: "bannerRestrictedBody" },
  pastDue: { title: "bannerPastDueTitle", body: "bannerPastDueBody" },
  overLimit: { title: "bannerOverLimitTitle", body: "bannerOverLimitBody" },
  trialUrgent: { title: "bannerTrialUrgentTitle", body: "bannerTrialUrgentBody" },
  trialInfo: { title: "bannerTrialInfoTitle", body: "bannerTrialInfoBody" },
};

// D-T6: chat is never touched by any of this. The banner lives in the admin
// layout (above every page's content, per D-T4) precisely because that's the
// one slot every other page shares — which is exactly why chat, the one page
// that must never show it, needs an explicit exemption rather than relying on
// "it's just not wired in there".
const EXEMPT_PATHS = ["/admin/chat"];

/**
 * docs/landing_page/66-trainer-billing-web-plan.md D-T4 — one banner slot,
 * driven purely by `bannerStateFor` (the priority table lives there, as a
 * pure function, so it's the thing under test — see `bannerState.test.ts`).
 */
export function AdminBillingBanner() {
  const t = useTranslations("admin.billing");
  const pathname = usePathname();
  const { data: entitlement } = useEntitlements();
  // Lazy initializer: reads sessionStorage once per mount, not on every
  // render — dismissing only ever needs to update this same in-memory flag
  // alongside the storage write, never re-derive it from storage again.
  const [trialInfoDismissed, setTrialInfoDismissed] = useState(() => isTrialInfoDismissed());

  if (EXEMPT_PATHS.some((path) => pathname?.startsWith(path))) return null;

  const state = bannerStateFor(entitlement);
  if (!state) return null;
  if (state.kind === "trialInfo" && trialInfoDismissed) return null;

  const tone = TONE_STYLES[state.tone];
  const copy = COPY_KEYS[state.kind];

  return (
    <div
      data-testid="admin-billing-banner"
      data-banner-kind={state.kind}
      className="rounded-[var(--r-lg)] p-4.5 mb-3.5 flex items-start gap-3"
      style={{ background: tone.background, color: tone.color }}
    >
      <span className="material-symbols-rounded text-2xl shrink-0">{tone.icon}</span>
      <div className="flex-1">
        <p className="text-sm font-extrabold">
          {state.kind === "overLimit"
            ? t(copy.title, { activeClients: state.activeClients, maxClients: state.maxClients })
            : state.kind === "trialUrgent" || state.kind === "trialInfo"
              ? t(copy.title, { days: state.daysLeft })
              : t(copy.title)}
        </p>
        <p className="text-xs mt-1">
          {/* 66 §4.1: "12 / 5 — archive 7 more, or upgrade" — a live countdown,
              not a static count; it shrinks (and the banner disappears once
              back within the limit) as the trainer archives clients, since
              archiving invalidates queryKeys.billing.entitlements() (Prompt 4). */}
          {state.kind === "overLimit"
            ? t(copy.body, { count: state.activeClients - state.maxClients })
            : t(copy.body)}
        </p>
        <Link href="/admin/billing" className="inline-block mt-2.5 text-xs font-extrabold underline">
          {t("bannerCta")}
        </Link>
      </div>
      {state.dismissible && (
        <button
          onClick={() => {
            dismissTrialInfo();
            setTrialInfoDismissed(true);
          }}
          aria-label={t("bannerDismiss")}
          className="shrink-0 p-1 rounded-full hover:bg-black/10"
        >
          <span className="material-symbols-rounded text-lg">close</span>
        </button>
      )}
    </div>
  );
}
