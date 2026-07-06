"use client";

import { useEffect, useRef } from "react";
import { useTranslations } from "next-intl";
import { useRouter } from "next/navigation";
import { authApi } from "../api";
import { useSessionStore } from "../store";
import { useLocale } from "@/lib/hooks/useLocale";
import { useTheme } from "@/lib/hooks/useTheme";
import { useToast } from "@/lib/hooks/useToast";
import { env } from "@/lib/env";
import { ApiError } from "@/lib/api/client";
import { userDetailsApi } from "@/features/onboarding/api";

declare global {
  interface Window {
    google?: {
      accounts: {
        id: {
          initialize: (config: {
            client_id: string;
            callback: (response: { credential: string }) => void;
          }) => void;
          renderButton: (parent: HTMLElement, options: Record<string, string>) => void;
        };
      };
    };
  }
}

const SCRIPT_ID = "google-identity-services";

function loadGsiScript(locale: string): Promise<void> {
  return new Promise((resolve, reject) => {
    document.getElementById(SCRIPT_ID)?.remove();

    const script = document.createElement("script");
    script.id = SCRIPT_ID;
    script.src = `https://accounts.google.com/gsi/client?hl=${locale}`;
    script.async = true;
    script.defer = true;
    script.onload = () => resolve();
    script.onerror = () => reject(new Error("Failed to load Google Identity Services"));
    document.head.appendChild(script);
  });
}

interface GoogleSignInButtonProps {
  /** "register" checks whether onboarding is needed and routes there instead
   *  of the dashboard — covers first-time social sign-ups. "login" (default)
   *  always goes straight to the dashboard; the dashboard banner handles
   *  re-offering onboarding for returning users who skipped it. */
  mode?: "login" | "register";
}

/** Official GIS-rendered "Continue with Google" button (Q5: no custom styling). */
export function GoogleSignInButton({ mode = "login" }: GoogleSignInButtonProps) {
  const t = useTranslations("auth");
  const router = useRouter();
  const applyAccessToken = useSessionStore((s) => s.applyAccessToken);
  const { show } = useToast();
  const locale = useLocale((s) => s.locale);
  const localeHydrated = useLocale((s) => s.hydrated);
  const themePreference = useTheme((s) => s.preference);
  const containerRef = useRef<HTMLDivElement>(null);

  const isDark =
    themePreference === "dark" ||
    (themePreference === "system" &&
      typeof window !== "undefined" &&
      window.matchMedia("(prefers-color-scheme: dark)").matches);

  const latestRef = useRef({ applyAccessToken, router, show, t, mode });
  useEffect(() => {
    latestRef.current = { applyAccessToken, router, show, t, mode };
  });

  useEffect(() => {
    if (!env.NEXT_PUBLIC_GOOGLE_CLIENT_ID || !localeHydrated) return;
    let cancelled = false;

    loadGsiScript(locale)
      .then(() => {
        if (cancelled || !window.google || !containerRef.current) return;

        window.google.accounts.id.initialize({
          client_id: env.NEXT_PUBLIC_GOOGLE_CLIENT_ID,
          callback: async (response) => {
            const { applyAccessToken, router, show, t, mode } = latestRef.current;
            try {
              const res = await authApi.socialGoogleLogin(response.credential);
              applyAccessToken(res.accessToken, res.refreshToken);
              if (mode === "register") {
                try {
                  await userDetailsApi.get();
                  router.push("/dashboard");
                } catch (detailsErr) {
                  if (detailsErr instanceof ApiError && detailsErr.status === 404) {
                    router.push("/onboarding");
                  } else {
                    router.push("/dashboard");
                  }
                }
              } else {
                router.push("/dashboard");
              }
            } catch (err) {
              const message = err instanceof ApiError ? err.message : t("googleSignInFailed");
              show(message, "error");
            }
          },
        });

        containerRef.current.innerHTML = "";
        window.google.accounts.id.renderButton(containerRef.current, {
          type: "standard",
          theme: isDark ? "filled_black" : "outline",
          size: "large",
          width: "320",
          text: "continue_with",
          locale,
        });
      })
      .catch(() => {
        const { show, t } = latestRef.current;
        show(t("googleSignInFailed"), "error");
      });

    return () => {
      cancelled = true;
    };
  }, [locale, isDark, localeHydrated]);

  if (!env.NEXT_PUBLIC_GOOGLE_CLIENT_ID) return null;

  return (
    <div className="flex flex-col items-center gap-4 w-full mt-2">
      <div className="flex items-center gap-3 w-full">
        <div className="h-px flex-1" style={{ background: "var(--outline)" }} />
        <span className="text-xs" style={{ color: "var(--on-surface-variant)" }}>
          {t("orContinueWith")}
        </span>
        <div className="h-px flex-1" style={{ background: "var(--outline)" }} />
      </div>
      <div ref={containerRef} className="w-full flex justify-center" />
    </div>
  );
}
