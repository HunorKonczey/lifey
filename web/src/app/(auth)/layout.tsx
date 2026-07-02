"use client";

import { useLocale } from "@/lib/hooks/useLocale";
import { I18nProvider } from "@/lib/i18n/provider";

export default function AuthLayout({
  children,
}: {
  children: React.ReactNode;
}) {
  const { locale } = useLocale();

  return (
    <I18nProvider locale={locale}>
      <div className="min-h-screen flex items-center justify-center bg-bg px-4">
        {children}
      </div>
    </I18nProvider>
  );
}
