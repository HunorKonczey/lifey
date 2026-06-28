"use client";

import { create } from "zustand";
import { setAccessToken, registerTokenRefresher } from "@/lib/api/client";
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
}

export const useSessionStore = create<SessionState>((set, get) => ({
  user: null,
  isLoading: true,
  initFailed: false,

  applyAccessToken: (accessToken, refreshToken) => {
    setAccessToken(accessToken);
    if (refreshToken) saveRefreshToken(refreshToken);
    set({ user: userFromAccessToken(accessToken), isLoading: false, initFailed: false });
  },

  logout: async () => {
    setAccessToken(null);
    clearRefreshToken();
    set({ user: null, initFailed: false });
    try { await authApi.logout(); } catch { /* ignore */ }
  },

  logoutAll: async () => {
    setAccessToken(null);
    clearRefreshToken();
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
