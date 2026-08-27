"use client";

import { useEffect } from "react";
import Link from "next/link";
import { useSessionStore } from "@/features/auth/store";

/**
 * The one piece of the marketing header that needs to know about auth state
 * (65 D-W2: "a small client component that reads the session store; the rest
 * of the page stays server-rendered"). `useSessionStore` is a plain Zustand
 * store — no `<Providers>` ancestor required, `initialize()` just calls the
 * refresh-token endpoint directly.
 *
 * Links to `/login`/`/register`/`/dashboard` are plain `next/link`, not the
 * marketing `Link` from `@/i18n/navigation` — those are authenticated-app
 * routes with no locale prefix, not in the marketing `pathnames` map.
 */
export function HeaderAuthActions({
  labels,
  variant = "desktop",
  onNavigate,
}: {
  labels: { login: string; trialCta: string; backToApp: string };
  variant?: "desktop" | "mobile";
  onNavigate?: () => void;
}) {
  const { user, initialize } = useSessionStore();

  useEffect(() => {
    initialize();
  }, [initialize]);

  if (user) {
    const initials = (
      user.firstName && user.lastName
        ? `${user.firstName[0]}${user.lastName[0]}`
        : user.email[0]
    ).toUpperCase();

    return (
      <div className={variant === "mobile" ? "flex flex-col gap-3" : "flex items-center gap-3.5"}>
        <Link
          href="/dashboard"
          onClick={onNavigate}
          className={
            variant === "mobile"
              ? "h-13 rounded-pill border-[1.5px] border-outline flex items-center justify-center gap-2 text-[15px] font-bold"
              : "h-12 rounded-pill border-[1.5px] border-outline flex items-center gap-2 px-5.5 text-[15px] font-bold"
          }
        >
          <span className="material-symbols-rounded text-xl">arrow_back</span>
          {labels.backToApp}
        </Link>
        {variant === "desktop" && (
          <span
            className="w-11 h-11 rounded-pill flex items-center justify-center text-[15px] font-extrabold"
            style={{ background: "var(--secondary)", color: "#161611" }}
          >
            {initials}
          </span>
        )}
      </div>
    );
  }

  if (variant === "mobile") {
    return (
      <div className="flex flex-col">
        <Link
          href="/login"
          onClick={onNavigate}
          className="h-[52px] flex items-center text-[17px] font-bold border-t border-outline mt-2"
          style={{ color: "var(--on-surface-variant)" }}
        >
          {labels.login}
        </Link>
        {/* Eventually the trainer-request flow (docs/landing_page/66 D-T1),
            once it exists — /register is the working placeholder target. */}
        <Link
          href="/register"
          onClick={onNavigate}
          className="h-14 rounded-pill flex items-center justify-center text-base font-extrabold mt-3"
          style={{ background: "var(--primary)", color: "var(--bg)" }}
        >
          {labels.trialCta}
        </Link>
      </div>
    );
  }

  return (
    <div className="flex items-center gap-3.5">
      <Link
        href="/login"
        className="h-11 flex items-center px-4 text-[15px] font-bold"
        style={{ color: "var(--on-surface)" }}
      >
        {labels.login}
      </Link>
      <Link
        href="/register"
        className="h-12 rounded-pill flex items-center px-5.5 text-[15px] font-extrabold"
        style={{ background: "var(--primary)", color: "var(--bg)" }}
      >
        {labels.trialCta}
      </Link>
    </div>
  );
}
