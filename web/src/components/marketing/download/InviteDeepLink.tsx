"use client";

import { useEffect, useState } from "react";
import { useSearchParams } from "next/navigation";

const ATTEMPT_TIMEOUT_MS = 1200;
const COOKIE_MAX_AGE_S = 600; // "short-lived" (69 §6.2) — not specified further; 10 minutes covers a slow install+open.
const SESSION_STORAGE_KEY = "lifey_invite_token";
const COOKIE_NAME = "lifey_invite";

/**
 * The invite deep-link handoff (69 §6.2). A trainer's invite email links to
 * `/hu/letoltes?invite=<token>`; this reads that token, stashes it, attempts
 * `lifey://invite/<token>`, and — if the app doesn't take over within
 * ATTEMPT_TIMEOUT_MS — gets out of the way so the static page underneath
 * (wordmark, store badges, legal links) shows through.
 *
 * Nothing currently reads `lifey_invite_token`/`lifey_invite` back — the
 * actual invite match happens server-side by e-mail on first login
 * (D-DM5: that polling *is* the deferred deep link, no SDK needed), not by
 * replaying this token. They're stored anyway because the spec says to;
 * consuming them is presumably a future web-login convenience, not this
 * prompt's job to invent.
 *
 * `useSearchParams()` requires a Suspense boundary to keep the page
 * `force-static` (this component reads no server data, so the boundary
 * costs nothing at build time) — see page.tsx.
 */
export function InviteDeepLinkOverlay() {
  const params = useSearchParams();
  const token = params.get("invite");
  const [attempting, setAttempting] = useState(Boolean(token));

  useEffect(() => {
    if (!token) return;

    try {
      sessionStorage.setItem(SESSION_STORAGE_KEY, token);
    } catch {
      /* private browsing / storage disabled — the deep-link attempt itself doesn't need it */
    }
    document.cookie = `${COOKIE_NAME}=${encodeURIComponent(token)}; max-age=${COOKIE_MAX_AGE_S}; path=/; samesite=lax`;

    window.location.href = `lifey://invite/${encodeURIComponent(token)}`;

    // Deliberately not gated on document.hidden: an earlier version only
    // revealed the fallback if the tab was still visible right at the
    // timeout, on the theory that a hidden tab meant the app had taken
    // over. That reasoning has a real hole — if the tab is backgrounded at
    // that exact instant for any *other* reason (the user switched apps,
    // manually changed tabs, or in one observed case, simply wasn't the
    // foreground tab in a multi-tab session), setAttempting(false) never
    // fires and the overlay is stuck forever, even after they come back.
    // If the app really did open, this tab isn't being watched anyway, so
    // revealing the fallback underneath it costs nothing.
    const timer = setTimeout(() => setAttempting(false), ATTEMPT_TIMEOUT_MS);

    return () => clearTimeout(timer);
  }, [token]);

  if (!attempting) return null;

  return (
    <div
      className="fixed inset-0 z-50 flex items-center justify-center"
      style={{ background: "var(--bg)" }}
    >
      <div className="flex flex-col items-center gap-4">
        <span
          className="material-symbols-rounded text-5xl animate-pulse"
          style={{ color: "var(--secondary)" }}
        >
          smartphone
        </span>
      </div>
    </div>
  );
}

/** The "the app isn't installed yet, your invite will wait" line — only shown for an invite visit that reached the fallback (69 §6.2 step 3). */
export function InviteReassuranceLine({ text }: { text: string }) {
  const params = useSearchParams();
  const token = params.get("invite");

  if (!token) return null;

  return (
    <p className="text-sm font-semibold mt-4" style={{ color: "var(--secondary)" }}>
      {text}
    </p>
  );
}
