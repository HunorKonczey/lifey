import { api } from "@/lib/api/client";
import type { AuthResponse, LoginRequest, RegisterRequest, UserResponse } from "./types";

export const authApi = {
  // Returns UserResponse (no tokens) — caller must log in afterwards.
  register: (body: RegisterRequest) =>
    api.post<UserResponse>("/auth/register", body),

  login: (body: LoginRequest) =>
    api.post<AuthResponse>("/auth/login", body),

  refresh: (refreshToken: string) =>
    api.post<AuthResponse>("/auth/refresh", { refreshToken }),

  logout: (refreshToken: string) =>
    api.post<void>("/auth/logout", { refreshToken }),

  // Revokes all tokens for the authenticated user (uses access token, no body).
  logoutAll: () =>
    api.post<void>("/auth/logout-all"),
};
