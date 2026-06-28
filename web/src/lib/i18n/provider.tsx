"use client";

import { NextIntlClientProvider } from "next-intl";
import enMessages from "../../../messages/en.json";
import huMessages from "../../../messages/hu.json";
import type { Locale } from "@/lib/hooks/useLocale";

const MESSAGES = { en: enMessages, hu: huMessages } as Record<string, Record<string, unknown>>;

export function I18nProvider({
  locale,
  children,
}: {
  locale: Locale;
  children: React.ReactNode;
}) {
  return (
    <NextIntlClientProvider locale={locale} messages={MESSAGES[locale]}>
      {children}
    </NextIntlClientProvider>
  );
}
