"use client";

import { NextIntlClientProvider } from "next-intl";
import { useEffect, useState } from "react";

type Messages = Record<string, unknown>;

async function loadMessages(locale: string): Promise<Messages> {
  const msgs = await import(`../../../messages/${locale}.json`);
  return msgs.default as Messages;
}

export function I18nProvider({
  locale,
  children,
}: {
  locale: "en" | "hu";
  children: React.ReactNode;
}) {
  const [messages, setMessages] = useState<Messages | null>(null);

  useEffect(() => {
    loadMessages(locale).then(setMessages);
  }, [locale]);

  if (!messages) return <>{children}</>;

  return (
    <NextIntlClientProvider locale={locale} messages={messages}>
      {children}
    </NextIntlClientProvider>
  );
}
