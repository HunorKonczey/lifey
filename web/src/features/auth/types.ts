export type Role = "ROLE_USER" | "ROLE_TRAINER";

export interface UserResponse {
  id: number;
  email: string;
  name: string;
  roles: Role[];
}

export interface AuthResponse {
  accessToken: string;
  refreshToken?: string;
  user: UserResponse;
}

export interface LoginRequest {
  email: string;
  password: string;
}

export interface RegisterRequest {
  name: string;
  email: string;
  password: string;
}
