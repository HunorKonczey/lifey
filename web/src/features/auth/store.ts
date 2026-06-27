"use client";

import { create } from "zustand";
import { setAccessToken, registerTokenRefresher } from "@/lib/api/client";
import { authApi } from "./api";
import type { UserResponse } from "./types";

interface SessionState {
  user: UserResponse | null;
  isLoading: boolean;
  setUser: (user: UserResponse | null, token: string | null) => void;
  logout: () => Promise<void>;
  logoutAll: () => Promise<void>;
  initialize: () => Promise<void>;
}

export const useSessionStore = create<SessionState>((set) => ({
  user: null,
  isLoading: true,

  setUser: (user, token) => {
    setAccessToken(token);
    set({ user, isLoading: false });
  },

  logout: async () => {
    try { await authApi.logout(); } catch { /* ignore */ }
    setAccessToken(null);
    set({ user: null });
  },

  logoutAll: async () => {
    try { await authApi.logoutAll(); } catch { /* ignore */ }
    setAccessToken(null);
    set({ user: null });
  },

  initialize: async () => {
    // Already authenticated (e.g. just logged in) — nothing to do
    if (get().user) {
      set({ isLoading: false });
      return;
    }
    try {
      const res = await authApi.refresh();
      setAccessToken(res.accessToken);
      set({ user: res.user, isLoading: false });
    } catch {
      setAccessToken(null);
      set({ user: null, isLoading: false });
    }
  },
}));

// Register single-flight refresh with the API client
registerTokenRefresher(async () => {
  try {
    const res = await authApi.refresh();
    useSessionStore.getState().setUser(res.user, res.accessToken);
    return res.accessToken;
  } catch {
    useSessionStore.getState().setUser(null, null);
    return null;
  }
});
