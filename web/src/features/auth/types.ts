export type Role = "ROLE_USER" | "ROLE_ADMIN" | "ROLE_TRAINER" | "ROLE_SUPER_ADMIN";

/** Backend UserResponse (from POST /auth/register). */
export interface UserResponse {
  id: number;
  email: string;
  firstName: string;
  lastName: string;
  roles: Role[];
  createdAt: string;
}

/** Backend AuthResponse (from /auth/login and /auth/refresh). No user object. */
export interface AuthResponse {
  accessToken: string;
  refreshToken: string;
  tokenType: string;
  expiresIn: number;
}

/** Derived from the access-token JWT claims for display. */
export interface SessionUser {
  id: number;
  email: string;
  firstName?: string;
  lastName?: string;
  roles: string[];
}

export interface LoginRequest {
  email: string;
  password: string;
}

export interface RegisterRequest {
  email: string;
  password: string;
  firstName: string;
  lastName: string;
}

export interface ForgotPasswordRequest {
  email: string;
}

export interface ResetPasswordRequest {
  email: string;
  code: string;
  newPassword: string;
}

export interface ChangePasswordRequest {
  currentPassword: string;
  newPassword: string;
}
