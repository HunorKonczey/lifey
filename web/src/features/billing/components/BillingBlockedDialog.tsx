"use client";

import Link from "next/link";
import { useTranslations } from "next-intl";
import { Dialog } from "@/components/ui/Dialog";
import type { TrainerPlan } from "../types";

interface BillingBlockedDialogProps {
  open: boolean;
  onClose: () => void;
  reason: "restricted" | "overLimit";
  /** Not interpolated into the copy directly — kept for parity with the shared
   *  data every gated call site already has on hand (66 §6), and available to
   *  a future call site without changing this component's shape again. */
  currentPlan: TrainerPlan | null;
  activeClients: number;
  maxClients: number | null;
}

/**
 * docs/landing_page/66-trainer-billing-web-plan.md D-T5 — one component so
 * the four blocked actions (send invite, assign content, assign a program,
 * schedule a workout) can't drift into four different explanations. Reuses
 * `AdminBillingBanner`'s own `bannerRestrictedTitle/Body` and
 * `bannerOverLimitTitle/Body` copy (`admin.billing` namespace) rather than a
 * near-duplicate set of dialog-only strings — D-T4's table and D-T5's dialog
 * are describing the exact same two states, just at two different moments.
 */
export function BillingBlockedDialog({ open, onClose, reason, activeClients, maxClients }: BillingBlockedDialogProps) {
  const t = useTranslations("admin.billing");
  const common = useTranslations("common");

  const title =
    reason === "restricted"
      ? t("bannerRestrictedTitle")
      : t("bannerOverLimitTitle", { activeClients, maxClients: maxClients ?? 0 });
  const body =
    reason === "restricted"
      ? t("bannerRestrictedBody")
      : t("bannerOverLimitBody", { count: activeClients - (maxClients ?? 0) });

  return (
    <Dialog open={open} onClose={onClose} title={title}>
      <div className="flex flex-col gap-4" data-testid="billing-blocked-dialog" data-blocked-reason={reason}>
        <p className="text-sm" style={{ color: "var(--on-surface-variant)" }}>
          {body}
        </p>
        <div className="flex gap-3">
          <button
            onClick={onClose}
            className="h-10 px-5 rounded-[var(--r-input)] font-semibold text-sm"
            style={{ background: "var(--surface-container)", color: "var(--on-surface)" }}
          >
            {common("cancel")}
          </button>
          <Link
            href="/admin/billing"
            className="h-10 px-5 rounded-[var(--r-input)] font-semibold text-sm flex items-center justify-center"
            style={{ background: "var(--primary)", color: "var(--bg)" }}
          >
            {t("bannerCta")}
          </Link>
        </div>
      </div>
    </Dialog>
  );
}
