"use client";

import { useLocale, useTranslations } from "next-intl";
import { createFormat, type LifeyFormat } from "./lifeyFormat";

/**
 * `lifeyFormat` plus the enum-label lookups that need the message catalog
 * (D-W0.8: "via messages, never `humanizeEnum` for display" — no raw
 * `workouts.activityTypes.CYCLING` or `ROLE_USER` on screen). The numeric and
 * date functions don't need React, so they stay in the plain `createFormat`
 * this wraps; only the label lookups need `useTranslations`.
 */
export interface UseFormatResult extends LifeyFormat {
  roleLabel(role: string): string;
  activityLabel(type: string): string;
  mealTypeLabel(type: string): string;
  recurrenceLabel(type: string): string;
  occurrenceStatusLabel(status: string): string;
}

export function useFormat(): UseFormatResult {
  const locale = useLocale();
  const t = useTranslations("labels");

  return {
    ...createFormat(locale),
    roleLabel: (role) => t(`roles.${role}` as never),
    activityLabel: (type) => t(`activityTypes.${type}` as never),
    mealTypeLabel: (type) => t(`mealTypes.${type}` as never),
    recurrenceLabel: (type) => t(`recurrence.${type}` as never),
    occurrenceStatusLabel: (status) => t(`occurrenceStatus.${status}` as never),
  };
}
