import type { OccurrenceStatus } from "./types";

/**
 * Shared status → chip style mapping (color/icon/fill) for every scheduled-occurrence
 * surface — the client Ütemterv tab timeline and the trainer calendar (docs/personal_trainer/
 * 12-edzo-naptar-terv.md) must render the exact same status language.
 */
export const STATUS_STYLE: Record<OccurrenceStatus, { bg: string; color: string; icon: string; fill?: boolean }> = {
  UPCOMING: { bg: "rgba(110,154,106,.18)", color: "var(--tertiary)", icon: "schedule" },
  DONE: { bg: "transparent", color: "var(--tertiary)", icon: "check_circle", fill: true },
  MISSED: { bg: "rgba(207,102,121,.16)", color: "var(--error)", icon: "warning" },
  CANCELLED: { bg: "transparent", color: "var(--on-surface-variant)", icon: "block" },
};
