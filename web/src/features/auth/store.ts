"use client";

import { create } from "zustand";
import { setAccessToken, registerTokenRefresher } from "@/lib/api/client";
import { decodeJwt } from "@/lib/utils/jwt";
import { authApi } from "./api";
import type { SessionUser } from "./types";

/** Build the display user from the access-token JWT claims. */
function userFromAccessToken(accessToken: string): SessionUser | null {
  const claims = decodeJwt(accessToken);
  if (!claims) return null;
  return {
    id: Number(claims.sub),
    email: claims.email,
    roles: claims.roles ?? [],
  };
}

interface SessionState {
  user: SessionUser | null;
  isLoading: boolean;
  initFailed: boolean;
  /** Store the access token in memory and derive the user. The refresh token
   *  lives only in the httpOnly cookie set by the backend. */
  applyAccessToken: (accessToken: string) => void;
  logout: () => Promise<void>;
  logoutAll: () => Promise<void>;
  initialize: () => Promise<void>;
}

export const useSessionStore = create<SessionState>((set, get) => ({
  user: null,
  isLoading: true,
  initFailed: false,

  applyAccessToken: (accessToken) => {
    setAccessToken(accessToken);
    set({ user: userFromAccessToken(accessToken), isLoading: false, initFailed: false });
  },

  logout: async () => {
    setAccessToken(null);
    set({ user: null, initFailed: false });
    try { await authApi.logout(); } catch { /* ignore */ }
  },

  logoutAll: async () => {
    setAccessToken(null);
    set({ user: null, initFailed: false });
    try { await authApi.logoutAll(); } catch { /* ignore */ }
  },

  initialize: async () => {
    if (get().user) {
      set({ isLoading: false });
      return;
    }
    // Try to restore the session from the httpOnly refresh cookie.
    try {
      const res = await authApi.refresh();
      setAccessToken(res.accessToken);
      set({ user: userFromAccessToken(res.accessToken), isLoading: false, initFailed: false });
    } catch {
      setAccessToken(null);
      set({ user: null, isLoading: false, initFailed: true });
    }
  },
}));

// Single-flight refresh for 401 interception — relies on the refresh cookie.
registerTokenRefresher(async () => {
  try {
    const res = await authApi.refresh();
    useSessionStore.getState().applyAccessToken(res.accessToken);
    return res.accessToken;
  } catch {
    return null;
  }
});
