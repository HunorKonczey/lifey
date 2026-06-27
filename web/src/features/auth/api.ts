import { api } from "@/lib/api/client";
import type { AuthResponse, LoginRequest, RegisterRequest } from "./types";

export const authApi = {
  login: (body: LoginRequest) =>
    api.post<AuthResponse>("/auth/login", body),

  register: (body: RegisterRequest) =>
    api.post<AuthResponse>("/auth/register", body),

  refresh: () =>
    api.post<AuthResponse>("/auth/refresh"),

  logout: () =>
    api.post<void>("/auth/logout"),

  logoutAll: () =>
    api.post<void>("/auth/logout-all"),
};
