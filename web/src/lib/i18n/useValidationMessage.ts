"use client";

import { useTranslations } from "next-intl";

/**
 * Zod schemas carry i18n keys ("validation.emailInvalid") instead of English
 * text, because they are defined outside React and can't call useTranslations.
 * This resolves such a key at render time; anything else (e.g. an API error
 * message already set via setError) passes through unchanged.
 */
export function useValidationMessage() {
  const t = useTranslations();
  return (message: string | undefined): string | undefined => {
    if (!message) return message;
    return message.startsWith("validation.") && t.has(message) ? t(message) : message;
  };
}
