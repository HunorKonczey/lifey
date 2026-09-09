"use client";

import { Link, usePathname } from "@/i18n/navigation";

const NAV_ITEMS = [
  { href: "/for-trainers", labelKey: "forTrainers" },
  { href: "/app", labelKey: "app" },
  { href: "/pricing", labelKey: "pricing" },
  { href: "/faq", labelKey: "faq" },
] as const;

export function MarketingNav({
  labels,
  variant = "desktop",
  onNavigate,
}: {
  /** Translated labels, keyed by `labelKey` above — passed from a server
   *  parent's `getTranslations("nav")` so this client island never needs its
   *  own `useTranslations` (65 §8's JS budget: no messages payload shipped
   *  just for four nav labels). */
  labels: Record<(typeof NAV_ITEMS)[number]["labelKey"], string>;
  variant?: "desktop" | "mobile";
  /** Mobile menu closes itself when a link is followed. */
  onNavigate?: () => void;
}) {
  const pathname = usePathname();

  if (variant === "mobile") {
    return (
      <nav className="flex flex-col">
        {NAV_ITEMS.map((item) => {
          const active = pathname === item.href;
          return (
            <Link
              key={item.href}
              href={item.href}
              onClick={onNavigate}
              className="h-[52px] flex items-center text-[17px] font-bold"
              style={{ color: active ? "var(--on-surface)" : "var(--on-surface-variant)" }}
            >
              {labels[item.labelKey]}
            </Link>
          );
        })}
      </nav>
    );
  }

  return (
    <nav className="hidden md:flex items-center gap-6.5 text-[15px] font-semibold">
      {NAV_ITEMS.map((item) => {
        const active = pathname === item.href;
        return (
          <Link
            key={item.href}
            href={item.href}
            style={{ color: active ? "var(--on-surface)" : "var(--on-surface-variant)" }}
          >
            {labels[item.labelKey]}
          </Link>
        );
      })}
    </nav>
  );
}
