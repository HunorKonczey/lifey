"use client";

import { create } from "zustand";
import { ApiError, setAccessToken, registerTokenRefresher } from "@/lib/api/client";
import { clearQueryCache } from "@/lib/queryCacheClearer";
import { decodeJwt } from "@/lib/utils/jwt";
import { authApi } from "./api";
import type { AuthResponse, SessionUser } from "./types";

const RT_KEY = "lifey-rt";

function getStoredRefreshToken(): string | null {
  try { return localStorage.getItem(RT_KEY); } catch { return null; }
}
function saveRefreshToken(token: string) {
  try { localStorage.setItem(RT_KEY, token); } catch { /* ignore */ }
}
function clearRefreshToken() {
  try { localStorage.removeItem(RT_KEY); } catch { /* ignore */ }
}

/** What exchanging the stored refresh token for a new pair came to. */
type Exchange = { status: "ok"; auth: AuthResponse } | { status: "rejected" } | { status: "unavailable" };

/**
 * Exchanges the stored refresh token. It is single-use, and several things share it: this tab's page load,
 * its 401 handling, and every other tab of the app (the token lives in localStorage). So:
 *
 * - a refusal (4xx) clears the stored token only if it is still the one we sent — if another tab rotated it
 *   in the meantime the stored value is newer, and it is the one to try (not to delete: clearing it signed
 *   the user out of every tab at the next load);
 * - a failure that says nothing about the token (no connection, a 5xx while the API restarts) keeps it, so a
 *   server hiccup does not end the session.
 */
async function exchangeStoredRefreshToken(): Promise<Exchange> {
  for (let attempt = 0; attempt < 2; attempt++) {
    const stored = getStoredRefreshToken();
    if (!stored) return { status: "rejected" };
    try {
      return { status: "ok", auth: await authApi.refresh(stored) };
    } catch (error) {
      if (!(error instanceof ApiError) || error.status >= 500) return { status: "unavailable" };
      if (getStoredRefreshToken() !== stored) continue;
      clearRefreshToken();
      return { status: "rejected" };
    }
  }
  return { status: "rejected" };
}

/** Everything that refreshes shares one exchange at a time, so one tab never spends its own token twice. */
let exchanging: Promise<Exchange> | null = null;
function exchangeOnce(): Promise<Exchange> {
  exchanging ??= exchangeStoredRefreshToken().finally(() => {
    exchanging = null;
  });
  return exchanging;
}

/** Build the display user from the access-token JWT claims. */
function userFromAccessToken(accessToken: string): SessionUser | null {
  const claims = decodeJwt(accessToken);
  if (!claims) return null;
  return {
    id: Number(claims.sub),
    email: claims.email,
    firstName: claims.firstName,
    lastName: claims.lastName,
    roles: claims.roles ?? [],
  };
}

interface SessionState {
  user: SessionUser | null;
  isLoading: boolean;
  initFailed: boolean;
  /** Store the access token in memory, persist the refresh token to localStorage,
   *  and derive the user from the access-token JWT claims. */
  applyAccessToken: (accessToken: string, refreshToken?: string) => void;
  logout: () => Promise<void>;
  logoutAll: () => Promise<void>;
  initialize: () => Promise<void>;
  /**
   * Unlike `initialize()`, always re-exchanges the refresh token even when a
   * user is already set — for when the server-side role set just changed
   * (docs/landing_page/66-trainer-billing-web-plan.md §2: a trainer request
   * was approved) and the current access token's `roles` claim is stale.
   * JWTs aren't re-issued retroactively, so the only way to pick up the new
   * role client-side is a fresh token. Returns whether it succeeded.
   */
  refreshUser: () => Promise<boolean>;
}

export const useSessionStore = create<SessionState>((set, get) => ({
  user: null,
  isLoading: true,
  initFailed: false,

  applyAccessToken: (accessToken, refreshToken) => {
    const previousUserId = get().user?.id;
    const nextUser = userFromAccessToken(accessToken);
    setAccessToken(accessToken);
    if (refreshToken) saveRefreshToken(refreshToken);
    // A different account just signed in on this session (e.g. logout then
    // Google sign-in as someone else) — drop cached queries (avatar,
    // settings, etc.) so they don't keep showing the previous user's data
    // until a hard refresh.
    if (previousUserId !== undefined && nextUser?.id !== previousUserId) {
      clearQueryCache();
    }
    set({ user: nextUser, isLoading: false, initFailed: false });
  },

  logout: async () => {
    // Read before it is cleared: the refresh token is what the server revokes, and on a cross-site setup the
    // httpOnly cookie is not always sent along, so the request carries it itself.
    const refreshToken = getStoredRefreshToken() ?? undefined;
    setAccessToken(null);
    clearRefreshToken();
    clearQueryCache();
    set({ user: null, initFailed: false });
    try { await authApi.logout(refreshToken); } catch { /* ignore */ }
  },

  logoutAll: async () => {
    // Asked *before* the access token is dropped: this endpoint identifies the user by it, and with the token
    // already cleared the request was a 401 - "log out of every device" revoked nothing on the server.
    try { await authApi.logoutAll(); } catch { /* signed out here either way */ }
    setAccessToken(null);
    clearRefreshToken();
    clearQueryCache();
    set({ user: null, initFailed: false });
  },

  initialize: async () => {
    if (get().user) {
      set({ isLoading: false });
      return;
    }
    if (!getStoredRefreshToken()) {
      set({ user: null, isLoading: false, initFailed: true });
      return;
    }
    const exchange = await exchangeOnce();
    if (exchange.status === "ok") {
      setAccessToken(exchange.auth.accessToken);
      saveRefreshToken(exchange.auth.refreshToken); // rotate stored token
      set({ user: userFromAccessToken(exchange.auth.accessToken), isLoading: false, initFailed: false });
      return;
    }
    // Rejected: the token is gone for good. Unavailable: it is kept, so the next load can still sign in.
    setAccessToken(null);
    set({ user: null, isLoading: false, initFailed: true });
  },

  refreshUser: async () => {
    if (!getStoredRefreshToken()) return false;
    const exchange = await exchangeOnce();
    if (exchange.status !== "ok") return false;
    setAccessToken(exchange.auth.accessToken);
    saveRefreshToken(exchange.auth.refreshToken);
    set({ user: userFromAccessToken(exchange.auth.accessToken), isLoading: false, initFailed: false });
    return true;
  },
}));

// Single-flight refresh for 401 interception.
registerTokenRefresher(async () => {
  if (!getStoredRefreshToken()) return null;
  const exchange = await exchangeOnce();
  if (exchange.status === "ok") {
    useSessionStore.getState().applyAccessToken(exchange.auth.accessToken, exchange.auth.refreshToken);
    return exchange.auth.accessToken;
  }
  // Rejected: the session is over (null). Unavailable: not knowing is not the same, so the request fails
  // with the network error and the in-memory session survives to try again.
  if (exchange.status === "unavailable") throw new Error("Could not reach the server to refresh the session");
  return null;
});
