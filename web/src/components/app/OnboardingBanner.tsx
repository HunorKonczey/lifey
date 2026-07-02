"use client";

import { useState } from "react";
import { useRouter } from "next/navigation";
import { useTranslations } from "next-intl";
import { useQuery } from "@tanstack/react-query";
import { userDetailsApi } from "@/features/onboarding/api";
import { queryKeys } from "@/lib/api/queryKeys";
import { ApiError } from "@/lib/api/client";

const DISMISSED_KEY = "lifey-onboarding-banner-dismissed";

function readDismissed(): boolean {
  if (typeof window === "undefined") return true; // hidden during SSR, resolved on first client render
  try {
    return localStorage.getItem(DISMISSED_KEY) === "1";
  } catch {
    return false;
  }
}

/**
 * Shown on the dashboard when the user hasn't completed (or has skipped) the
 * onboarding wizard — GET /user-details 404 is the signal (see
 * docs/21-onboarding-user-details-plan.md, there's no hasUserDetails flag on
 * login to check instead). Dismissal is per-browser, not per-account.
 */
export function OnboardingBanner() {
  const t = useTranslations("onboarding");
  const router = useRouter();
  const [dismissed, setDismissed] = useState(readDismissed);

  const { data, error } = useQuery({
    queryKey: queryKeys.userDetails.all(),
    queryFn: userDetailsApi.get,
    retry: false,
  });

  const notOnboarded = error instanceof ApiError && error.status === 404;
  if (dismissed || data || !notOnboarded) return null;

  const dismiss = () => {
    try {
      localStorage.setItem(DISMISSED_KEY, "1");
    } catch {
      /* ignore */
    }
    setDismissed(true);
  };

  return (
    <div
      className="flex items-center justify-between gap-4 p-4 rounded-[var(--r-card)] mb-4"
      style={{ background: "color-mix(in srgb, var(--primary) 14%, var(--surface))", border: "1px solid var(--primary)" }}
    >
      <div className="flex items-center gap-3">
        <span className="material-symbols-rounded text-2xl" style={{ color: "var(--primary)" }}>eco</span>
        <div>
          <p className="text-sm font-bold">{t("bannerTitle")}</p>
          <p className="text-xs" style={{ color: "var(--on-surface-variant)" }}>{t("bannerBody")}</p>
        </div>
      </div>
      <div className="flex items-center gap-2 shrink-0">
        <button
          onClick={() => router.push("/onboarding")}
          className="h-9 px-4 rounded-[var(--r-input)] font-semibold text-sm"
          style={{ background: "var(--primary)", color: "#1E1F18" }}
        >
          {t("bannerCta")}
        </button>
        <button onClick={dismiss} aria-label={t("bannerDismissAria")} style={{ color: "var(--muted)" }}>
          <span className="material-symbols-rounded text-lg">close</span>
        </button>
      </div>
    </div>
  );
}
