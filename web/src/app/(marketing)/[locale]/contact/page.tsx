import type { Metadata } from "next";
import { getTranslations, setRequestLocale } from "next-intl/server";
import { buildMetadata } from "@/lib/marketingMetadata";
import { ContactForm } from "@/components/marketing/contact/ContactForm";

// The contact page (docs/landing_page/65 Prompt 8, 68 §6: "a short form...
// plus a direct email address"). The form posts to POST /api/v1/contact,
// added to the backend alongside this page (com.lifey.contact,
// MailService.sendContactMessage) — see this prompt's landed notes for why
// that crossed out of web/ for the first time in this doc's 8 prompts.
export const dynamic = "force-static";

export async function generateMetadata({
  params,
}: {
  params: Promise<{ locale: string }>;
}): Promise<Metadata> {
  const { locale } = await params;
  const t = await getTranslations({ locale, namespace: "seo.contact" });
  return buildMetadata({ locale, href: "/contact", title: t("metaTitle"), description: t("metaDescription") });
}

export default async function ContactPage({
  params,
}: {
  params: Promise<{ locale: string }>;
}) {
  const { locale } = await params;
  setRequestLocale(locale);

  const t = await getTranslations("contact");
  const footer = await getTranslations("footer");

  return (
    <main className="py-14 md:py-20" style={{ background: "var(--bg)" }}>
      <div className="max-w-[560px] mx-auto px-4 md:px-8">
        <h1 className="text-[32px] md:text-[44px] font-bold tracking-[-0.02em] text-center">{t("title")}</h1>
        <p className="text-base md:text-lg mt-3 text-center" style={{ color: "var(--on-surface-variant)" }}>
          {t("sub")}
        </p>

        <div className="mt-8">
          <ContactForm
            locale={locale}
            labels={{
              name: t("nameLabel"),
              email: t("emailLabel"),
              message: t("messageLabel"),
              submit: t("submit"),
              sending: t("sending"),
              success: t("success"),
              error: t("error"),
            }}
          />
        </div>

        <p className="text-sm text-center mt-6" style={{ color: "var(--muted)" }}>
          {t("directEmailPrefix")}{" "}
          <a href={`mailto:${footer("email")}`} className="font-bold" style={{ color: "var(--primary)" }}>
            {footer("email")}
          </a>
        </p>
      </div>
    </main>
  );
}
