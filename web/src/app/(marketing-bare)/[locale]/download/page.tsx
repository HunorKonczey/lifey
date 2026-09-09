import { Suspense } from "react";
import type { Metadata } from "next";
import { getTranslations, setRequestLocale } from "next-intl/server";
import { buildMetadata } from "@/lib/marketingMetadata";
import { Link } from "@/i18n/navigation";
import { StoreBadges } from "@/components/marketing/StoreBadges";
import { InviteDeepLinkOverlay, InviteReassuranceLine } from "@/components/marketing/download/InviteDeepLink";

// The download / invite bridge page (docs/landing_page/65 Prompt 7, spec at
// 69 §6). Deliberately sparse (69 §6.1: "nothing scrolls on a phone") and
// chrome-free — see the (marketing-bare) layout.tsx for why that needed a
// second route group. No QR anywhere (69 §6.3, DV-4 — withdrawn).
export const dynamic = "force-static";

export async function generateMetadata({
  params,
}: {
  params: Promise<{ locale: string }>;
}): Promise<Metadata> {
  const { locale } = await params;
  const t = await getTranslations({ locale, namespace: "seo.download" });
  // Canonical/hreflang deliberately never carry `?invite=` — every token
  // would otherwise be a distinct "page" to a crawler.
  return buildMetadata({ locale, href: "/download", title: t("metaTitle"), description: t("metaDescription") });
}

export default async function DownloadPage({
  params,
}: {
  params: Promise<{ locale: string }>;
}) {
  const { locale } = await params;
  setRequestLocale(locale);

  const t = await getTranslations("download");
  const footer = await getTranslations("footer");

  return (
    <main className="min-h-dvh flex items-center justify-center px-6" style={{ background: "var(--bg)" }}>
      <Suspense fallback={null}>
        <InviteDeepLinkOverlay />
      </Suspense>

      <div className="text-center max-w-[360px]">
        <div className="flex items-center justify-center gap-2.5 mb-6">
          <span
            className="w-9 h-9 rounded-md flex items-center justify-center"
            style={{ background: "var(--primary)", color: "var(--bg)" }}
          >
            <span className="material-symbols-rounded text-xl" style={{ fontVariationSettings: "'FILL' 1" }}>
              eco
            </span>
          </span>
          <h1 className="text-xl font-extrabold">Lifey</h1>
        </div>

        <p className="text-base font-medium" style={{ color: "var(--on-surface-variant)" }}>
          {footer("tagline")}
        </p>

        <div className="flex justify-center mt-7">
          <StoreBadges size="lg" variant="disabled" />
        </div>

        <Suspense fallback={null}>
          <InviteReassuranceLine text={t("inviteWaits")} />
        </Suspense>

        <div className="flex items-center justify-center gap-3 mt-10 text-[11px]" style={{ color: "var(--muted)" }}>
          <Link href="/legal/terms">{footer("legalTerms")}</Link>
          <span>·</span>
          <Link href="/legal/privacy">{footer("legalPrivacy")}</Link>
        </div>
      </div>
    </main>
  );
}
