"use client";

import { create } from "zustand";
import { setAccessToken, registerTokenRefresher } from "@/lib/api/client";
import { decodeJwt } from "@/lib/utils/jwt";
import { authApi } from "./api";
import type { SessionUser } from "./types";

const SESSION_KEY = "lifey_refresh_token";

function saveRefreshToken(token: string) {
  try {
    sessionStorage.setItem(SESSION_KEY, token);
  } catch { /* ignore */ }
}

function getRefreshToken(): string | null {
  try {
    return sessionStorage.getItem(SESSION_KEY);
  } catch {
    return null;
  }
}

function clearRefreshToken() {
  try {
    sessionStorage.removeItem(SESSION_KEY);
  } catch { /* ignore */ }
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
  /** Persist the token pair and derive the user from the access token. */
  applyTokens: (accessToken: string, refreshToken: string) => void;
  logout: () => Promise<void>;
  logoutAll: () => Promise<void>;
  initialize: () => Promise<void>;
}

export const useSessionStore = create<SessionState>((set, get) => ({
  user: null,
  isLoading: true,
  initFailed: false,

  applyTokens: (accessToken, refreshToken) => {
    setAccessToken(accessToken);
    saveRefreshToken(refreshToken);
    set({
      user: userFromAccessToken(accessToken),
      isLoading: false,
      initFailed: false,
    });
  },

  logout: async () => {
    const rt = getRefreshToken();
    clearRefreshToken();
    setAccessToken(null);
    set({ user: null, initFailed: false });
    if (rt) {
      try { await authApi.logout(rt); } catch { /* ignore */ }
    }
  },

  logoutAll: async () => {
    clearRefreshToken();
    setAccessToken(null);
    set({ user: null, initFailed: false });
    try { await authApi.logoutAll(); } catch { /* ignore */ }
  },

  initialize: async () => {
    if (get().user) {
      set({ isLoading: false });
      return;
    }
    const rt = getRefreshToken();
    if (!rt) {
      set({ user: null, isLoading: false, initFailed: true });
      return;
    }
    try {
      const res = await authApi.refresh(rt);
      setAccessToken(res.accessToken);
      saveRefreshToken(res.refreshToken);
      set({
        user: userFromAccessToken(res.accessToken),
        isLoading: false,
        initFailed: false,
      });
    } catch {
      clearRefreshToken();
      setAccessToken(null);
      set({ user: null, isLoading: false, initFailed: true });
    }
  },
}));

// Single-flight refresh for 401 interception
registerTokenRefresher(async () => {
  const rt = getRefreshToken();
  if (!rt) return null;
  try {
    const res = await authApi.refresh(rt);
    useSessionStore.getState().applyTokens(res.accessToken, res.refreshToken);
    return res.accessToken;
  } catch {
    return null;
  }
});
