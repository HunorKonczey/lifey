import { api } from "@/lib/api/client";
import type { AuthResponse, LoginRequest, RegisterRequest, UserResponse } from "./types";

export const authApi = {
  // Returns UserResponse (no tokens) — caller must log in afterwards.
  register: (body: RegisterRequest) =>
    api.post<UserResponse>("/auth/register", body),

  // Sets the refresh token as an httpOnly cookie; access token comes in the body.
  login: (body: LoginRequest) =>
    api.post<AuthResponse>("/auth/login", body),

  // Accepts the refresh token in the body (cross-origin safe) or falls back to
  // the httpOnly cookie if no token is provided (same-site setups).
  refresh: (refreshToken?: string) =>
    api.post<AuthResponse>("/auth/refresh", refreshToken ? { refreshToken } : undefined),

  // Reads + clears the refresh cookie server-side.
  logout: () =>
    api.post<void>("/auth/logout"),

  // Revokes all tokens for the authenticated user (uses access token) + clears cookie.
  logoutAll: () =>
    api.post<void>("/auth/logout-all"),
};
