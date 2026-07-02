import { api } from "@/lib/api/client";
import type {
  AuthResponse,
  ChangePasswordRequest,
  ForgotPasswordRequest,
  LoginRequest,
  RegisterRequest,
  ResetPasswordRequest,
  UserResponse,
} from "./types";

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

  // Always resolves (200), regardless of whether the email is registered.
  forgotPassword: (body: ForgotPasswordRequest) =>
    api.post<void>("/auth/forgot-password", body),

  resetPassword: (body: ResetPasswordRequest) =>
    api.post<void>("/auth/reset-password", body),

  // Returns a fresh token pair so the calling device stays logged in.
  changePassword: (body: ChangePasswordRequest) =>
    api.post<AuthResponse>("/auth/change-password", body),
};
