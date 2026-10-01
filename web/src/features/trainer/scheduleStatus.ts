import type { OccurrenceStatus } from "./types";

/**
 * Shared status → chip style mapping (color/icon/fill) for every scheduled-occurrence
 * surface — the client Ütemterv tab timeline and the trainer calendar (docs/personal_trainer/
 * 12-edzo-naptar-terv.md) must render the exact same status language.
 */
export const STATUS_STYLE: Record<OccurrenceStatus, { bg: string; color: string; icon: string; fill?: boolean }> = {
  UPCOMING: { bg: "color-mix(in srgb, var(--primary) 16%, transparent)", color: "var(--text)", icon: "schedule" },
  DONE: { bg: "color-mix(in srgb, var(--improvement) 16%, transparent)", color: "var(--text)", icon: "check_circle", fill: true },
  MISSED: { bg: "color-mix(in srgb, var(--heart) 16%, transparent)", color: "var(--text)", icon: "warning" },
  CANCELLED: { bg: "transparent", color: "var(--text-2)", icon: "block" },
};
