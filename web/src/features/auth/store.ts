"use client";

import { create } from "zustand";
import { setAccessToken, registerTokenRefresher } from "@/lib/api/client";
import { queryClient } from "@/lib/queryClient";
import { decodeJwt } from "@/lib/utils/jwt";
import { authApi } from "./api";
import type { SessionUser } from "./types";

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
      queryClient.clear();
    }
    set({ user: nextUser, isLoading: false, initFailed: false });
  },

  logout: async () => {
    setAccessToken(null);
    clearRefreshToken();
    queryClient.clear();
    set({ user: null, initFailed: false });
    try { await authApi.logout(); } catch { /* ignore */ }
  },

  logoutAll: async () => {
    setAccessToken(null);
    clearRefreshToken();
    queryClient.clear();
    set({ user: null, initFailed: false });
    try { await authApi.logoutAll(); } catch { /* ignore */ }
  },

  initialize: async () => {
    if (get().user) {
      set({ isLoading: false });
      return;
    }
    const stored = getStoredRefreshToken();
    if (!stored) {
      set({ user: null, isLoading: false, initFailed: true });
      return;
    }
    try {
      const res = await authApi.refresh(stored);
      setAccessToken(res.accessToken);
      saveRefreshToken(res.refreshToken); // rotate stored token
      set({ user: userFromAccessToken(res.accessToken), isLoading: false, initFailed: false });
    } catch {
      setAccessToken(null);
      clearRefreshToken();
      set({ user: null, isLoading: false, initFailed: true });
    }
  },

  refreshUser: async () => {
    const stored = getStoredRefreshToken();
    if (!stored) return false;
    try {
      const res = await authApi.refresh(stored);
      setAccessToken(res.accessToken);
      saveRefreshToken(res.refreshToken);
      set({ user: userFromAccessToken(res.accessToken), isLoading: false, initFailed: false });
      return true;
    } catch {
      return false;
    }
  },
}));

// Single-flight refresh for 401 interception.
registerTokenRefresher(async () => {
  const stored = getStoredRefreshToken();
  if (!stored) return null;
  try {
    const res = await authApi.refresh(stored);
    useSessionStore.getState().applyAccessToken(res.accessToken, res.refreshToken);
    return res.accessToken;
  } catch {
    clearRefreshToken();
    return null;
  }
});
